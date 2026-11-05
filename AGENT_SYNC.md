# 🔄 Dual-Agent Synchronization Bus (User Hands-On ➔ Windows Verifier ➔ Mac Architect/Documenter)

## ⚠️ CRITICAL OPERATING RULE FOR BOTH AGENTS
1. **The User (Ragchaa) executes all hands-on setup and lab commands personally** to build deep muscle memory.
2. **Windows Agent Role (Q&A Assistant & Read-Only Verifier):**
   - **NEVER** auto-execute new setup or lab steps on behalf of the user.
   - Answer the user's quick questions while they work on the VMs.
   - Only when the user asks to *"verify/confirm my work"*, run read-only verification commands (and clean up temporary lab namespaces if requested), save the verified terminal output into `evidence/`, update the Status Report below, and `git push origin main`.
   - **Encoding Note:** Always write markdown files using UTF-8 without BOM so Unicode characters render cleanly on GitHub.
3. **Mac Agent Role (Mentor & Documentation Architect):**
   - Teach the next step with clear commands and interview theory.
   - After Windows Agent pushes the verified `evidence/` file, pull from GitHub, review the verification log, and write/update the engineering runbooks in `docs/`, `configs/`, and executive summary in `README.md`.

---

## 🎯 CURRENT STEP: Step 03 ➔ Week 2 Software-Defined Networking (SDN): Namespaces, veth, Cross-Node VXLAN & MTU 1450 vs 1500
**Status:** `COMPLETED_WINDOWS_EXECUTION` (Verified Live ✅ & Clean Teardown Verified — Awaiting Mac Architect Step 04 Runbook)

### Verification Summary:
1. **Namespaces & veth Pair:** `ns-vm1` (`192.168.100.11/24`) on `compute01` and `ns-vm2` (`192.168.100.12/24`) on `compute02` verified with peer links plugged into `br-sdn` ✅
2. **Cross-Node VXLAN Tunnel:** `vxlan100` (VNI `100`, UDP `4789`, MTU `1450`) verified between `compute01` (`10.10.20.21`) and `compute02` (`10.10.20.22`) on `ens34` ✅
3. **Overlay Connectivity:** Basic ping between `ns-vm1` and `ns-vm2` across the physical tunnel verified at `~0.35 ms` RTT (0% packet loss) ✅
4. **MTU Blackhole & VXLAN Overhead Proof (`ping -M do`):**
   - `1450` Bytes (`-s 1422`): **PASS (0% loss, ~0.42 ms)** ✅
   - `1500` Bytes (`-s 1472`): **FAIL (100% loss / dropped)**, proving the 50-byte VXLAN encapsulation tax ✅
5. **Clean Slate Teardown:** All temporary SDN namespaces (`ns-vm1`, `ns-vm2`), bridges (`br-sdn`), and tunnel interfaces (`vxlan100`) cleanly removed from `compute01` and `compute02`. Interfaces verified in pristine state for Kolla-Ansible ✅
6. **Evidence File:** Compiled at [`evidence/02-week2-sdn-vxlan-mtu.txt`](evidence/02-week2-sdn-vxlan-mtu.txt) ✅

---

## 📡 STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 09:38:00 UTC+08
- **Week 2 SDN Verification Status:** Fully completed and verified live.
- **Node Cleanliness Check:**
  - `compute01`: Pristine (`lo`, `ens32`, `ens33`, `ens34` only)
  - `compute02`: Pristine (`lo`, `ens32`, `ens33`, `ens34` only)
  - `controller`: Pristine (`cinder-volumes` LVM ready on `/dev/sdb`)
- **Ready for Next Task:** Mac Architect to document Week 2 SDN runbook in `docs/03-sdn-namespaces-vxlan.md` and provide **Step 04 — Week 3 Kolla-Ansible Multinode Deployment**.
