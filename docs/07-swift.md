# 07 — Swift: three zones, three replicas

**Goal:** a Keystone-authenticated object store with a real 3-replica ring across
`storage01`, `compute01` and `compute02`, and a proxy on `controller01`.

This layout deliberately puts one Swift zone on each worker node. It is not the textbook
"dedicated storage nodes" design, but it fits five hosts and exercises real replication,
rebalancing and rsync.

| Node | Zone | Device | Ports |
|---|---|---|---|
| `storage01` | 1 | `/srv/node/d1` | 6200/6201/6202 |
| `compute01` | 2 | `/srv/node/d1` | 6200/6201/6202 |
| `compute02` | 3 | `/srv/node/d1` | 6200/6201/6202 |

---

## 1. Credentials and endpoint (controller01)

```bash
source ~/admin-openrc
openstack user create --domain default --password SWIFT_PASS swift
openstack role add --project service --user swift admin
openstack service create --name swift --description "OpenStack Object Storage" object-store

for iface in public internal; do
  openstack endpoint create --region RegionOne object-store "$iface" \
    'http://controller01:8080/v1/AUTH_%(project_id)s'
done
openstack endpoint create --region RegionOne object-store admin http://controller01:8080/v1
```

## 2. Prepare the three storage nodes

On `storage01`, `compute01` and `compute02`:

```bash
sudo apt install -y swift swift-account swift-container swift-object xfsprogs rsync

# one XFS filesystem per node
sudo fallocate -l 20G /var/lib/swift-d1.img
sudo mkfs.xfs /var/lib/swift-d1.img
sudo mkdir -p /srv/node/d1
echo '/var/lib/swift-d1.img /srv/node/d1 xfs loop,noatime 0 0' | sudo tee -a /etc/fstab
sudo mount -a
sudo chown -R swift:swift /srv/node
```

Install the shared configs:

- [`configs/storage/swift/swift.conf`](../configs/storage/swift/swift.conf) → `/etc/swift/swift.conf`
- [`configs/storage/swift/account-server.conf`](../configs/storage/swift/account-server.conf)
- [`configs/storage/swift/container-server.conf`](../configs/storage/swift/container-server.conf)
- [`configs/storage/swift/object-server.conf`](../configs/storage/swift/object-server.conf)
- [`configs/storage/swift/rsyncd.conf`](../configs/storage/swift/rsyncd.conf) → `/etc/rsyncd.conf`

`swift.conf` must contain the **same** hash prefix/suffix on every node. Generate one pair and
copy the file everywhere:

```bash
python3 - <<'PY'
import uuid
print("prefix:", uuid.uuid4().hex)
print("suffix:", uuid.uuid4().hex)
PY
```

Enable the rsync daemon:

```bash
echo 'RSYNC_ENABLE=true' | sudo tee /etc/default/rsync
sudo systemctl enable --now rsync
sudo ss -lntp | grep 873
```

Create the recon cache:

```bash
sudo mkdir -p /var/cache/swift
sudo chown -R root:swift /var/cache/swift
sudo chmod -R 775 /var/cache/swift
```

## 3. Proxy (controller01)

```bash
sudo apt install -y swift swift-proxy python3-swiftclient \
  python3-keystoneclient python3-keystonemiddleware memcached
```

Install [`configs/storage/swift/proxy-server.conf`](../configs/storage/swift/proxy-server.conf) as
`/etc/swift/proxy-server.conf`, and copy the shared
[`configs/storage/swift/swift.conf`](../configs/storage/swift/swift.conf) to `/etc/swift/swift.conf`.
The pipeline must keep `authtoken keystoneauth` in this order:

```
catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk tempurl
ratelimit authtoken keystoneauth copy container-quotas account-quotas slo dlo
versioned_writes symlink proxy-logging proxy-server
```

## 4. Build and distribute the rings (controller01)

```bash
cd /etc/swift
sudo chown -R "$USER":swift /etc/swift

for ring in account container object; do
  swift-ring-builder "$ring.builder" create 10 3 1
done
```

Add one device per zone. Ports differ per service: account `6202`, container `6201`, object
`6200`.

```bash
add() {
  local ring=$1 port=$2 zone=$3 ip=$4
  swift-ring-builder "$ring.builder" add --region 1 --zone "$zone" \
    --ip "$ip" --port "$port" --device d1 --weight 100
}

for ring in account container object; do
  case $ring in
    account)   port=6202 ;;
    container) port=6201 ;;
    object)    port=6200 ;;
  esac
  add "$ring" "$port" 1 10.10.10.41
  add "$ring" "$port" 2 10.10.10.21
  add "$ring" "$port" 3 10.10.10.22
  swift-ring-builder "$ring.builder" rebalance
  swift-ring-builder "$ring.builder"
done
```

Expected: `1024 partitions, 3.000000 replicas, 1 regions, 3 zones, 3 devices` and
`balance 0.00`.

Distribute the rings and `swift.conf`:

```bash
for host in storage01 compute01 compute02; do
  ssh "$host" 'mkdir -p /tmp/swift-dist'
  scp /etc/swift/*.ring.gz /etc/swift/swift.conf "$host":/tmp/swift-dist/
  ssh "$host" 'sudo mv /tmp/swift-dist/* /etc/swift/ && sudo chown root:swift /etc/swift/* && sudo chmod 640 /etc/swift/*.ring.gz'
done
```

The proxy on `controller01` also needs the three `.ring.gz` files in `/etc/swift`.

## 5. Start the services

On each storage node:

```bash
sudo systemctl enable --now swift-account swift-container swift-object 2>/dev/null \
  || sudo swift-init all start
sudo swift-init all status
```

On `controller01`:

```bash
sudo systemctl enable --now swift-proxy 2>/dev/null || sudo swift-init proxy start
sudo systemctl status swift-proxy --no-pager 2>/dev/null || true
```

## 6. Verify

```bash
source ~/admin-openrc
openstack object store account show
# Account: AUTH_<project-id>
# Containers: 0, Objects: 0, Bytes: 0

openstack container create demo-container
openstack object create demo-container README.md
openstack object list demo-container
openstack object save demo-container README.md --file /tmp/README.swift
cmp README.md /tmp/README.swift
```

Check placement. The ring builder shows the three devices; the object should exist on all three
nodes because `replicas=3`:

```bash
# on each storage node
sudo find /srv/node/d1/objects -type f | head
sudo grep -c "Object PUT" /var/log/swift/object.log 2>/dev/null || true
```

Replication happens asynchronously; give it a few seconds after the upload. On a healthy ring,
`swift-recon` (with credentials) reports no async pendings. The minimum useful check is that each
node has a copy of the same object hash.

## 7. Gate check

- `openstack object store account show` returns the project's account.
- PUT/GET round-trip matches byte-for-byte.
- `swift-ring-builder object.builder` reports 3 zones, 3 devices, 3 replicas, balance 0.
- `/srv/node/d1` contains object data on all three nodes.

If the proxy returns 503, the ring files are missing/mismatched or the storage services are not
listening:

```bash
ss -lntp | grep -E '6200|6201|6202'
sudo swift-init all status
sudo tail -50 /var/log/swift/proxy.log
```

---

Next: [08 — Horizon](08-horizon.md)
