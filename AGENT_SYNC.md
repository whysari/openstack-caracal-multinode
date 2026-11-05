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
**Status:** `IN_PROGRESS_HANDS_ON_EXECUTION` (Resolving dependency installation before bootstrap-servers and deploy)

### Field Progress & Troubleshooting Notes:
1. **Ansible Ping [VERIFIED]:**
   - All 4 targets (`localhost`, `controller`, `compute01`, `compute02`) return `SUCCESS` (`pong`) using `/etc/kolla/multinode`.
2. **Ansible Version Gate [RESOLVED]:**
   - Kolla-Ansible 2024.1 strictly requires `ansible-core >= 2.15, < 2.17`.
   - Python 3.12 default pip pulled `2.17.14`. Resolved via `pip install "ansible-core>=2.16,<2.17"`.
3. **OpenDev Git Branch Rename [WORKAROUND IDENTIFIED]:**
   - Upstream OpenStack moved series 2024.1 (Caracal) from `stable/2024.1` to `unmaintained/2024.1`.
   - `kolla-ansible install-deps` failed with `pathspec 'stable/2024.1' did not match any file(s) known to git`.
   - Fix: Update `~/kolla-venv/share/kolla-ansible/requirements.yml` to point to `unmaintained/2024.1`, then run `kolla-ansible install-deps` to install role `openstack.kolla.baremetal`.
4. **Mac Architect Globals [PULLED]:**
   - Pulled `configs/kolla/globals.yml` (commit `57696cf`) with worker limit `openstack_service_workers: "1"` for host RAM conservation.

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
- **Last Updated:** 2026-11-05 10:20:00 UTC+08
- **Current Position:** Resolving `openstack.kolla.baremetal` dependency before `bootstrap-servers`.
- **Next User Milestones:**
  1. Run `kolla-ansible install-deps` (after fixing `requirements.yml`)
  2. Copy `configs/kolla/globals.yml` to `/etc/kolla/globals.yml` & run `kolla-genpwd`
  3. Run `kolla-ansible -i /etc/kolla/multinode bootstrap-servers`
  4. Run `kolla-ansible -i /etc/kolla/multinode prechecks`
  5. Run `kolla-ansible -i /etc/kolla/multinode deploy`
  6. Run `kolla-ansible -i /etc/kolla/multinode post-deploy`
  7. Step 4.6: Install `python-openstackclient` and verify live cloud
