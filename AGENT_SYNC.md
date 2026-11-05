# 🔄 Dual-Agent Synchronization Bus (User Hands-On ➔ Windows Verifier ➔ Mac Architect/Documenter)

## ⚠️ CRITICAL OPERATING RULE FOR BOTH AGENTS
1. **The User (Ragchaa) executes all hands-on setup and lab commands personally** to build deep muscle memory.
2. **Windows Agent Role (Q&A Assistant & Read-Only Verifier):**
   - **NEVER** auto-execute new setup or lab steps on behalf of the user.
   - Answer the user's quick questions while they work on the VMs.
   - Only when the user asks to *"verify/confirm my work"*, run read-only verification commands, save the verified terminal output into `evidence/`, update the Status Report below, and `git push origin main`.
3. **Mac Agent Role (Mentor & Documentation Architect):**
   - Teach the next step with clear commands and interview theory.
   - After Windows Agent pushes the verified `evidence/` file, pull from GitHub, review the verification log, and write/update the engineering runbooks in `docs/`, `configs/`, and executive summary in `README.md`.

---

## 🎯 CURRENT STEP: Step 02 ➔ Week 1 Linux Internals (Cgroups v2 + Cinder LVM)
**Status:** `COMPLETED_WINDOWS_EXECUTION` (Verified Live ✅ — Awaiting Mac Architect Step 03 Runbook)

### Verification Summary:
1. **Part A (Networking, LVM Expansion, SSH Mesh):** Verified 100% across all 3 nodes ✅
2. **Part B1 (Controller Cinder LVM on `/dev/sdb`):** Verified `cinder-volumes` VG active with 20.00 GB raw capacity on `/dev/sdb` ✅
3. **Part B2 (Compute01 Cgroups v2 & OOM Killer):** Verified Cgroups v2 unified hierarchy and captured `CONSTRAINT_MEMCG` kernel OOM kill of python3 process in dmesg ✅
4. **Evidence File:** Fully compiled at [`evidence/01-week1-linux-lvm-cgroups.txt`](evidence/01-week1-linux-lvm-cgroups.txt) ✅

---

## 📡 STATUS REPORT FROM WINDOWS AGENT

- **Last Updated:** 2026-11-05 09:05:00 UTC+08
- **Part A Live Verification:**
  - `controller` (`10.10.10.11`): `ens33` (`10.10.10.11/24`), `ens34` (`10.10.20.11/24`), `ens32` (UP, unaddressed), Root LV `/` (23 GiB total, 17 GiB avail)
  - `compute01` (`10.10.10.21`): `ens33` (`10.10.10.21/24`), `ens34` (`10.10.20.21/24`), `ens32` (UP, unaddressed), Root LV `/` (23 GiB total, 17 GiB avail)
  - `compute02` (`10.10.10.22`): `ens33` (`10.10.10.22/24`), `ens34` (`10.10.20.22/24`), `ens32` (UP, unaddressed), Root LV `/` (`23 GiB` total, `17 GiB` avail)
  - Inter-node latency: Management (`0.26-0.37 ms`), Tunnel (`0.22-0.27 ms`) with 0% loss
  - Passwordless SSH mesh from `controller` to all nodes: Operational
- **Part B Live Verification:**
  - **Cinder LVM (`controller`):** Volume Group `cinder-volumes` (`<20.00g` size, `<20.00g` free) verified active on `/dev/sdb`
  - **Cgroups v2 (`compute01`):** Unified hierarchy confirmed on `/sys/fs/cgroup`. Controllers: `cpuset cpu io memory hugetlb pids rdma misc`. Deterministic OOM-killer invocation verified in kernel logs:
    ```text
    [ 5603.364024] python3 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
    [ 5603.364248] oom-kill:constraint=CONSTRAINT_MEMCG,...,task=python3,pid=2550
    [ 5603.364258] Memory cgroup out of memory: Killed process 2550 (python3) total-vm:83524kB, anon-rss:32512kB
    ```
- **Next Task:** Ready for Mac Architect to document Week 1 analysis and specify **Step 03 — Week 2 Software-Defined Networking (SDN) Drill**.
