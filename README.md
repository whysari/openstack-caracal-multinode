# OpenStack 2025.2 (Flamingo) Multi-Node Private Cloud -- Ground-Up Build

> **Note:** This repository documents a **100% from-scratch, ground-up build** of a 3-node **OpenStack 2025.2 (Flamingo)** private cloud deployed with **Kolla-Ansible (`21.3.0`)** on **Ubuntu 24.04.5 LTS (Noble Numbat)** (`6.8.0-147-generic`), paired with low-level **Linux Kernel (Cgroups v2, OOM Killer), LVM/iSCSI Storage, and Software-Defined Networking (Linux Namespaces, Open vSwitch, VXLAN)** verification labs. Every stage is backed by raw terminal outputs captured directly from the live cluster in [`evidence/`](evidence/).

---

## 1. Physical Host & Virtualization Lab Specifications

- **Hypervisor Host:** Windows 11 + VMware Workstation Pro 17
- **CPU:** Intel Core i5-9400F (6 Physical Cores @ 2.90 GHz, Hardware VT-x + EPT Nested Virtualization enabled, `/dev/kvm` verified across all nodes)
- **Host Memory:** 16 GB DDR4 (10.0 GiB allocated across the 3 cluster nodes + `zram` lz4 swap compression)
- **Base OS:** Ubuntu Server 24.04.5 LTS (`Linux 6.8.0-147-generic`)
- **OpenStack Release:** OpenStack 2025.2 (Flamingo) via `kolla-ansible==21.3.0` & `ansible-core==2.19.15` (`quay.io/openstack.kolla/*:2025.2-ubuntu-noble`)

---

## 2. 3-Node Cluster Topology & Network Planes

```mermaid
flowchart TB
    subgraph MGMT["Management & API Plane -- ens33 (VMnet8 NAT: 10.10.10.0/24, GW: 10.10.10.2)"]
        VIP["Kolla Internal VIP (HAProxy / Keepalived)<br/>10.10.10.250"]
        CTRL["controller (10.10.10.11)<br/>5.0 GiB RAM | 2 vCPU | sda 25G + sdb 20G<br/>Keystone, Glance, Placement, Nova Control,<br/>Neutron Server/L3/DHCP, Cinder LVM, MariaDB, RabbitMQ, Horizon"]
        COMP1["compute01 (10.10.10.21)<br/>2.5 GiB RAM | 2 vCPU (Nested KVM) | sda 25G<br/>nova-compute, nova-libvirt, openvswitch-agent<br/>Workload: cirros-vm-01"]
        COMP2["compute02 (10.10.10.22)<br/>2.5 GiB RAM | 2 vCPU (Nested KVM) | sda 25G<br/>nova-compute, nova-libvirt, openvswitch-agent<br/>Workload: cirros-vm-02"]
    end

    subgraph TUN["Tunnel / Overlay Plane -- ens34 (VMnet2 Host-Only: 10.10.20.0/24, VXLAN UDP 4789)"]
        CTRL_T["controller: 10.10.20.11"] <--> COMP1_T["compute01: 10.10.20.21"]
        CTRL_T <--> COMP2_T["compute02: 10.10.20.22"]
        COMP1_T <--> COMP2_T
    end

    subgraph EXT["External / Provider Plane -- ens32 (VMnet3: 10.10.30.0/24, OVS br-ex)"]
        HOST_GW["Windows Host Adapter (10.10.30.1)"] <--> BREX["OVS br-ex (ens32 unaddressed)<br/>Floating IP Pool: 10.10.30.100 - 10.10.30.150"]
    end
```

### Node Inventory

| Hostname | Role(s) | RAM / Swap | vCPU | Mgmt IP (`ens33`) | Tunnel IP (`ens34`) | External NIC (`ens32`) | Storage Disks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`controller`** | Control, Network, Storage (`controller@lvm-1`) | 5.0 GiB + zram | 2 (VT-x) | `10.10.10.11/24` (VIP `.250`) | `10.10.20.11/24` | Bridged in `br-ex` | `sda` (23G Root LV) + `sdb` (20G `cinder-volumes` VG) |
| **`compute01`** | Hypervisor #1 (KVM) + OVS Agent | 2.5 GiB + zram | 2 (VT-x) | `10.10.10.21/24` | `10.10.20.21/24` | Bridged in `br-ex` | `sda` (23G Root LV + Nova instances) |
| **`compute02`** | Hypervisor #2 (KVM) + OVS Agent | 2.5 GiB + zram | 2 (VT-x) | `10.10.10.22/24` | `10.10.20.22/24` | Bridged in `br-ex` | `sda` (23G Root LV + Nova instances) |

---

## 3. Engineering Runbooks & Live Evidence

