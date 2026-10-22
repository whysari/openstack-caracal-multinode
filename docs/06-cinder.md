# 06 — Cinder: LVM over iSCSI

**Goal:** create a volume, attach it to a running instance, and see the block device inside the
guest.

Roles:

- `controller01` — `cinder-api`, `cinder-scheduler`
- `storage01` — `cinder-volume`, LVM VG `cinder-volumes`, `tgt` iSCSI target
- `compute01/02` — `open-iscsi` (the client side)

---

## 1. Database and credentials (controller01)

```bash
sudo mysql <<'SQL'
CREATE DATABASE cinder;
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'localhost' IDENTIFIED BY 'CINDER_DBPASS';
GRANT ALL PRIVILEGES ON cinder.* TO 'cinder'@'%' IDENTIFIED BY 'CINDER_DBPASS';
SQL

source ~/admin-openrc
openstack user create --domain default --password CINDER_PASS cinder
openstack role add --project service --user cinder admin
openstack service create --name cinderv3 --description "OpenStack Block Storage" volumev3
for iface in public internal; do
  openstack endpoint create --region RegionOne volumev3 "$iface" http://controller01:8776/v3/%\(project_id\)s
done
openstack endpoint create --region RegionOne volumev3 admin http://controller01:8776/v3/%\(project_id\)s
```

## 2. Controller services

```bash
sudo apt install -y cinder-api cinder-scheduler
```

Install [`configs/controller/cinder.conf`](../configs/controller/cinder.conf) as
`/etc/cinder/cinder.conf`.

```bash
sudo su -s /bin/sh -c "cinder-manage db sync" cinder
sudo systemctl enable --now cinder-api cinder-scheduler
```

## 3. Storage node

```bash
sudo apt install -y cinder-volume tgt open-iscsi
```

Create the volume group exactly as named in the config:

```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgs
```

If your disk is not `/dev/sdb`, adjust. Cinder refuses to start if the VG is missing.

Install [`configs/storage/cinder.conf`](../configs/storage/cinder.conf) as
`/etc/cinder/cinder.conf`. The backend block is the part that matters:

```ini
[lvm-iscsi]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm
target_ip_address = 10.10.10.41
volume_backend_name = lvm-iscsi
```

```bash
sudo systemctl enable --now tgt
sudo systemctl enable --now cinder-volume
```

`cinder-volume` needs to reach RabbitMQ, MariaDB and the Cinder API. Check:

```bash
nc -vz controller01 5672
nc -vz controller01 3306
nc -vz controller01 8776
```

## 4. Compute side

```bash
sudo apt install -y open-iscsi
sudo systemctl enable --now iscsid
```

Without `iscsiadm`, Nova reports the volume as attached but the guest never sees a device.

## 5. Verify

```bash
source ~/admin-openrc
openstack volume service list
```

Expected: `cinder-scheduler` and `cinder-volume` both `up`. The volume service host is
`storage01@lvm-iscsi`.

```bash
openstack volume create --size 1 demo-vol
openstack volume list
openstack volume show demo-vol -c status -c volume_type
```

Wait for `available`, then attach:

```bash
openstack server add volume cirros-01 demo-vol
openstack volume show demo-vol -c status -c attachments
```

Expected: `status: in-use`, attachments contains `cirros-01` and a device path such as
`/dev/vdb`.

Inside the guest:

```bash
ssh cirros@192.168.100.150
lsblk
# vda   1G  disk
# vdb   1G  disk
sudo mkfs.ext4 /dev/vdb
sudo mkdir -p /mnt/data && sudo mount /dev/vdb /mnt/data
df -h /mnt/data
```

On `storage01`, the iSCSI target should show a backing LV:

```bash
sudo tgtadm --mode target --op show | grep -E 'Target|Backing store'
sudo lvs
```

## 6. Gate check

- `cinder-volume` and `cinder-scheduler` are `up`.
- A 1 GiB volume reaches `available`.
- Attaching it sets `in-use` and produces `/dev/vdb` in the guest.
- `tgtadm` lists the target and the LVM logical volume as its backing store.

If the volume stays `creating`, check `journalctl -u cinder-volume` — the usual causes are a
missing VG, `tgt` not running, or `target_ip_address` pointing at an unreachable interface.

---

Next: [07 — Swift](07-swift.md)
