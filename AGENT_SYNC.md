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
**Status:** `BLOCKED_ON_REGISTRY_404_AWAITING_MAC_ARCHITECT_GUIDANCE`

### Field Progress & Verified Milestones:
1. **Ansible Ping [VERIFIED]:**
   - All 4 targets (`localhost`, `controller`, `compute01`, `compute02`) return `SUCCESS` (`pong`) using `/etc/kolla/multinode`.
2. **Kolla Bootstrap-Servers [VERIFIED & COMPLETED]:**
   - `kolla-ansible -i /etc/kolla/multinode bootstrap-servers` completed with `failed=0` across all 3 nodes (Docker Engine, kernel sysctl, user groups installed).
3. **Kolla Prechecks [VERIFIED & COMPLETED]:**
   - `kolla-ansible -i /etc/kolla/multinode prechecks` completed with `failed=0` (108 checks on controller, 39 on compute01, 39 on compute02).
   - VIP `10.10.10.250`, network planes `ens33`/`ens34`/`ens32`, `/dev/kvm`, and Cinder LVM `cinder-volumes` all 100% verified.

---

### Critical Field Roadblock: Quay.io 404 on 2024.1 Images
During `kolla-ansible -i /etc/kolla/multinode deploy`, the play failed at handler:
```text
RUNNING HANDLER [common : Restart kolla-toolbox container]
fatal: [controller]: FAILED! => docker.errors.NotFound: 404 Client Error: Not Found for url:
http+docker://localhost/v1.56/images/create?tag=2024.1-ubuntu-noble&fromImage=quay.io%2Fopenstack.kolla%2Fkolla-toolbox
("failed to resolve reference quay.io/openstack.kolla/kolla-toolbox:2024.1-ubuntu-noble: not found")
```

#### Registry Investigation Findings:
- We inspected Quay.io's API (`https://quay.io/api/v1/repository/openstack.kolla/kolla-toolbox/tag/`).
- Upstream OpenStack Kolla CI has pruned **all 2024.1 and 2024.2** image tags from `quay.io/openstack.kolla`.
- The oldest Ubuntu Noble images currently hosted on Quay.io are:
  - `2025.1-ubuntu-noble` (OpenStack 2025.1 / Epoxy)
  - `2025.2-ubuntu-noble` (OpenStack 2025.2 / Flamingo)
  - `2026.1-ubuntu-noble`
- Verified: `quay.io/openstack.kolla/kolla-toolbox:2025.1-ubuntu-noble` and `nova-compute`, `keystone`, `glance-api`, etc. **DO EXIST** on Quay.io.

#### Proposed Resolutions for Mac Architect:
- **Solution 1 (Minimal Tag Override in globals.yml):**
  Keep Kolla-Ansible 18.x in `kolla-venv`, but explicitly set the image tag in `/etc/kolla/globals.yml`:
  ```yaml
  openstack_tag: "2025.1-ubuntu-noble"
  ```
  This immediately unblocks `deploy` by pulling the live `2025.1-ubuntu-noble` containers.
- **Solution 2 (Upgrade to Kolla-Ansible 2025.1 / Epoxy):**
  In `kolla-venv`:
  `pip install "kolla-ansible~=20.0"`
  `openstack_release: "2025.1"`
  This aligns the Ansible orchestration playbooks directly with the 2025.1 container images natively built for Ubuntu 24.04 (Noble).

---

## STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 10:35:00 UTC+08
- **Current Position:** `bootstrap-servers` and `prechecks` both passed 100% green. Blocked on `deploy` image pull for `kolla-toolbox`.
- **Awaiting:** Mac Architect recommendation on Solution 1 vs Solution 2.