| Module | Engineering Runbook | Verified Evidence Log | Status |
| :--- | :--- | :--- | :--- |
| **01. Host & 3-Plane Networking** | [`docs/01-host-and-network-setup.md`](docs/01-host-and-network-setup.md) | [`evidence/00-env-discovery.txt`](evidence/00-env-discovery.txt) | `[VERIFIED]` |
| **02. Linux Cgroups v2 & Cinder LVM** | [`docs/02-linux-cgroups-and-lvm.md`](docs/02-linux-cgroups-and-lvm.md) | [`evidence/01-week1-linux-lvm-cgroups.txt`](evidence/01-week1-linux-lvm-cgroups.txt) | `[VERIFIED]` |
| **03. Linux SDN, Namespaces & VXLAN** | [`docs/03-sdn-namespaces-vxlan.md`](docs/03-sdn-namespaces-vxlan.md) | [`evidence/02-week2-sdn-vxlan-mtu.txt`](evidence/02-week2-sdn-vxlan-mtu.txt) | `[VERIFIED]` |
| **04. Kolla-Ansible Multinode Deploy** | [`docs/04-kolla-ansible-deployment.md`](docs/04-kolla-ansible-deployment.md) | [`evidence/03-kolla-control-plane.txt`](evidence/03-kolla-control-plane.txt) | `[VERIFIED]` |
| **05. Workloads & Outage Drills** | `docs/05-workloads-and-failure-drills.md` *(in progress)* | `evidence/04-workloads-and-drills.txt` | `[IN PROGRESS]` |

---

## 4. Execution Roadmap & Live Verification Status

- [x] **Step 01 -- Hardware & VM Discovery:** Verified 3 Ubuntu 24.04.5 LTS nodes, `/dev/kvm` nested hardware virtualization, 3 NICs (`ens33`, `ens34`, `ens32`), and 20 GB raw block disk (`sdb`) on `controller` -> [`evidence/00-env-discovery.txt`](evidence/00-env-discovery.txt)
- [x] **Step 02 -- Base Networking, Root LVM Expansion & Week 1 Linux Internals:** -> [`evidence/01-week1-linux-lvm-cgroups.txt`](evidence/01-week1-linux-lvm-cgroups.txt)
  - Locked static Netplan IPs (`10.10.10.11/21/22` & `10.10.20.11/21/22`), unique hostnames, and passwordless SSH mesh (`~0.25 ms` inter-node RTT)
  - Expanded root LV (`ubuntu-lv`) from 11.5 GiB to full 23.0 GiB across all 3 nodes
  - Provisioned `cinder-volumes` LVM Volume Group (`20.00 GiB` free) on `controller:/dev/sdb`
  - Executed deterministic Cgroups v2 (`MemoryMax=32M`) OOM-killer drill and captured `CONSTRAINT_MEMCG` trace (`anon-rss:32512kB`)
- [x] **Step 03 -- Week 2 Software-Defined Networking (SDN) Drill:** -> [`evidence/02-week2-sdn-vxlan-mtu.txt`](evidence/02-week2-sdn-vxlan-mtu.txt)
  - Built isolated Linux network namespaces (`ns-vm1` on `compute01`, `ns-vm2` on `compute02`), `veth` pairs, and `br-sdn` bridges
  - Configured cross-node VXLAN overlay (`vxlan100`, VNI `100`, UDP `4789`) across `10.10.20.21 <-> 10.10.20.22` (`0.35 ms` RTT)
  - Proved the 50-byte VXLAN encapsulation overhead (`1450` bytes `-s 1422 -M do` PASS vs `1500` bytes `-s 1472 -M do` 100% packet loss)
- [x] **Step 04 -- Week 3 Kolla-Ansible Multinode Deployment (OpenStack 2025.2 Flamingo):** -> [`evidence/03-kolla-control-plane.txt`](evidence/03-kolla-control-plane.txt)
  - Deployed 37 control-plane containers on `controller` and 9 compute/SDN containers each on `compute01` and `compute02` with `failed=0`
  - Verified HAProxy/Keepalived VIP `10.10.10.250`, Keystone, Glance, Placement, Nova (`compute01` & `compute02` UP), Neutron (6 OVS/L3/DHCP/Metadata agents UP, `br-int`/`br-tun`/`br-ex` plumbed), Cinder (`controller@lvm-1` UP), and Horizon HTTP 200 OK
- [ ] **Step 05 -- Workload Verification & Failure Drills (Week 4):**
  - Upload CirrOS image to Glance, create Provider (`public-net` on `10.10.30.0/24`) and Self-Service VXLAN (`private-net` on `192.168.100.0/24`) networks, Neutron router, Security Groups, and SSH Keypair
  - Launch `cirros-vm-01` on `compute01` and `cirros-vm-02` on `compute02`
  - Verify cross-node VXLAN East-West traffic, Floating IP North-South ping/SSH, Cinder iSCSI volume attach (`/dev/vdb`), and failure/recovery drills
