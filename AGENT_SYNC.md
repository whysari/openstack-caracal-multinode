# 🔄 Dual-Agent Synchronization Bus (Mac Architect ➔ Windows Executor)

This file coordinates execution between:
- **Mac Agent (Antigravity):** Architecture, step-by-step runbook design, Linux/SDN/OpenStack verification analysis, and interview preparation.
- **Windows Agent (Host/VM Executor):** Direct execution on Windows 11 + VMware Workstation Pro (`controller`, `compute01`, `compute02`), capturing real terminal outputs into `evidence/`, and pushing state back to GitHub.

---

## 🎯 CURRENT TASK: Step 02 ➔ Static Networking, Root LVM Expansion & Week 1 Linux Internals (Cgroups v2 + Cinder LVM)
**Target:** Windows Agent  
**Status:** `PENDING_WINDOWS_EXECUTION`

### Instructions for Windows Agent:

Execute the following tasks across the 3 VMs (`controller`, `compute01`, `compute02`) and capture all verification outputs into **`evidence/01-week1-linux-lvm-cgroups.txt`**:

#### Part A: Node Identity, Root Filesystem Expansion & Static 3-Plane Networking
1. **Root LV Expansion (Critical before Docker/Kolla):**
   - Currently `ubuntu--vg-ubuntu--lv` is only `11.5G` out of `23G` on `sda3`. On **all 3 nodes**, expand it to 100% of the free VG space:
     ```bash
     sudo lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv
     ```
2. **Unique Hostnames & Machine IDs:**
   - Set hostnames: `controller`, `compute01`, `compute02` (`sudo hostnamectl set-hostname <name>`).
   - Ensure unique `/etc/machine-id` and SSH host keys on the clones.
3. **Clean `/etc/hosts` on All 3 Nodes:**
   ```text
   127.0.0.1 localhost
   10.10.10.11 controller
   10.10.10.21 compute01
   10.10.10.22 compute02
   ```
   *(Remove the old `network01` and `storage01` lines and update `127.0.1.1` to the node's actual hostname).*
4. **Static Netplan Configuration (`/etc/netplan/01-netcfg.yaml`, remove `50-cloud-init.yaml`):**
   - **`controller`:**
     - `ens33` (Mgmt/API): `10.10.10.11/24`, default route via `10.10.10.2`, DNS `8.8.8.8, 1.1.1.1`
     - `ens34` (Tunnel/Overlay): `10.10.20.11/24`
     - `ens32` (External Provider `br-ex`): `dhcp4: no`, `dhcp6: no`, brought `UP` with no IP (`sudo ip link set ens32 up` / Netplan `activation-mode: always` or unaddressed)
   - **`compute01`:**
     - `ens33`: `10.10.10.21/24`, default route via `10.10.10.2`, DNS `8.8.8.8, 1.1.1.1`
     - `ens34`: `10.10.20.21/24`
     - `ens32`: `dhcp4: no`, `dhcp6: no`, UP with no IP
   - **`compute02`:**
     - `ens33`: `10.10.10.22/24`, default route via `10.10.10.2`, DNS `8.8.8.8, 1.1.1.1`
     - `ens34`: `10.10.20.22/24`
     - `ens32`: `dhcp4: no`, `dhcp6: no`, UP with no IP
5. **Internal SSH Mesh:**
   - Generate an ed25519 keypair for `sysadmin` (and `root`) on `controller` and authorize it across `controller`, `compute01`, and `compute02` so `controller` can SSH without password to all 3 nodes by hostname and IP.
   - Verify connectivity across both `10.10.10.x` (Management) and `10.10.20.x` (Tunnel) networks.

#### Part B: Week 1 Linux Internals Drills (LVM for Cinder & Cgroups v2 / OOM Killer)
1. **Cinder Block Storage LVM Provisioning on `controller` (`/dev/sdb` - 20G):**
   - Run `sudo pvcreate /dev/sdb` and `sudo vgcreate cinder-volumes /dev/sdb`.
   - **Hands-on LV Lifecycle Check:** Create a 1G test logical volume (`sudo lvcreate -L 1G -n lv_smoke_test cinder-volumes`), format with `mkfs.ext4`, inspect with `sudo pvs`, `sudo vgs`, `sudo lvs`, and then remove the test LV (`sudo lvremove -y /dev/cinder-volumes/lv_smoke_test`) so the full 20G `cinder-volumes` VG remains clean and ready for Kolla-Ansible Cinder!
2. **Cgroups v2 & Kernel OOM-Killer Drill on `compute01`:**
   - Verify Cgroups v2 unified hierarchy (`mount | grep cgroup2` and `cat /sys/fs/cgroup/cgroup.controllers`).
   - Trigger a deterministic Cgroup v2 OOM-kill using `systemd-run`:
     ```bash
     sudo systemd-run --scope -p MemoryMax=32M -p MemorySwapMax=0M -p CPUQuota=50% \
       python3 -c "a = bytearray(64 * 1024 * 1024)" || true
     ```
   - Capture the resulting Linux kernel OOM-killer trace (`sudo journalctl -k --no-pager | grep -E -i "oom|killed process|memory" | tail -n 20`).

#### Part C: Record Evidence & Sync
1. Save all structured terminal outputs (Part A + Part B) into **`evidence/01-week1-linux-lvm-cgroups.txt`**.
2. Check off **Step 02** in `README.md` if completed cleanly.
3. Update the **Status Report from Windows Agent** section below, commit, and push to `origin main`.

---

## 📡 STATUS REPORT FROM WINDOWS AGENT

- **Last Updated:** 2026-11-05 07:54:00 UTC+08 (Step 01 Completed; Step 02 Pending)
- **Step 02 Execution Summary:** *(Windows Agent: update here after completing Step 02)*
