# 04 — Nova: control plane and computes

**Goal:** Nova API, scheduler, conductor and two compute services, with KVM/libvirt on
`compute1` and `compute2`.

Run the database/credential steps and the control-plane steps on `controller`. Run the compute
steps on each compute node.

---

## 1. Databases and credentials (controller)

```bash
sudo mysql <<'SQL'
CREATE DATABASE nova;
CREATE DATABASE nova_api;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
SQL

source ~/admin-openrc
openstack user create --domain default --password NOVA_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute

for iface in public internal admin; do
  openstack endpoint create --region RegionOne compute "$iface" http://controller:8774/v2.1
done
```

## 2. Control plane (controller)

```bash
sudo apt install -y nova-api nova-conductor nova-scheduler nova-novncproxy
```

Copy [`configs/controller/nova.conf`](../configs/controller/nova.conf) to `/etc/nova/nova.conf`.
The important values:

```ini
[DEFAULT]
my_ip = 192.168.100.24
transport_url = rabbit://openstack:RABBIT_PASS@controller:5672/
use_neutron = true

[api_database]
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova_api

[database]
connection = mysql+pymysql://nova:NOVA_DBPASS@controller/nova

[glance]
api_servers = http://controller:9292

[neutron]
auth_url = http://controller:5000
service_metadata_proxy = true
metadata_proxy_shared_secret = METADATA_SECRET

[vnc]
server_listen = 192.168.100.24
server_proxyclient_address = 192.168.100.24
novncproxy_base_url = http://192.168.100.24:6080/vnc_auto.html
```

Populate the databases and create the cell:

```bash
sudo su -s /bin/sh -c "nova-manage api_db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
sudo su -s /bin/sh -c "nova-manage db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 list_cells" nova
```

```bash
sudo systemctl enable --now nova-api nova-scheduler nova-conductor nova-novncproxy
```

## 3. Compute nodes

On **both** `compute1` and `compute2`:

```bash
sudo apt install -y nova-compute
```

Copy the matching file:

| Host | File |
|---|---|
| `compute1` | [`configs/compute1/nova.conf`](../configs/compute1/nova.conf) |
| `compute2` | [`configs/compute2/nova.conf`](../configs/compute2/nova.conf) |

Key difference: `my_ip` and `server_proxyclient_address` are `.25` on `compute1` and `.26` on
`compute2`; `novncproxy_base_url` always points at `controller:6080`.

```bash
sudo systemctl enable --now nova-compute
```

If the host does not expose hardware virtualisation (`egrep -c '(vmx|svm)' /proc/cpuinfo` is
`0`), set `[libvirt] virt_type = qemu` in `nova.conf` and restart `nova-compute`.

## 4. Discover the computes (controller)

```bash
source ~/admin-openrc
sudo su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
openstack compute service list
openstack hypervisor list
```

Expected:

| Binary | Host | State |
|---|---|---|
| `nova-conductor` | `controller` | up |
| `nova-scheduler` | `controller` | up |
| `nova-compute` | `compute1` | up |
| `nova-compute` | `compute2` | up |

The lab capture also shows a `nova-compute` record on `controller`.
That is a leftover from an earlier all-in-one attempt, not part of this design. If it exists,
disable the unit and remove the stale service record:

```bash
sudo systemctl disable --now nova-compute    # only if installed on the controller by mistake
openstack compute service delete <service-id>
```

The demo capture also intentionally stopped `compute2`'s `nova-compute` and OVS agent. See
[11 — Completing the build](11-completing-the-build.md) to bring it back.

## 5. Gate check

- `openstack compute service list` shows both computes up.
- `openstack hypervisor list` shows `compute1` and `compute2`.
- `openstack resource provider list` shows a provider per compute.
- `/var/log/nova/nova-compute.log` has no libvirt or AMQP errors.

---

Next: [05 — Neutron](05-neutron.md)
