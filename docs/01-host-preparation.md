# 01 — Host preparation

**Goal:** five Ubuntu 22.04 hosts with stable addressing, synchronised clocks, the Caracal
package repo, and the provider bridge in place on the controller.

The cluster has three physical nodes (`controller`, `compute1`, `compute2`) and two virtual
machines (`block`, `object`). All five sit on `192.168.100.0/24`.

Run the steps on every node unless marked otherwise.

---

## 1. Base OS and identity

Install Ubuntu Server 22.04 LTS (minimal). Then:

```bash
sudo hostnamectl set-hostname controller   # compute1, compute2, block, object
sudo apt update && sudo apt -y upgrade
sudo apt install -y software-properties-common chrony curl vim
```

Copy [`configs/hosts`](../configs/hosts) to `/etc/hosts` on all five nodes, then verify:

```bash
getent hosts controller compute1 compute2 block object
```

Every name must resolve to its `192.168.100.x` address before you continue — Keystone,
RabbitMQ and the APIs all use hostnames in their config.

## 2. Addressing

Each host has one NIC. Confirm its name (it is rarely `eth0`):

```bash
ip -br link
```

### Controller: `br-ex` carries the host address

The controller is also the Neutron network node. Its physical NIC is enslaved to the OVS
bridge `br-ex`, and `192.168.100.24/24` lives on the bridge. This is the single-NIC variant of
the install guide: management and provider traffic share the same L2 segment.

Install OVS **before** applying netplan:

```bash
sudo apt install -y openvswitch-switch
```

Copy [`configs/netplan/controller.yaml`](../configs/netplan/controller.yaml) to
`/etc/netplan/01-openstack.yaml`, replace `enp1s0` with the real interface name, then:

```bash
sudo netplan try      # auto-rolls back after 120 s if you lose connectivity
sudo netplan apply
ip -br address
ovs-vsctl show        # br-ex with the physical NIC as its port
ping -c2 192.168.100.1
```

> **Lockout warning:** if you apply the bridge manually over SSH, you can cut your own session.
> Prefer `netplan try`; use [`configs/ovs/br-ex.sh`](../configs/ovs/br-ex.sh) only from a
> console with `ALLOW_LOCKOUT=1`.

### Computes and storage VMs

Copy the matching file from [`configs/netplan/`](../configs/netplan/) to
`/etc/netplan/01-openstack.yaml`:

| Host | File | Address |
|---|---|---|
| `compute1` | `compute1.yaml` | `192.168.100.25/24` |
| `compute2` | `compute2.yaml` | `192.168.100.26/24` |
| `block` | `block.yaml` | `192.168.100.27/24` |
| `object` | `object.yaml` | `192.168.100.28/24` |

Gateway `192.168.100.1`; DNS `1.1.1.1`, `8.8.8.8`. Replace the interface name and apply:

```bash
sudo netplan try
sudo netplan apply
ip -br address
```

## 3. Kernel and forwarding settings

Copy [`configs/sysctl/90-openstack.conf`](../configs/sysctl/90-openstack.conf) to
`/etc/sysctl.d/90-openstack.conf` and apply:

```bash
sudo sysctl --system
sysctl net.ipv4.ip_forward net.ipv4.conf.all.rp_filter
```

`ip_forward=1` is required on the controller (router namespace and NAT) and on the computes
(overlay-to-tap forwarding).

## 4. Time synchronisation

```bash
sudo systemctl enable --now chrony
chronyc tracking
timedatectl show -p NTPSynchronized --value    # yes
```

Skewed clocks cause `Unable to authenticate` and RabbitMQ heartbeat failures that look like
unrelated bugs. On a fully offline lab, point `chrony` at the controller and let the controller
use the host clock or an upstream NTP server.

## 5. OpenStack Caracal repository

```bash
sudo add-apt-repository -y cloud-archive:caracal
sudo apt update
sudo apt install -y python3-openstackclient
openstack --version
```

Hold the release so a later dist-upgrade does not silently move the cluster to a newer OpenStack:

```bash
sudo apt-mark hold 'python3-*openstack*' 'nova-*' 'neutron-*' 'cinder-*' 'swift-*' \
  'keystone' 'glance' 'placement-*' 'openstack-dashboard'
```

## 6. Storage preparation

### Block node — Cinder LVM

The volume group must be called `cinder-volumes`. With a dedicated disk (`/dev/sdb` in the
original build):

```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgs cinder-volumes
```

With a file-backed loop device (quick lab rebuild):

```bash
sudo fallocate -l 50G /var/lib/cinder-volumes.img
LOOP=$(sudo losetup --find --show /var/lib/cinder-volumes.img)
sudo pvcreate "$LOOP"
sudo vgcreate cinder-volumes "$LOOP"
```

Loop devices do not survive a reboot; re-attach and `vgchange -ay cinder-volumes` after boot,
or use a real disk. Cinder marks the backend down if the VG disappears.

### Object node — Swift devices

The original build used four directories, not four disks:

```bash
sudo mkdir -p /srv/node/{1,2,3,4}
sudo chown -R swift:swift /srv/node
```

Because these are directories on the root filesystem, the Swift server configs set
`mount_check = false`. On a real deployment each device would be a separate filesystem and
`mount_check` would be `true`. Add `xfsprogs` and mount real disks if you have them.

## 7. Package baseline

```bash
# all nodes
sudo apt install -y python3-openstackclient chrony

# controller
sudo apt install -y mariadb-server python3-pymysql rabbitmq-server memcached \
  python3-memcache etcd-server etcd-client apache2

# compute1, compute2
sudo apt install -y qemu-kvm libvirt-daemon-system libvirt-clients \
  openvswitch-switch

# block
sudo apt install -y lvm2 tgt

# object
sudo apt install -y swift swift-account swift-container swift-object \
  swift-proxy rsync
```

## 8. Gate check

```bash
./scripts/00-preflight.sh
```

Expected: hostname, all five names resolve, NTP synchronised, OVS present on the controller
and computes, `br-ex` carries `192.168.100.24/24`, and the block/object storage prerequisites
exist. Do not proceed while anything reports `[FAIL]`.

---

Next: [02 — Keystone](02-keystone.md)
