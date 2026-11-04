# OpenStack 2024.1 (Caracal) Multi-Node Private Cloud — Ground-Up Build

> **Note:** This repository documents a **100% from-scratch, ground-up build** of a 3-node OpenStack 2024.1 (Caracal) private cloud deployed with **Kolla-Ansible** on **Ubuntu 24.04.5 LTS (Noble Numbat)** (`6.8.0-147-generic`), paired with low-level **Linux Kernel (Cgroups v2, OOM Killer), LVM/iSCSI Storage, and Software-Defined Networking (Linux Namespaces, Open vSwitch, VXLAN)** verification labs. Every stage is backed by raw terminal outputs captured directly from the live cluster in [`evidence/`](evidence/).

---

## 1. Physical Host & Virtualization Lab Specifications

- **Hypervisor Host:** Windows 11 + VMware Workstation Pro 17
- **CPU:** Intel Core i5-9400F (6 Physical Cores @ 2.90 GHz, Hardware VT-x + EPT Nested Virtualization enabled, `/dev/kvm` verified across all nodes)
- **Host Memory:** 16 GB DDR4 (10.0 GiB allocated across the 3 cluster nodes + `zram` lz4 swap compression)
- **Base OS:** Ubuntu Server 24.04.5 LTS (`Linux 6.8.0-147-generic`)
- **Deployment Method:** Kolla-Ansible (Dockerized OpenStack Control & Data Plane with HAProxy/Keepalived VIP)

---

## 2. 3-Node Cluster Topology & Network Planes

```mermaid
flowchart TB
    subgraph MGMT["Management & API Plane — ens33 (VMnet8 NAT: 10.10.10.0/24, GW: 10.10.10.2)"]
        VIP["Kolla Internal VIP (HAProxy / Keepalived)<br/>10.10.10.250"]
        CTRL["controller (10.10.10.11)<br/>5.0 GiB RAM | 2 vCPU | sda 25G + sdb 20G<br/>Keystone, Glance, Placement, Nova Control,<br/>Neutron Server/L3/DHCP, Cinder LVM, MariaDB, RabbitMQ"]
        COMP1["compute01 (10.10.10.21)<br/>2.5 GiB RAM | 2 vCPU (Nested KVM) | sda 25G<br/>nova-compute, libvirtd, openvswitch-agent<br/>Workload: cirros-vm-01"]
        COMP2["compute02 (10.10.10.22)<br/>2.5 GiB RAM | 2 vCPU (Nested KVM) | sda 25G<br/>nova-compute, libvirtd, openvswitch-agent<br/>Workload: cirros-vm-02"]
    end

    subgraph TUN["Tunnel / Overlay Plane — ens34 (VMnet2 Host-Only: 10.10.20.0/24, VXLAN UDP 4789)"]
        CTRL_T["controller: 10.10.20.11"] <--> COMP1_T["compute01: 10.10.20.21"]
        CTRL_T <--> COMP2_T["compute02: 10.10.20.22"]
        COMP1_T <--> COMP2_T
    end

    subgraph EXT["External / Provider Plane — ens32 (VMnet3: 10.10.30.0/24, OVS br-ex)"]
        HOST_GW["Windows Host Adapter (10.10.30.1)"] <--> BREX["OVS br-ex (ens32 unaddressed)<br/>Floating IP Pool: 10.10.30.100 - 10.10.30.150"]
    end
```

### Node Inventory

| Hostname | Role(s) | RAM / Swap | vCPU | Mgmt IP (`ens33`) | Tunnel IP (`ens34`) | External NIC (`ens32`) | Storage Disks |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`controller`** | Control, Network, Storage (Cinder LVM) | 5.0 GiB + zram | 2 (VT-x) | `10.10.10.11/24` | `10.10.20.11/24` | Unaddressed (`br-ex`) | `sda` (25G OS) + `sdb` (20G `cinder-volumes` VG) |
| **`compute01`** | Hypervisor #1 (KVM) + OVS Agent | 2.5 GiB + zram | 2 (VT-x) | `10.10.10.21/24` | `10.10.20.21/24` | Unaddressed (`br-ex`) | `sda` (25G OS + Nova instances) |
| **`compute02`** | Hypervisor #2 (KVM) + OVS Agent | 2.5 GiB + zram | 2 (VT-x) | `10.10.10.22/24` | `10.10.20.22/24` | Unaddressed (`br-ex`) | `sda` (25G OS + Nova instances) |

---

## 3. Execution Roadmap & Live Verification Status

- [x] **Step 01 — Hardware & VM Discovery:** Verified 3 Ubuntu 24.04.5 LTS nodes, `/dev/kvm` nested hardware virtualization, 3 NICs (`ens33`, `ens34`, `ens32`), and 20 GB raw block disk (`sdb`) on `controller` → [`evidence/00-env-discovery.txt`](evidence/00-env-discovery.txt)
- [ ] **Step 02 — Base Networking, Root LVM Expansion & Week 1 Linux Internals:**
  - Lock static Netplan IPs (`10.10.10.11/21/22` & `10.10.20.11/21/22`), unique hostnames, and SSH mesh
  - Expand root LV (`ubuntu-lv`) from 11.5G to full 23G across all nodes for Docker container storage
  - Provision `cinder-volumes` LVM Volume Group on `controller:/dev/sdb`
  - Execute Cgroups v2 (`MemoryMax`, `CPUQuota`) and Linux Kernel OOM-killer verification drill
- [ ] **Step 03 — Week 2 Software-Defined Networking (SDN) Drill:**
  - Isolated Linux network namespaces (`ip netns`), `veth` pairs, and VXLAN encapsulation / MTU verification prior to OpenStack deployment
- [ ] **Step 04 — Week 3 Kolla-Ansible Multinode Deployment:**
  - Bootstrap servers, deploy MariaDB, RabbitMQ, Keystone, Glance, Placement, Nova (KVM), Neutron (ML2/OVS), Cinder (LVM/iSCSI), and Horizon via `kolla-ansible -i multinode deploy`
- [ ] **Step 05 — Workload Verification & Failure Drills (Week 4):**
  - Launch `cirros-vm-01` on `compute01` and `cirros-vm-02` on `compute02`
  - Verify cross-node VXLAN East-West traffic, Cinder volume attach, Floating IP North-South reachability, and outage drills
