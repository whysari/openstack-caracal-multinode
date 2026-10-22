# 06 — Cinder: LVM/iSCSI block storage

**Goal:** a Cinder API/scheduler on `controller` and a working `cinder-volume` on `block`,
backed by the `cinder-volumes` LVM volume group and exported over iSCSI with `tgt`.

---

## 1. Database and credentials (controller)

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
for iface in public internal admin; do
  openstack endpoint create --region RegionOne volumev3 "$iface" \
    "http://controller:8776/v3/%(project_id)s"
done
```

## 2. Controller: API and scheduler

```bash
sudo apt install -y cinder-api cinder-scheduler
```

Copy [`configs/controller/cinder.conf`](../configs/controller/cinder.conf) to
`/etc/cinder/cinder.conf`:

```ini
[DEFAULT]
my_ip = 192.168.100.24
transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/
glance_api_servers = http://controller:9292

[database]
connection = mysql+pymysql://cinder:CINDER_DBPASS@controller/cinder

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
project_name = service
username = cinder
password = CINDER_PASS
```

```bash
sudo su -s /bin/sh -c "cinder-manage db sync" cinder
sudo systemctl enable --now cinder-api cinder-scheduler
```

## 3. Block node: LVM and tgt

On `block`:

```bash
sudo apt install -y cinder-volume lvm2 tgt
```

### LVM filter

Copy the `devices` block from [`configs/block/lvm.conf`](../configs/block/lvm.conf) into
`/etc/lvm/lvm.conf`:

```ini
devices {
    filter = [ "a/sda/", "a/sdb/", "r/.*/" ]
}
```

Only the OS disk (`sda`) and the Cinder data disk (`sdb`) are scanned. Without this filter, LVM
can scan the iSCSI volumes Cinder creates and corrupt them.

### Volume group

```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgs cinder-volumes
```

### tgt include

Copy [`configs/block/tgt-cinder.conf`](../configs/block/tgt-cinder.conf) to
`/etc/tgt/conf.d/cinder.conf`:

```
include /var/lib/cinder/volumes/*
```

```bash
sudo systemctl enable --now tgt
```

### Cinder volume service

Copy [`configs/block/cinder.conf`](../configs/block/cinder.conf) to `/etc/cinder/cinder.conf`:

```ini
[DEFAULT]
my_ip = 192.168.100.27
enabled_backends = lvm

[lvm]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group = cinder-volumes
target_protocol = iscsi
target_helper = tgtadm
volume_backend_name = lvm
```

Start it:

```bash
sudo systemctl enable --now cinder-volume
```

## 4. Verify

```bash
source ~/admin-openrc
openstack volume service list
```

Expected:

| Binary | Host | Zone | State |
|---|---|---|---|
| `cinder-scheduler` | `controller` | nova | up |
| `cinder-volume` | `block@lvm` | nova | up |

The backend name is `lvm` — the lab build used `[lvm]` and `block@lvm`, not
`lvm-iscsi`.

Create and attach a volume:

```bash
openstack volume create --size 1 demo-vol
openstack volume list

openstack server add volume selfservice-demo0 demo-vol
openstack volume show demo-vol -c status -c attachments
# status: in-use
```

Inside the guest, check for a second disk:

```bash
cat /proc/partitions
# vdb (or sdb) with the volume size
```

## 5. Gate check

- `cinder-volume` is `up` on `block@lvm`.
- A 1 GiB volume reaches `available`, then `in-use` after attach.
- `/dev/sdb` is the only non-OS disk in the VG.
- `tgtadm --mode target --op show` lists the exported volume.

---

Next: [07 — Swift](07-swift.md)
