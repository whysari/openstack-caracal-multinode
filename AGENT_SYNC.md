# 🔄 Dual-Agent Synchronization Bus (Mac Architect ➔ Windows Executor)

This file coordinates execution between:
- **Mac Agent (Antigravity):** Architecture, step-by-step runbook design, Linux/SDN/OpenStack verification analysis, and interview preparation.
- **Windows Agent (Host/VM Executor):** Direct execution on Windows 11 + VMware Workstation Pro (`controller`, `compute01`, `compute02`), capturing real terminal outputs into `evidence/`, and pushing state back to GitHub.

---

## 🎯 CURRENT TASK: Step 02 ➔ Static Networking, Root LVM Expansion & Week 1 Linux Internals (Cgroups v2 + Cinder LVM)
**Target:** Windows Agent  
**Status:** `IN_PROGRESS_WINDOWS_EXECUTION` (Part A Complete & Verified ✅; Part B In Progress)

### Instructions for Windows Agent:

Execute the following tasks across the 3 VMs (`controller`, `compute01`, `compute02`) and capture all verification outputs into **`evidence/01-week1-linux-lvm-cgroups.txt`**:

#### Part A: Node Identity, Root Filesystem Expansion & Static 3-Plane Networking (COMPLETED ✅)
1. **Root LV Expansion (Critical before Docker/Kolla):**
   - Expanded `ubuntu--vg-ubuntu--lv` to 100% of free VG space (23.00 GiB total, 17 GiB free) across **all 3 nodes** ✅
2. **Unique Hostnames & Machine IDs:**
   - Hostnames set and verified: `controller`, `compute01`, `compute02` ✅
3. **Clean `/etc/hosts` on All 3 Nodes:**
   - Configured with `10.10.10.11 controller`, `10.10.10.21 compute01`, `10.10.10.22 compute02` ✅
4. **Static Netplan Configuration:**
   - **`controller`:** `ens33` (10.10.10.11/24), `ens34` (10.10.20.11/24), `ens32` (UP, unaddressed) ✅
   - **`compute01`:** `ens33` (10.10.10.21/24), `ens34` (10.10.20.21/24), `ens32` (UP, unaddressed) ✅
   - **`compute02`:** `ens33` (10.10.10.22/24), `ens34` (10.10.20.22/24), `ens32` (UP, unaddressed) ✅
   - Ping verification: Management (`10.10.10.x`) and Tunnel (`10.10.20.x`) bidirectional pings verified with 0% packet loss (~0.3-0.5ms) ✅
5. **Internal SSH Mesh:**
   - Passwordless ed25519 SSH from `controller` to `compute01` and `compute02` tested and operational ✅

#### Part B: Week 1 Linux Internals Drills (LVM for Cinder & Cgroups v2 / OOM Killer) (IN PROGRESS ⏳)
1. **Cinder Block Storage LVM Provisioning on `controller` (`/dev/sdb` - 20G):**
   - Dedicated 20 GB disk verified at `/dev/sdb`. `pvcreate` and `vgcreate cinder-volumes` ready for execution.
2. **Cgroups v2 & Kernel OOM-Killer Drill on `compute01`:**
   - Ready for deterministic memory limit drill using `systemd-run`.

#### Part C: Record Evidence & Sync
1. Compile raw outputs into `evidence/01-week1-linux-lvm-cgroups.txt`.
2. Update `README.md` and `AGENT_SYNC.md`.
3. Commit and push back to `origin main`.

---

## 📡 STATUS REPORT FROM WINDOWS AGENT

- **Last Updated:** 2026-11-05 08:38:00 UTC+08
- **Part A Verification Results (100% Verified Live):**
  - **`controller` (`10.10.10.11`):**
    - `ens33`: `10.10.10.11/24` (Management & Internet, GW `10.10.10.2`)
    - `ens34`: `10.10.20.11/24` (Tunnel Overlay)
    - `ens32`: UP (External Provider `br-ex`, unaddressed)
    - Root Filesystem (`/`): **23 GiB Total | 17 GiB Available (23% used)**
  - **`compute01` (`10.10.10.21`):**
    - `ens33`: `10.10.10.21/24`
    - `ens34`: `10.10.20.21/24`
    - `ens32`: UP
    - Root Filesystem (`/`): **23 GiB Total | 17 GiB Available (23% used)**
  - **`compute02` (`10.10.10.22`):**
    - `ens33`: `10.10.10.22/24`
    - `ens34`: `10.10.20.22/24`
    - `ens32`: UP
    - Root Filesystem (`/`): **23 GiB Total | 17 GiB Available (23% used)**
  - **Connectivity Matrix:**
    - `controller` ➔ `compute01` Management (`10.10.10.21`): **PASS (0.39 ms)**
    - `controller` ➔ `compute01` Tunnel (`10.10.20.21`): **PASS (0.52 ms)**
    - `controller` ➔ `compute02` Management (`10.10.10.22`): **PASS (0.37 ms)**
    - `controller` ➔ `compute02` Tunnel (`10.10.20.22`): **PASS (0.55 ms)**
    - Passwordless SSH (`ssh compute01` / `ssh compute02`): **PASS (Authenticated)**
- **Next Actions:**
  - Proceeding with Part B (Cinder LVM on `/dev/sdb` and Cgroups v2 OOM-killer verification).
