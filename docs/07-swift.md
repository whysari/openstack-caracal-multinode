# 07 — Swift: proxy, rings and object servers

**Goal:** a working Swift object store with Keystone auth, a four-device ring and the proxy on
the controller.

The real cluster has **one object node** (`object`, `192.168.100.28`) and a **proxy on the
controller** (`controller:8080`). The proxy is the only Swift service on the controller; the
account, container and object servers run on `object`.

> **As-built note.** The initial lab notes describe the proxy on the object node and also show
> an intermediate `tempauth` configuration. The captured path —
> `openstack object create` against `controller:8080`, with an `AUTH_<project-id>` account —
> requires a Keystone-authenticated proxy on the controller. This repository documents that
> working split. If you prefer the proxy on `object`, change the endpoint to
> `http://object:8080` and keep the same Keystone pipeline.

---

## 1. Devices (object)

```bash
sudo mkdir -p /srv/node/{1,2,3,4}
sudo chown -R swift:swift /srv/node
ls -ld /srv/node/*
```

The four devices are directories on the root filesystem. The server configs therefore set
`mount_check = false`; on a real deployment each device would be its own mount.

## 2. Shared hash configuration

Generate one hash pair and put it in `/etc/swift/swift.conf` on **both** `controller` and
`object`:

```bash
python3 -c "import uuid; print(uuid.uuid4().hex)"
```

```ini
[swift-hash]
swift_hash_path_suffix = <generated-suffix>
swift_hash_path_prefix = <generated-prefix>

[storage-policy:0]
name = Policy-0
default = yes
```

The values must match exactly, or objects land in different partitions on different nodes.
[`configs/object/swift/swift.conf`](../configs/object/swift/swift.conf) is the template.

## 3. Build the rings (object)

```bash
sudo apt install -y swift
cd /etc/swift

swift-ring-builder account.builder create 10 3 1
swift-ring-builder container.builder create 10 3 1
swift-ring-builder object.builder create 10 3 1

for dev in 1 2 3 4; do
  swift-ring-builder account.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6002 --device "$dev" --weight 100
  swift-ring-builder container.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6001 --device "$dev" --weight 100
  swift-ring-builder object.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6000 --device "$dev" --weight 100
done

for b in account.builder container.builder object.builder; do
  swift-ring-builder "$b" rebalance
done

swift-ring-builder object.builder
# 10 partitions, 3.000000 replicas, 1 zones, 4 devices
```

The initial lab ring builder used 10 partitions, 3 replicas and a 1-hour `min_part_hours`, with
one zone. Four devices spread the replicas across four directories, but they are still on one
node: this is **not** node-level redundancy. Adding `object2`/`object3` later requires new
devices and a rebalance.

Copy the rings to the controller (the proxy reads them):

```bash
for f in /etc/swift/*.ring.gz; do
  sudo scp "$f" controller:/etc/swift/
done
sudo chown swift:swift /etc/swift/*.ring.gz
```

## 4. Object server configuration

On `object`, copy:

- [`configs/object/swift/account-server.conf`](../configs/object/swift/account-server.conf) →
  `/etc/swift/account-server.conf`
- [`configs/object/swift/container-server.conf`](../configs/object/swift/container-server.conf) →
  `/etc/swift/container-server.conf`
- [`configs/object/swift/object-server.conf`](../configs/object/swift/object-server.conf) →
  `/etc/swift/object-server.conf`
- [`configs/object/swift/rsyncd.conf`](../configs/object/swift/rsyncd.conf) → `/etc/rsyncd.conf`
- [`configs/object/swift/swift.conf`](../configs/object/swift/swift.conf) → `/etc/swift/swift.conf`

```bash
sudo systemctl enable --now rsync
sudo systemctl enable --now swift-account swift-container swift-object
# or, if the package uses the old init scripts:
sudo swift-init all start
```

## 5. Proxy configuration (controller)

```bash
sudo apt install -y swift-proxy memcached
```

Copy [`configs/controller/swift-proxy-server.conf`](../configs/controller/swift-proxy-server.conf)
to `/etc/swift/proxy-server.conf` and
[`configs/object/swift/swift.conf`](../configs/object/swift/swift.conf) to `/etc/swift/swift.conf`.

Key values:

```ini
[DEFAULT]
bind_ip = 192.168.100.24
bind_port = 8080

[pipeline:main]
pipeline = catch_errors gatekeeper healthcheck proxy-logging cache container_sync bulk tempurl ratelimit authtoken keystoneauth copy container-quotas account-quotas slo dlo versioned_writes symlink proxy-logging proxy-server

[filter:cache]
memcache_servers = 192.168.100.24:11211

[filter:authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
project_name = service
username = swift
password = SWIFT_PASS
```

Start:

```bash
sudo systemctl enable --now swift-proxy
sudo systemctl restart memcached
```

## 6. Keystone service and endpoints (controller)

```bash
source ~/admin-openrc
openstack user create --domain default --password SWIFT_PASS swift
openstack role add --project service --user swift admin
openstack service create --name swift --description "OpenStack Object Storage" object-store
openstack endpoint create --region RegionOne object-store public \
  http://controller:8080/v1/AUTH_%(project_id)s
openstack endpoint create --region RegionOne object-store internal \
  http://controller:8080/v1/AUTH_%(project_id)s
openstack endpoint create --region RegionOne object-store admin \
  http://controller:8080/v1/AUTH_%(project_id)s
```

## 7. Verify

```bash
source ~/demo-openrc
swift stat
# Account: AUTH_<project-id>
# Containers: 0, Objects: 0, Bytes: 0

openstack container create container3
echo "hello" > /tmp/variable.yml
openstack object create container3 /tmp/variable.yml
openstack object list container3
openstack object save container3 variable.yml --file /tmp/variable.roundtrip.yml
diff /tmp/variable.yml /tmp/variable.roundtrip.yml
```

Expected: the object is listed and the downloaded copy is identical.

Check the servers on `object`:

```bash
sudo systemctl status swift-account swift-container swift-object
sudo swift-init all status
ss -lntp | grep -E '600[0-2]'
```

Check the ring:

```bash
swift-ring-builder /etc/swift/object.builder
```

## 8. Gate check

- `swift stat` works with Keystone auth.
- Object PUT/GET round-trip is byte-identical.
- Ring reports 10 partitions, 3 replicas, 1 zone, 4 devices.
- No `503` in `/var/log/swift/proxy.log`.

---

Next: [08 — Horizon](08-horizon.md)
