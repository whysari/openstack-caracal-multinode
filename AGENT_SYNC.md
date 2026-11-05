# 🔄 Dual-Agent Synchronization Bus (User Hands-On ➔ Windows Verifier ➔ Mac Architect/Documenter)

## ⚠️ CRITICAL OPERATING RULE FOR BOTH AGENTS
1. **The User (Ragchaa) executes all hands-on setup and lab commands personally** to build deep muscle memory.
2. **Windows Agent Role (Q&A Assistant & Read-Only Verifier):**
   - **NEVER** auto-execute new setup or lab steps on behalf of the user.
   - Answer the user's quick questions while they work on the VMs.
   - Only when the user asks you to *"verify/confirm my work"*, run read-only verification commands, save the verified terminal output into `evidence/`, update the Status Report below, and `git push origin main`.
3. **Mac Agent Role (Mentor & Documentation Architect):**
   - Teach the next step with clear commands and interview theory.
   - After Windows Agent pushes the verified `evidence/` file, pull from GitHub, review the verification log, and write/update the engineering runbooks in `docs/`, `configs/`, and executive summary in `README.md`.

---

## 🎯 CURRENT STEP: Step 02 (Part B) ➔ Week 1 Linux Internals (Cgroups v2 + Cinder LVM)
**Status:** `AWAITING_USER_HANDS_ON_EXECUTION` (Part A Verified ✅; User now executing Part B hands-on)

### Verification Checklist for Windows Agent (Run ONLY after User completes Part B):
1. **Cgroups v2 & Kernel OOM-Killer (`compute01`):**
   - Confirm `mount | grep cgroup2`, `cat /sys/fs/cgroup/cgroup.controllers`, and the kernel OOM-killer trace (`sudo dmesg -T | grep -E -i "oom-kill|out of memory|killed process" | tail -n 15`) showing `CONSTRAINT_MEMCG`.
2. **LVM Block Storage (`controller`):**
   - Confirm `sudo pvs` and `sudo vgs` showing Volume Group `cinder-volumes` (`20.00g` total, `20.00g` free) on `/dev/sdb`.
3. **Save Evidence:**
   - Write full verification output (Part A + Part B) into `evidence/01-week1-linux-lvm-cgroups.txt` and push to `origin main`.

---

## 📡 STATUS REPORT FROM WINDOWS AGENT

- **Last Updated:** 2026-11-05 08:38:00 UTC+08
- **Part A Verification Results (100% Verified Live):**
  - **`controller` (`10.10.10.11`):** `ens33` (`10.10.10.11/24`), `ens34` (`10.10.20.11/24`), `ens32` (`UP`, unaddressed), Root LV `/` (`23 GiB` total, `17 GiB` avail)
  - **`compute01` (`10.10.10.21`):** `ens33` (`10.10.10.21/24`), `ens34` (`10.10.20.21/24`), `ens32` (`UP`, unaddressed), Root LV `/` (`23 GiB` total, `17 GiB` avail)
  - **`compute02` (`10.10.10.22`):** `ens33` (`10.10.10.22/24`), `ens34` (`10.10.20.22/24`), `ens32` (`UP`, unaddressed), Root LV `/` (`23 GiB` total, `17 GiB` avail)
  - **Connectivity Matrix:** Management (`0.37–0.39 ms`) and Tunnel (`0.52–0.55 ms`) 0% loss; Passwordless SSH mesh verified ✅
- **Part B Verification Results:** *(Pending user hands-on execution of Алхам 4 & Алхам 5)*
