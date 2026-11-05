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
**Status:** `AWAITING_USER_HANDS_ON_EXECUTION` (Step 02 Documented ✅; User now executing Step 03 hands-on)

### Verification Checklist for Windows Agent (Run ONLY after User completes Week 2 SDN Hands-On):
When the user finishes building the manual SDN overlay across `compute01` (`10.10.20.21`) and `compute02` (`10.10.20.22`) and asks you to verify, capture the following outputs into **`evidence/02-week2-sdn-vxlan-mtu.txt`**:
1. **Namespace & veth Inspection (`compute01` & `compute02`):**
   - `sudo ip netns list` (`ns-vm1` on `compute01`, `ns-vm2` on `compute02`)
   - `sudo ip netns exec ns-vm1 ip -br a` (`192.168.100.11/24`, MTU `1450`) and `sudo ip netns exec ns-vm2 ip -br a` (`192.168.100.12/24`, MTU `1450`)
   - Bridge & VXLAN interface details on host (`ip -d link show vxlan100`, `bridge fdb show dev vxlan100`) showing VXLAN VNI `100`, UDP port `4789`, local/remote tunnel endpoints (`10.10.20.21` ↔ `10.10.20.22` on `ens34`).
2. **Cross-Node Overlay Connectivity & MTU 1450 vs 1500 Proof (`compute01` ➔ `compute02`):**
   - Ping from `ns-vm1` (`compute01`) to `ns-vm2` (`192.168.100.12` on `compute02`) showing 0% loss across the VXLAN tunnel.
   - **MTU Blackhole / Overhead Proof (`ping -M do`):**
     - `sudo ip netns exec ns-vm1 ping -c 2 -M do -s 1422 192.168.100.12` -> **PASS** (`1422` payload + `28` IP/ICMP = `1450` inner frame + `50` byte VXLAN/UDP/IP/Eth outer header = `1500` bytes on `ens34`).
     - `sudo ip netns exec ns-vm1 ping -c 2 -M do -s 1472 192.168.100.12` -> **FAIL (`Frag needed and DF set` / `message too long`)**, proving why VXLAN tenant networks require `MTU 1450`!
3. **iptables SNAT / Floating IP Emulation Check (`compute01`):**
   - Output of `sudo iptables -t nat -L -n -v` (or nftables equivalent) showing the SNAT/MASQUERADE rule tested during the lab.
4. **Clean Slate Teardown for Kolla-Ansible:**
   - After capturing the evidence above, confirm that temporary lab interfaces (`ns-vm1`, `ns-vm2`, `br-sdn`, `vxlan100`, temporary NAT rules) have been cleanly removed so the nodes are 100% clean for Step 04 (`kolla-ansible deploy`).

---

## 📡 STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 09:05:00 UTC+08 (Week 1 Verified & Documented ✅)
- **Week 2 SDN Verification Status:** *(Pending user hands-on execution of Week 2 SDN labs)*
