# 04 -- Multi-Node OpenStack 2025.2 (Flamingo) Deployment via Kolla-Ansible

## 1. Architectural Overview

In this stage, we deployed a production-grade, containerized **OpenStack 2025.2 (Flamingo)** cloud across our 3 **Ubuntu 24.04.5 LTS (`Noble Numbat`)** nodes using **Kolla-Ansible (`21.3.0`)** and **Ansible Core (`2.19.15`)**.

### 1.1 Control & Data Plane Service Distribution
| Plane / Layer | Services (`quay.io/openstack.kolla/*:2025.2-ubuntu-noble`) | Target Node(s) | Purpose |
| :--- | :--- | :--- | :--- |
| **HA Ingress & Load Balancing** | `keepalived`, `haproxy`, `proxysql` | `controller` (`VIP 10.10.10.250` on `ens33`) | Floating Virtual IP and L4/L7 load balancing across all OpenStack APIs and MariaDB. |
| **State & Messaging** | `mariadb`, `rabbitmq`, `memcached` | `controller` | Relational persistence, AMQP RPC message bus, and Keystone Fernet token caching. |
| **Control Plane APIs** | `keystone`, `glance_api`, `placement_api`, `nova_api`, `nova_scheduler`, `nova_conductor`, `nova_novncproxy`, `neutron_server`, `cinder_api`, `cinder_scheduler`, `heat_api`, `horizon` | `controller` | Identity, image registry, resource placement, compute scheduling, SDN orchestration, block storage API, and web dashboard (`http://10.10.10.250`). |
| **SDN Routing & Edge (`Neutron`)** | `openvswitch_db`, `openvswitch_vswitchd`, `neutron_openvswitch_agent`, `neutron_l3_agent`, `neutron_dhcp_agent`, `neutron_metadata_agent` | `controller` (L3/DHCP/Metadata + OVS), `compute01` (OVS), `compute02` (OVS) | Manages `br-int`, `br-tun` (VXLAN over `ens34`), and `br-ex` (External provider bridge on `ens32`), plus `qrouter` and `qdhcp` namespaces. |
| **Hypervisor Compute (`Nova`)** | `nova_libvirt`, `nova_compute`, `nova_ssh`, `iscsid` | `compute01`, `compute02` | Hardware-accelerated KVM/QEMU execution (`/dev/kvm`) and iSCSI volume attachment initiator. |
| **Block Storage (`Cinder`)** | `cinder_volume`, `tgtd`, `iscsid` | `controller` (`controller@lvm-1` on `/dev/sdb`) | Carves Logical Volumes from the 20 GiB `cinder-volumes` VG and exports them via iSCSI (`tgtd`) to compute nodes. |

### 1.2 Engineering Optimizations for a 16 GB Host Memory Budget
Running 37 control-plane containers on `controller` alongside 2 KVM compute nodes inside 10.0 GiB total VM RAM required three targeted optimizations in [`configs/kolla/globals.yml`](../configs/kolla/globals.yml):
1. **`openstack_service_workers: "1"` & `openstack_service_rpc_workers: "1"`:** Caps Gunicorn/uWSGI and Oslo RPC worker forks to 1 per service instead of `vCPU * 2`, reducing control-plane Python memory footprint by ~60%.
2. **`enable_fluentd: "no"`:** Disables heavy Ruby/Fluentd log shipping daemons on every node while retaining native `docker logs` and systemd journal access.
3. **ZRAM Compressed Swap (`zram0`):** Provides fast in-memory `lz4` swap compression on all 3 nodes.

---

## 2. Deployment Commands Executed (`controller`)

### 2.1 Virtual Environment & Kolla-Ansible 2025.2 Installation
```bash
python3 -m venv --system-site-packages ~/kolla-venv
source ~/kolla-venv/bin/activate

pip install -U pip
pip install "ansible-core>=2.18,<2.20" docker pkgconfig dbus-python
pip install git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
kolla-ansible install-deps
```

### 2.2 Configuration & Inventory Setup
- Configuration files committed in repository:
  - [`configs/kolla/globals.yml`](../configs/kolla/globals.yml)
  - [`configs/kolla/multinode`](../configs/kolla/multinode)
