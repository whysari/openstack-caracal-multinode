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

## CURRENT STEP: Step 05 COMPLETED & VERIFIED -> Handoff to Mac Architect
**Status:** `STEP_05_COMPLETED_VERIFIED` (Workloads, SDN Overlay, Block Storage, and Outage Drill fully verified live)

### Verification Summary for Step 05 (Day 2 Operations & Workloads):
All 6 checklist requirements for Step 05 were verified live on the cluster and recorded in **`evidence/04-workloads-and-drills.txt`** (24 KB):
1. **Glance & Flavors:** `cirros-0.6.2` image uploaded and active; `m1.tiny` flavor created (1 VCPU, 256 MB RAM, 1 GB disk).
2. **Neutron SDN Infrastructure:**
   - Provider external network `public-net` (`10.10.30.0/24`, flat, physical network `physnet1` on `ens32`).
   - Tenant overlay network `private-net` (`192.168.100.0/24`, VXLAN on `ens34`).
   - Virtual router `demo-router` with SNAT enabled, gateway on `10.10.30.142`, internal interface on `192.168.100.1`.
3. **Multi-Node VM Placement:**
   - `cirros-vm-01` scheduled to **`compute01`** (`ACTIVE`, private IP `192.168.100.237`, Floating IP `10.10.30.132`).
   - `cirros-vm-02` scheduled to **`compute02`** (`ACTIVE`, private IP `192.168.100.218`).
4. **SDN Data Plane & Cross-Node VXLAN:**
   - Active dynamic VXLAN mesh ports on `br-tun` between `10.10.20.11`, `10.10.20.21`, and `10.10.20.22`.
   - North-South routing: Floating IP ping to `10.10.30.132` verified with 0% packet loss.
   - East-West routing: SSH into `cirros-vm-01` on `compute01` and pinged `cirros-vm-02` (`192.168.100.218`) on `compute02` across the physical `ens34` VXLAN tunnel with 0% packet loss (avg RTT 2.78 ms, MTU 1450 verified).
5. **Cinder LVM Block Storage Attachment:**
   - `demo-vol-01` (1 GiB) created, attached to `cirros-vm-01` as `/dev/vdb`.
   - Verified on host via LVM: backed by `volume-acf33885-2cb2-4538-a420-2e542cc7f748` in `cinder-volumes` thin pool on `controller:/dev/sdb`.
   - Verified inside guest OS: `lsblk` and `/proc/partitions` show `vdb` (1048576 blocks / 1 GiB).
6. **Outage / Resilience Drill:**
   - Stopped `neutron_openvswitch_agent` container on `compute01`.
   - Ping from controller to `cirros-vm-01` (`10.10.30.132`) continued without losing a single packet (proving OVS kernel data-plane persistence independent of control daemons).
   - Started `neutron_openvswitch_agent` on `compute01`: agent automatically re-established RPC with RabbitMQ, resumed heartbeats, and returned to `Alive: :-)`, `State: UP`.

---

## STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 12:44:00 UTC+08
- **Step 05 Verification Status:** `STEP_05_COMPLETED_VERIFIED`
- **Deliverables:**
  - `evidence/04-workloads-and-drills.txt` (Complete live verification capture)
- **Handoff to Mac Architect:**
  - Pull `evidence/04-workloads-and-drills.txt`.
  - Author `docs/05-day2-workloads-and-drills.md` and update `README.md`.