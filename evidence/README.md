# Live Cluster Evidence Logs

All files in this directory are raw, unedited terminal outputs captured directly from the 3-node Ubuntu 24.04.5 LTS OpenStack cluster (`controller`, `compute01`, `compute02`).

| File | Stage | Description |
| :--- | :--- | :--- |
| [`00-env-discovery.txt`](00-env-discovery.txt) | Step 01 | Initial 3-VM discovery: OS/Kernel (`6.8.0-147-generic`), Nested KVM (`/dev/kvm`), ZRAM swap, 3 NICs (`ens33`, `ens34`, `ens32`), and 20GB `sdb` disk on `controller`. |
| [`01-week1-linux-lvm-cgroups.txt`](01-week1-linux-lvm-cgroups.txt) | Step 02 (Week 1) | Static Netplan networking (`10.10.10.0/24` & `10.10.20.0/24`), root LVM expansion (`23 GiB`), Cinder `cinder-volumes` VG (`20 GiB`), and Cgroups v2 / Kernel OOM-killer (`CONSTRAINT_MEMCG`) verification. |
| [`02-week2-sdn-vxlan-mtu.txt`](02-week2-sdn-vxlan-mtu.txt) | Step 03 (Week 2) | Isolated Linux network namespaces (`ns-vm1`, `ns-vm2`), `veth` pairs, cross-node VXLAN tunnel (`VNI 100`, `UDP 4789`), FDB MAC learning table, and `MTU 1450` (PASS) vs `MTU 1500` (FAIL) proof. |
| `03-kolla-control-plane.txt` | Step 04 (Week 3) | Kolla-Ansible multinode deployment verification: Dockerized control plane, Keystone, Glance, Placement, Nova hypervisors, Neutron OVS agents, and Cinder LVM volume services. |
