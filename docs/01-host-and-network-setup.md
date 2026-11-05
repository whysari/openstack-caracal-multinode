# 01 — Host Virtualization, Root LVM Expansion & 3-Plane Network Architecture

## 1. Architectural Purpose

Before deploying OpenStack services or container runtimes, a production-grade private cloud requires:
1. **Hardware-Assisted Virtualization (`VT-x/EPT`):** Exposing `/dev/kvm` inside the compute nodes (`compute01`, `compute02`) so guest instances run with hardware acceleration (`virt_type = kvm`) rather than software emulation.
2. **Root Volume Capacity:** Expanding Ubuntu Server's default 50% LVM root allocation (`11.5 GiB` -> `23.0 GiB`) so Docker images and OpenStack container layers under `/var/lib/docker` do not exhaust disk space.
3. **Strict 3-Plane Network Segmentation:**
   - **`ens33` (Management & API Plane — `10.10.10.0/24`):** Carries internal REST API calls, MariaDB, RabbitMQ, Ansible orchestration, and NAT outbound access (`GW 10.10.10.2`).
   - **`ens34` (Tunnel / Overlay Plane — `10.10.20.0/24`):** Dedicated point-to-point transport network for Neutron VXLAN (`UDP 4789`) tenant traffic between `controller`, `compute01`, and `compute02`.
   - **`ens32` (External / Provider Plane — `10.10.30.0/24`):** Brought `UP` without an IP address on the Linux host so Open vSwitch (`br-ex`) can bridge North-South Floating IP traffic directly.

---

## 2. Executed Commands (All 3 Nodes)

### 2.1 Root LVM Logical Volume Expansion
```bash
df -h /
sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
df -h /
```

### 2.2 Clone Identity Reset & Host Resolution (`/etc/hosts`)
```bash
sudo rm -f /etc/machine-id /var/lib/dbus/machine-id
sudo dbus-uuidgen --ensure=/etc/machine-id
sudo dbus-uuidgen --ensure
sudo dpkg-reconfigure openssh-server

sudo tee /etc/hosts << 'EOF'
127.0.0.1 localhost

10.10.10.11 controller
10.10.10.21 compute01
10.10.10.22 compute02
EOF
```

### 2.3 Static 3-NIC Netplan Configuration (`/etc/netplan/01-netcfg.yaml`)
See the exact node configurations in [`configs/netplan/`](../configs/netplan/):
- [`configs/netplan/controller.yaml`](../configs/netplan/controller.yaml) (`10.10.10.11/24`, `10.10.20.11/24`, `ens32` UP)
- [`configs/netplan/compute01.yaml`](../configs/netplan/compute01.yaml) (`10.10.10.21/24`, `10.10.20.21/24`, `ens32` UP)
- [`configs/netplan/compute02.yaml`](../configs/netplan/compute02.yaml) (`10.10.10.22/24`, `10.10.20.22/24`, `ens32` UP)

Applied on each node with:
```bash
sudo rm -f /etc/netplan/50-cloud-init.yaml
sudo chmod 600 /etc/netplan/01-netcfg.yaml
sudo netplan apply
```

### 2.4 Passwordless SSH Mesh (`controller` ➔ All Nodes)
```bash
ssh-keygen -t ed25519 -N "" -f ~/.ssh/id_ed25519
ssh-copy-id sysadmin@controller
ssh-copy-id sysadmin@compute01
ssh-copy-id sysadmin@compute02
```

---

## 3. Live Verification Summary

| Node | Management (`ens33`) | Tunnel (`ens34`) | External (`ens32`) | Root LV (`/`) | Mgmt Ping RTT | Tunnel Ping RTT |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **`controller`** | `10.10.10.11/24` | `10.10.20.11/24` | `UP` (Unaddressed) | `23 GiB` (`17 GiB` avail) | Local | Local |
| **`compute01`** | `10.10.10.21/24` | `10.10.20.21/24` | `UP` (Unaddressed) | `23 GiB` (`17 GiB` avail) | `0.39 ms` (0% loss) | `0.52 ms` (0% loss) |
| **`compute02`** | `10.10.10.22/24` | `10.10.20.22/24` | `UP` (Unaddressed) | `23 GiB` (`17 GiB` avail) | `0.37 ms` (0% loss) | `0.55 ms` (0% loss) |

- **Raw Hardware Discovery Evidence:** [`evidence/00-env-discovery.txt`](../evidence/00-env-discovery.txt)
- **Week 1 Verification Log:** [`evidence/01-week1-linux-lvm-cgroups.txt`](../evidence/01-week1-linux-lvm-cgroups.txt)
