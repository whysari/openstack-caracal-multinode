# Dual-Agent Synchronization Bus (User Hands-On -> Windows Verifier -> Mac Architect/Documenter)

## CRITICAL OPERATING RULE FOR BOTH AGENTS
1. **The User (Ragchaa) executes all hands-on setup and lab commands personally** to build deep muscle memory.
2. **Windows Agent Role (Q&A Assistant & Read-Only Verifier):**
   - **NEVER** auto-execute new setup or lab steps on behalf of the user.
   - Answer the user's quick questions while they work on the VMs.
   - Only when the user asks to *"verify/confirm my work"*, run read-only verification commands, save the verified terminal output into `evidence/`, update the Status Report below, and `git push origin main`.
   - **Encoding Note:** Always write markdown files using pure ASCII (`--`, `->`, `[VERIFIED]`) or UTF-8 without BOM so characters never get mangled by Windows PowerShell.
3. **Mac Agent Role (Mentor & Documentation Architect):**
   - Teach the next step with clear commands and interview theory.
   - After Windows Agent pushes the verified `evidence/` file, pull from GitHub, review the verification log, and write/update the engineering runbooks in `docs/`, `configs/`, and executive summary in `README.md`.

---

## CURRENT STEP: Step 04 -> Week 3 OpenStack Multi-Node Deployment via Kolla-Ansible
**Status:** `AWAITING_USER_HANDS_ON_EXECUTION` (Step 03 Documented in `docs/03-sdn-namespaces-vxlan.md`; User now executing Step 04 hands-on)

### Verification Checklist for Windows Agent (Run ONLY after User completes Step 04 `kolla-ansible post-deploy`):
When the user finishes deploying OpenStack with Kolla-Ansible and asks you to verify, capture the following outputs into **`evidence/03-kolla-control-plane.txt`**:
1. **Container & VIP Status across all 3 nodes:**
   - `ip -br a show dev ens33` on `controller` (confirming Keepalived VIP `10.10.10.250/32` is bound on `ens33`)
   - `sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"` on `controller`, `compute01`, and `compute02`
2. **OpenStack Control Plane & Agent CLI Verification (on `controller` using `/etc/kolla/admin-openrc.sh`):**
   - `openstack endpoint list`
   - `openstack service list`
   - `openstack compute service list` (showing `nova-scheduler`, `nova-conductor` on `controller` and `nova-compute` `up`/`enabled` on both `compute01` and `compute02`)
   - `openstack hypervisor list`
   - `openstack network agent list` (showing Open vSwitch agent alive on `controller`, `compute01`, `compute02`, plus L3, DHCP, and Metadata agents alive on `controller`)
   - `openstack volume service list` (showing `cinder-scheduler` and `cinder-volume` `controller@lvm` `up`/`enabled`)
3. **Open vSwitch Bridge Inspection inside Docker Container:**
   - `sudo docker exec openvswitch_vswitchd ovs-vsctl show` on `controller` and `compute01` (showing `br-int`, `br-tun` with VXLAN ports, and `br-ex` with `ens32`).

---

## STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 09:38:00 UTC+08 (Week 2 SDN Verified & Documented)
- **Week 3 Kolla-Ansible Verification Status:** *(Pending user hands-on execution of Step 04)*
