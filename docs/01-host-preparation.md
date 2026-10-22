# 01 — Host preparation

**Goal:** five Ubuntu 22.04 hosts with stable management addressing, synchronised clocks, the
Caracal package repo, and the provider bridge in place on `network01`.

Run the steps on every node unless marked otherwise.

---

## 1. Base OS and identity

Install Ubuntu Server 22.04 LTS (minimal). Then:

```bash
sudo hostnamectl set-hostname controller01     # compute01, compute02, network01, storage01
sudo apt update && sudo apt -y upgrade
sudo apt install -y software-properties-common chrony curl vim
```

Copy [`configs/hosts`](../configs/hosts) to `/etc/hosts` on all five nodes, then verify:

```bash
getent hosts controller01 compute01 compute02 network01 storage01
```

Every name must resolve to its `10.10.10.x` address before you continue — Keystone, RabbitMQ and
the APIs all use hostnames in their config.

## 2. Management network

Each host needs one management NIC. Confirm its name (it is rarely `eth0`):

```bash
ip -br link
```

> **network01 ordering:** its netplan file defines the OVS bridge `br-ex`, so install
> `openvswitch-switch` **before** applying netplan:
>
> ```bash
> sudo apt install -y openvswitch-switch
> ```

Copy the matching file from [`configs/netplan/`](../configs/netplan/) to
`/etc/netplan/01-openstack.yaml`, replace the interface name, then:

```bash
sudo netplan try      # auto-rolls back after 120 s if you lose connectivity
sudo netplan apply
ip -br address
ping -c2 10.10.10.11
```

## 3. Provider bridge (network01 only)

`network01` has a second NIC (`enp2s0`) that carries the flat provider network. It is enslaved to
`br-ex`, and **the bridge has no IP**: the router namespace owns the external gateway and the
floating IPs.

The netplan file [`configs/netplan/network01.yaml`](../configs/netplan/network01.yaml) does this
declaratively:

```bash
sudo apt install -y openvswitch-switch
sudo netplan apply
sudo ovs-vsctl show          # br-ex with enp2s0 as its only port
sudo ovs-vsctl list-ports br-ex
```

If netplan's OVS integration gives you trouble, use the imperative fallback instead (and remove
the `bridges:` block from netplan first):

```bash
sudo PROVIDER_IF=enp2s0 ./configs/ovs/br-ex.sh
```

> **Lockout warning:** enslaving the NIC that carries your SSH session will disconnect you. The
> fallback script refuses to do that; netplan will not.

## 4. Kernel and forwarding settings

Copy [`configs/sysctl/90-openstack.conf`](../configs/sysctl/90-openstack.conf) to
`/etc/sysctl.d/90-openstack.conf` and apply:

```bash
sudo sysctl --system
sysctl net.ipv4.ip_forward net.ipv4.conf.all.rp_filter
```

`ip_forward=1` is required on `network01`; the computes also route VXLAN traffic between the
overlay and the instance tap devices.

## 5. Time synchronisation

```bash
sudo systemctl enable --now chrony
chronyc tracking
timedatectl show -p NTPSynchronized --value    # yes
```

Skewed clocks cause `Unable to authenticate` and RabbitMQ heartbeat failures that look like
unrelated bugs.

## 6. OpenStack Caracal repository

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

## 7. Storage devices

### Cinder (storage01)

The volume group must be called `cinder-volumes`. With a dedicated disk:

```bash
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo vgs cinder-volumes
```

With a file-backed loop device (what the lab used for a quick rebuild):

```bash
sudo fallocate -l 50G /var/lib/cinder-volumes.img
LOOP=$(sudo losetup --find --show /var/lib/cinder-volumes.img)
sudo pvcreate "$LOOP"
sudo vgcreate cinder-volumes "$LOOP"
```

Loop devices do not survive a reboot; re-attach and `vgchange -ay cinder-volumes` after boot, or
use a real disk. Cinder will mark the backend down if the VG disappears.

### Swift (storage01, compute01, compute02)

One XFS filesystem per node, mounted at `/srv/node/d1`:

```bash
sudo apt install -y xfsprogs
sudo fallocate -l 20G /var/lib/swift-d1.img
sudo mkfs.xfs /var/lib/swift-d1.img
sudo mkdir -p /srv/node/d1
echo '/var/lib/swift-d1.img /srv/node/d1 xfs loop,noatime 0 0' | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R swift:swift /srv/node
df -h /srv/node/d1
```

## 8. Package baseline

```bash
# all nodes
sudo apt install -y python3-openstackclient chrony

# controller01
sudo apt install -y mariadb-server python3-pymysql rabbitmq-server memcached python3-memcache

# network01
sudo apt install -y openvswitch-switch

# compute01, compute02
sudo apt install -y qemu-kvm libvirt-daemon-system openvswitch-switch
```

## 9. Gate check

```bash
./scripts/00-preflight.sh
```

Expected: hostname, all five names resolve, NTP synchronised, OVS present where required, and
`br-ex` exists on `network01`. Do not proceed while anything reports `[FAIL]`.

---

Next: [02 — Keystone](02-keystone.md)
