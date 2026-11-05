# Dual-Agent Synchronization Bus (User Hands-On -> Windows Verifier -> Mac Architect/Documenter)

## CRITICAL OPERATING RULE FOR BOTH AGENTS
1. **The User (Ragchaa) executes all hands-on setup and lab commands personally** to build deep muscle memory.
2. **Windows Agent Role (Q&A Assistant & Read-Only Verifier):**
   - **NEVER** auto-execute new setup or lab steps on behalf of the user unless explicitly instructed by the user.
   - Answer the user's quick questions while they work on the VMs.
   - Only when the user asks to *"verify/confirm my work"*, run read-only verification commands, save the verified terminal output into `evidence/`, update the Status Report below, and `git push origin main`.
   - **Encoding Note:** Always write markdown files using pure ASCII (`--`, `->`, `[VERIFIED]`) or UTF-8 without BOM.
3. **Mac Agent Role (Mentor & Documentation Architect):**
   - Teach the next step with clear commands and interview theory.
   - After Windows Agent pushes the verified `evidence/` file, pull from GitHub, review the verification log, and write/update the engineering runbooks in `docs/`, `configs/`, and executive summary in `README.md`.

---

## CURRENT STEP: Step 05 -> Week 4 Day-2 Cloud Operations, Multi-Node Workloads & Failure Drills
**Status:** `AWAITING_USER_HANDS_ON_EXECUTION` (Step 04 Documented in `docs/04-kolla-ansible-deployment.md`; User now executing Step 05 hands-on)

### Verification Checklist for Windows Agent (Run ONLY after User completes Step 05 Hands-On):
When the user finishes provisioning the networks, launching `cirros-vm-01` (on `compute01`) and `cirros-vm-02` (on `compute02`), attaching the Cinder volume, assigning a Floating IP, and running the outage drill, capture the following outputs into **`evidence/04-workloads-and-drills.txt`**:
1. **Glance Image, Flavors & Networks:**
   - `openstack image list`
   - `openstack flavor list`
   - `openstack network list` & `openstack subnet list`
   - `openstack router list` & `openstack router show demo-router`
2. **Multi-Node VM Placement (`compute01` vs `compute02`) & Floating IP:**
   - `openstack server list --long` (showing `cirros-vm-01` `ACTIVE` on `compute01` and `cirros-vm-02` `ACTIVE` on `compute02`, with private `192.168.100.x` and Floating IP `10.10.30.x`)
   - `openstack floating ip list`
3. **Live SDN Data-Plane Inspection (OVS VXLAN Tunnels & Linux Namespaces):**
   - `ip netns list` on `controller` (showing `qrouter-*` and `qdhcp-*` namespaces created by Neutron!)
   - `sudo docker exec openvswitch_vswitchd ovs-vsctl show` on `controller`, `compute01`, and `compute02` (showing active `vxlan-*` ports inside `br-tun` between `10.10.20.11`, `10.10.20.21`, and `10.10.20.22`, plus `qvo*` tap ports on `br-int`!)
4. **North-South Floating IP & East-West Cross-Node VXLAN Connectivity Proof:**
   - Ping & SSH into `cirros-vm-01`'s Floating IP (`10.10.30.x`) from `controller` (via `qrouter` or `br-ex` IP) or Windows host (`10.10.30.1`), and from inside `cirros-vm-01` ping `cirros-vm-02`'s private IP (`192.168.100.x`) across the VXLAN tunnel!
5. **Cinder LVM/iSCSI Volume Attach Proof:**
   - `openstack volume list` (showing `demo-vol-1` `in-use` attached to `cirros-vm-01` on `/dev/vdb`)
   - `sudo vgs` and `sudo lvs` on `controller` (showing the backing LV inside `cinder-volumes` VG!)
   - `lsblk` output from inside `cirros-vm-01` showing `vdb` (`1G` attached block disk).
6. **Outage / Failure Recovery Drill Proof:**
   - Summary/log of the OVS agent / container failure drill (`docker stop neutron_openvswitch_agent` -> observe `openstack network agent list` state / recovery -> `docker start neutron_openvswitch_agent`).

---

## STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 12:08:03 UTC+08 (Step 04 OpenStack 2025.2 Flamingo Deployed & Verified)
- **Step 05 Verification Status:** *(Pending user hands-on execution of Step 05)*
