# Configuration files

These are the actual files from the lab, with credentials replaced by placeholders. They are
committed so the deployment can be reviewed and reproduced — **do not commit real passwords**.

## Layout

| Directory | Host | Contents |
|---|---|---|
| `controller/` | `controller` | Keystone, Glance, Placement, Nova API/scheduler/conductor, Neutron server + L3/DHCP/metadata/OVS agents, Cinder API/scheduler, Horizon, Swift proxy, Etcd |
| `compute1/` | `compute1` | `nova.conf`, `neutron.conf`, `openvswitch_agent.ini` for `192.168.100.25` |
| `compute2/` | `compute2` | same files for `192.168.100.26` |
| `block/` | `block` | `cinder.conf` (`[lvm]`), LVM filter, `tgt` include |
| `object/swift/` | `object` | account/container/object servers, `swift.conf`, `rsyncd.conf` |
| `netplan/` | all | per-host static addressing; the controller uses `br-ex` |
| `ovs/` | controller | imperative `br-ex` fallback |
| `sysctl/` | all | forwarding and `rp_filter` |
| `hosts` | all | `/etc/hosts` for the five nodes |

The controller's Swift proxy is `controller/swift-proxy-server.conf`; the object node's data
servers are under `object/swift/`.

## Placeholders

| Placeholder | Used in | Meaning |
|---|---|---|
| `KEYSTONE_DBPASS` | `keystone.conf` | MariaDB password for the `keystone` user |
| `GLANCE_DBPASS` / `GLANCE_PASS` | `glance-api.conf` | Glance DB password / service password |
| `PLACEMENT_DBPASS` / `PLACEMENT_PASS` | `placement.conf`, `nova.conf` | Placement DB / service password |
| `NOVA_DBPASS` / `NOVA_PASS` | `nova.conf` | Nova DB / service password |
| `NEUTRON_DBPASS` / `NEUTRON_PASS` | `neutron.conf`, `nova.conf` | Neutron DB / service password |
| `CINDER_DBPASS` / `CINDER_PASS` | `cinder.conf` | Cinder DB / service password |
| `SWIFT_PASS` | `swift-proxy-server.conf`, Keystone | Swift service password |
| `RABBIT_PASS` | all `transport_url` values | RabbitMQ `openstack` user password |
| `METADATA_SECRET` | `nova.conf`, `metadata_agent.ini` | Shared metadata proxy secret |
| `CHANGE_ME_HASH_*` | `object/swift/swift.conf` | Swift ring hash prefix/suffix |

Generate strong values:

```bash
openssl rand -hex 16
```

Keep one copy in a password manager or an untracked `secrets.env`; never in this repository.

## Host-specific values

Only four things change between hosts:

- `my_ip` / `local_ip` — `.24` controller, `.25` compute1, `.26` compute2, `.27` block,
  `.28` object.
- The management NIC name in `netplan/*.yaml` (`enp1s0` is a placeholder).
- The controller's `br-ex` bridge — see `netplan/controller.yaml`.
- Swift `bind_ip` — proxy on `.24`; data servers on `0.0.0.0` (pin them to `.28` in a less
  trusting environment).

The tree is split by role, not by package, so `compute1` and `compute2` have explicit copies
rather than a shared file with an edited IP.

## Files that must match across nodes

- `/etc/swift/swift.conf` (hash prefix/suffix) — controller and object.
- `/etc/swift/*.ring.gz` — controller and object.
- `/etc/hosts` — all five nodes.
- NTP/time zone — all five nodes.
