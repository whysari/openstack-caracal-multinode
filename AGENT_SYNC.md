# 🔄 Dual-Agent Synchronization Bus (Mac Architect ↔ Windows Executor)

This file coordinates execution between:
- **Mac Agent (Antigravity):** Architecture, step-by-step runbook design, Linux/SDN/OpenStack verification analysis, and interview preparation.
- **Windows Agent (Host/VM Executor):** Direct execution on Windows 11 + VMware Workstation Pro (`controller`, `compute01`, `compute02`), capturing real terminal outputs into `evidence/`, and pushing state back to GitHub.

---

## 🎯 CURRENT TASK: Step 01 — Live Environment Discovery & Base Verification
**Target:** Windows Agent  
**Status:** `PENDING_WINDOWS_EXECUTION`

### Instructions for Windows Agent:
1. Ensure the 3 cloned VMs (`controller`, `compute01`, `compute02`) are powered on and reachable.
2. Collect the exact current state of the 3 VMs (whether already partially configured or fresh clones) and write the raw terminal outputs into `evidence/00-env-discovery.txt`:
   - OS version (`lsb_release -a` or `/etc/os-release`) and kernel (`uname -r`)
   - CPU & virtualization flags (`lscpu | grep -E "Model name|CPU\(s\)|Virtualization"`, `ls -l /dev/kvm`)
   - RAM & Swap (`free -h`)
   - Network interfaces and IPs (`ip -br link`, `ip -br a`, `ip route`) on all 3 nodes
   - Block devices (`lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT`) on all 3 nodes (specifically checking if `controller` or storage node has an extra disk/partition for `cinder-volumes` LVM)
   - Current progress check: Have you already installed any packages (Docker, Ansible, `kolla-ansible`, LVM, OVS) or configured `/etc/hosts` and SSH keys between `controller`, `compute01`, and `compute02`?
3. Update the **Status Report from Windows Agent** section below with:
   - The IP scheme currently in use (e.g. `192.168.x.x/24` or `10.10.10.x/24`)
   - NIC names on the VMs (e.g. `ens33`, `ens34`)
   - Current stage reached on Windows so far
4. Commit and push back to `main`:
   ```bash
   git add AGENT_SYNC.md evidence/00-env-discovery.txt
   git commit -m "chore(sync): report initial 3-VM state from Windows host"
   git push origin main
   ```

---

## 📤 STATUS REPORT FROM WINDOWS AGENT
*(Windows Agent: Replace this block with your execution summary and findings after running Step 01)*

- **Last Updated:** *(pending)*
- **VMware Subnets / Node IPs:**
  - `controller`: *(pending)*
  - `compute01`: *(pending)*
  - `compute02`: *(pending)*
  - `kolla_internal_vip_address`: *(pending)*
- **NIC Names:**
  - `network_interface`: *(pending)*
  - `neutron_external_interface`: *(pending)*
- **Extra Disk for Cinder (`cinder-volumes`):** *(pending)*
- **Completed Steps So Far:** *(pending)*
- **Blockers / Notes for Mac Agent:** *(pending)*
