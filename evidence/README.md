# Live Cluster Evidence Logs

All files in this directory are raw, unedited terminal outputs captured directly from the 3-node Ubuntu 24.04.5 LTS OpenStack 2025.2 (Flamingo) cluster (`controller`, `compute01`, `compute02`).

| File | Stage | Description |
| :--- | :--- | :--- |
| [`00-env-discovery.txt`](00-env-discovery.txt) | Step 01 | Initial 3-VM discovery: OS/Kernel (`6.8.0-147-generic`), Nested KVM (`/dev/kvm`), ZRAM swap, 3 NICs (`ens33`, `ens34`, `ens32`), and 20GB `sdb` disk on `controller`. |
| [`01-week1-linux-lvm-cgroups.txt`](01-week1-linux-lvm-cgroups.txt) | Step 02 (Week 1) | Static Netplan networking (`10.10.10.0/24` & `10.10.20.0/24`), root LVM expansion (`23 GiB`), Cinder `cinder-volumes` VG (`20 GiB`), and Cgroups v2 / Kernel OOM-killer (`CONSTRAINT_MEMCG`) verification. |
| [`02-week2-sdn-vxlan-mtu.txt`](02-week2-sdn-vxlan-mtu.txt) | Step 03 (Week 2) | Isolated Linux network namespaces (`ns-vm1`, `ns-vm2`), `veth` pairs, cross-node VXLAN tunnel (`VNI 100`, `UDP 4789`), FDB MAC learning table, and `MTU 1450` (PASS) vs `MTU 1500` (FAIL) proof. |
| [`03-kolla-control-plane.txt`](03-kolla-control-plane.txt) | Step 04 (Week 3) | Kolla-Ansible (`21.3.0`) OpenStack 2025.2 (Flamingo) multinode deployment verification: 37 control-plane containers on `controller`, 9 containers each on `compute01` & `compute02`, VIP `10.10.10.250`, Nova KVM hypervisors, 6 Neutron OVS/L3/DHCP/Metadata agents, Cinder LVM (`controller@lvm-1`), and Horizon HTTP 200 OK. |
| [`04-workloads-and-drills.txt`](04-workloads-and-drills.txt) | Step 05 (Week 4) | Multi-node VM placement (`cirros-vm-01` on `compute01`, `cirros-vm-02` on `compute02`), North-South Floating IP (`10.10.30.132`) ping/SSH, East-West cross-node VXLAN ping (`192.168.100.237 -> 192.168.100.218`, `MTU 1450`), Cinder 1 GiB volume attach (`/dev/vdb`), and OVS agent outage/recovery drill. |