```bash
sudo mkdir -p /etc/kolla
sudo chown $USER:$USER /etc/kolla
cp ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/passwords.yml /etc/kolla/passwords.yml
kolla-genpwd
sed -i 's/^keystone_admin_password:.*/keystone_admin_password: OpenStack2026!/' /etc/kolla/passwords.yml
```

### 2.3 Bootstrap, Precheck, Deploy & Post-Deploy
```bash
kolla-ansible -i /etc/kolla/multinode bootstrap-servers
kolla-ansible -i /etc/kolla/multinode prechecks
kolla-ansible -i /etc/kolla/multinode deploy
kolla-ansible -i /etc/kolla/multinode post-deploy

pip install -U python-openstackclient
source /etc/kolla/admin-openrc.sh
```

---

## 3. Verified Live Cluster State

### 3.1 Playbook Recap (`0` Failures)
- **`prechecks`:** `controller: ok=114 failed=0`, `compute01: ok=40 failed=0`, `compute02: ok=40 failed=0`
- **`deploy`:** `controller: ok=421 changed=273 failed=0`, `compute01: ok=92 changed=59 failed=0`, `compute02: ok=89 changed=57 failed=0`
- **`post-deploy`:** `localhost: ok=9 changed=5 failed=0`

### 3.2 Nova Compute & Hypervisors
```text
+--------------------------------------+----------------+------------+----------+---------+-------+
| ID                                   | Binary         | Host       | Zone     | Status  | State |
+--------------------------------------+----------------+------------+----------+---------+-------+
| 8015d4d8-f2fe-46ac-8791-b18b815539e2 | nova-scheduler | controller | internal | enabled | up    |
| 6849074c-0618-4e76-a0be-f166c0b2e124 | nova-conductor | controller | internal | enabled | up    |
| 676b96b7-6aa0-4fe4-9921-800eba2c4c73 | nova-compute   | compute01  | nova     | enabled | up    |
| dda5bbf5-9e78-44a2-af52-0bc5a02468f5 | nova-compute   | compute02  | nova     | enabled | up    |
+--------------------------------------+----------------+------------+----------+---------+-------+
```

### 3.3 Neutron SDN Agents & Open vSwitch Bridges (`br-int`, `br-tun`, `br-ex`)
```text
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| ID                                   | Agent Type         | Host       | Availability Zone | Alive | State | Binary                    |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
| 693b750b-7521-4f5b-be05-acdc94e37436 | Open vSwitch agent | controller | None              | :-)   | UP    | neutron-openvswitch-agent |
| 728c624d-8d9a-4bd1-9fc0-452230b04b29 | Open vSwitch agent | compute02  | None              | :-)   | UP    | neutron-openvswitch-agent |
| 7aa42616-7eef-4ffe-9d6f-a9f1bddc0ced | L3 agent           | controller | nova              | :-)   | UP    | neutron-l3-agent          |
| 7bc2e4db-2bd5-4311-a767-e1c6019f06d0 | Open vSwitch agent | compute01  | None              | :-)   | UP    | neutron-openvswitch-agent |
| ebc7f808-7c21-440a-ac02-a399ca5f6abe | Metadata agent     | controller | None              | :-)   | UP    | neutron-metadata-agent    |
| fbb441b0-77ea-4a8a-8ed1-1407ced9fcaf | DHCP agent         | controller | nova              | :-)   | UP    | neutron-dhcp-agent        |
+--------------------------------------+--------------------+------------+-------------------+-------+-------+---------------------------+
```
- **OVS Patch Port Plumbing Verified (`ovs-vsctl show`):**
  - `br-int` <-> `br-tun` connected via `patch-tun` / `patch-int`
  - `br-int` <-> `br-ex` connected via `int-br-ex` / `phy-br-ex` with physical interface `ens32` enslaved to `br-ex`

### 3.4 Cinder LVM Block Storage Service
```text
+------------------+------------------+------+---------+-------+
| Binary           | Host             | Zone | Status  | State |
+------------------+------------------+------+---------+-------+
| cinder-scheduler | controller       | nova | enabled | up    |
| cinder-volume    | controller@lvm-1 | nova | enabled | up    |
+------------------+------------------+------+---------+-------+
```

- **Full Raw Evidence Log (314 lines):** [`evidence/03-kolla-control-plane.txt`](../evidence/03-kolla-control-plane.txt)
