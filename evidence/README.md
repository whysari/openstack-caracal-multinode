# Live Cluster Evidence Logs

All files in this directory are raw, unedited terminal outputs captured directly from the 3-node Ubuntu 24.04.5 LTS OpenStack Caracal cluster (`controller`, `compute01`, `compute02`).

| File | Stage | Description |
| :--- | :--- | :--- |
| [`00-env-discovery.txt`](00-env-discovery.txt) | Step 01 | Initial 3-VM discovery: OS/Kernel (`6.8.0-147-generic`), Nested KVM (`/dev/kvm`), ZRAM swap, 3 NICs (`ens33`, `ens34`, `ens32`), and 20GB `sdb` disk on `controller`. |
| `01-week1-linux-lvm-cgroups.txt` | Step 02 | Static Netplan networking (`10.10.10.0/24` & `10.10.20.0/24`), root LVM expansion, Cinder `cinder-volumes` VG creation, and Cgroups v2 / Kernel OOM-killer verification. |
