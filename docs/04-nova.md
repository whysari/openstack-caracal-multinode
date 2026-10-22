# 04 — Nova (control plane and computes)

**Goal:** Nova API, scheduler, conductor and two compute nodes registered with Placement.
Controller steps run on `controller01`; compute steps on `compute01` and `compute02`.

---

## 1. Database and credentials (controller01)

```bash
sudo mysql <<'SQL'
CREATE DATABASE nova_api;
CREATE DATABASE nova;
CREATE DATABASE nova_cell0;
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_api.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'localhost' IDENTIFIED BY 'NOVA_DBPASS';
GRANT ALL PRIVILEGES ON nova_cell0.* TO 'nova'@'%' IDENTIFIED BY 'NOVA_DBPASS';
SQL
```

```bash
source ~/admin-openrc
openstack user create --domain default --password NOVA_PASS nova
openstack role add --project service --user nova admin
openstack service create --name nova --description "OpenStack Compute" compute
for iface in public internal; do
  openstack endpoint create --region RegionOne compute "$iface" http://controller01:8774/v2.1
done
openstack endpoint create --region RegionOne compute admin http://controller01:8774/v2.1
```

## 2. Controller packages and config

```bash
sudo apt install -y nova-api nova-conductor nova-novncproxy nova-scheduler
```

Install [`configs/controller/nova.conf`](../configs/controller/nova.conf) as `/etc/nova/nova.conf`.
Replace the placeholder passwords. `my_ip` must be `10.10.10.11`.

```bash
sudo su -s /bin/sh -c "nova-manage api_db sync" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 map_cell0" nova
sudo su -s /bin/sh -c "nova-manage cell_v2 create_cell --name=cell1 --verbose" nova
sudo su -s /bin/sh -c "nova-manage db sync" nova
sudo nova-manage cell_v2 list_cells
```

Expected: `cell0` and `cell1`, both with a working transport URL.

```bash
sudo systemctl enable --now nova-api nova-scheduler nova-conductor nova-novncproxy
```

## 3. Compute nodes

On **compute01** and **compute02**:

```bash
sudo apt install -y nova-compute
```

Install [`configs/compute/nova.conf`](../configs/compute/nova.conf) as `/etc/nova/nova.conf`.
Change `my_ip`, `server_proxyclient_address` and (if needed) `virt_type`.

```bash
# KVM requires vmx/svm; otherwise set virt_type = qemu
egrep -c '(vmx|svm)' /proc/cpuinfo
sudo systemctl enable --now libvirtd
sudo systemctl enable --now nova-compute
```

Check that the compute can reach the control plane before debugging Nova itself:

```bash
nc -vz controller01 5672    # RabbitMQ
nc -vz controller01 3306    # MariaDB
nc -vz controller01 8774    # Nova API
```

## 4. Register the computes

Back on `controller01`, after both computes have started:

```bash
source ~/admin-openrc
sudo nova-manage cell_v2 discover_hosts --verbose
openstack compute service list
openstack hypervisor list
```

Expected:

```
+----+----------------+------------+------+----------+---------+-------+
| ID | Binary         | Host       | Zone | Status   | State   | ...   |
+----+----------------+------------+------+----------+---------+-------+
| .. | nova-conductor | controller | nova | enabled  | up      | ...   |
| .. | nova-scheduler | controller | nova | enabled  | up      | ...   |
| .. | nova-compute   | compute01  | nova | enabled  | up      | ...   |
| .. | nova-compute   | compute02  | nova | enabled  | up      | ...   |
+----+----------------+------------+------+----------+---------+-------+
```

If a compute is missing, it has not registered with the message queue. Check
`journalctl -u nova-compute -n 100` for `AMQP` or authentication errors before anything else.

## 5. Flavor

```bash
openstack flavor create --vcpus 1 --ram 256 --disk 1 m1.tiny
openstack flavor list
```

Swift and Cinder do not need flavors, but the smoke test does.

## 6. Gate check

```bash
openstack compute service list
openstack hypervisor list
openstack hypervisor show compute01 -c vcpus -c memory_mb -c running_vms
```

All four services are `up`; both hypervisors are visible with the expected capacity.

---

Next: [05 — Neutron](05-neutron.md)
