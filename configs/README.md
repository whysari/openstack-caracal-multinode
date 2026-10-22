# Configuration files

These are the actual files from the lab, with credentials replaced by placeholders. They are
committed so the deployment can be reviewed and reproduced — **do not commit real passwords**.

## Placeholders

| Placeholder | Used in | Meaning |
|---|---|---|
| `KEYSTONE_DBPASS` | `keystone.conf` | MariaDB password for the `keystone` user |
| `GLANCE_DBPASS` / `GLANCE_PASS` | `glance-api.conf` | Glance DB password / service password |
| `PLACEMENT_DBPASS` / `PLACEMENT_PASS` | `placement.conf`, `nova.conf` | Placement DB / service password |
| `NOVA_DBPASS` / `NOVA_PASS` | `nova.conf` | Nova DB / service password |
| `NEUTRON_DBPASS` / `NEUTRON_PASS` | `neutron.conf`, `nova.conf` | Neutron DB / service password |
| `CINDER_DBPASS` / `CINDER_PASS` | `cinder.conf` | Cinder DB / service password |
| `SWIFT_PASS` | `swift/proxy-server.conf` | Swift service password |
| `RABBIT_PASS` | all `transport_url` values | RabbitMQ `openstack` user password |
| `METADATA_SECRET` | `nova.conf`, `metadata_agent.ini` | Shared metadata proxy secret |
| `CHANGE_ME_HASH_*` | `swift/swift.conf` | Swift ring hash prefix/suffix |

Generate strong values, for example:

```bash
openssl rand -hex 16
```

Keep one copy in a password manager or an untracked `secrets.env`; never in this repository.

## Host-specific values

Only three things change between nodes:

- `my_ip` / `local_ip` (the node's `10.10.10.x` management address)
- the management NIC name in `netplan/*.yaml`
- Swift `bind_ip` (left as `0.0.0.0` here for readability)

Everything else is shared. The `configs/` tree is split by role, not by host, so `compute01` and
`compute02` use the same files with `10.10.10.21` replaced by `10.10.10.22`.
