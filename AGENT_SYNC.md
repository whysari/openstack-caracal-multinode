# Dual-Agent Synchronization Bus (User Hands-On -> Windows Verifier -> Mac Architect/Documenter)

## CURRENT STEP: Step 04 -> Deploy the LATEST OpenStack on Ubuntu 24.04 LTS (`2026.1` Gazpacho / `2025.2` Flamingo)
**Target:** Windows Agent (Explicitly authorized by User to upgrade Kolla-Ansible to the latest Ubuntu 24.04 release and execute deployment)  
**Status:** `APPROVED_FOR_WINDOWS_AGENT_EXECUTION`

---

### Architectural Directive from User & Mac Architect
- **Use the LATEST OpenStack release for Ubuntu 24.04 LTS (`noble`)!** We are in 2026 — do NOT deploy outdated 2024.x releases.
- As discovered on Quay.io (`https://quay.io/api/v1/repository/openstack.kolla/kolla-toolbox/tag/`), upstream Kolla hosts `2026.1-ubuntu-noble` (OpenStack 2026.1 Gazpacho) and `2025.2-ubuntu-noble` (OpenStack 2025.2 Flamingo).

---

### Exact Execution Steps for Windows Agent on `controller`:

1. **Check the latest stable branch on OpenDev (`stable/2026.1` vs `stable/2025.2`) and verify Quay.io image completeness:**
   ```bash
   git ls-remote --heads https://opendev.org/openstack/kolla-ansible | grep -E "stable/2025|stable/2026"
   ```
   - If `stable/2026.1` is present and all core images (`keystone`, `glance-api`, `nova-compute`, `neutron-server`, `openvswitch-vswitchd`, `cinder-volume`, `horizon`, `mariadb-server`, `rabbitmq`: `2026.1-ubuntu-noble`) exist on Quay.io, use **`stable/2026.1`** (`openstack_release: "2026.1"`, `ansible-core>=2.18`).
   - If `2026.1` is still a master/RC branch missing any service container on Quay.io, use the latest complete stable release **`stable/2025.2`** (`openstack_release: "2025.2"`, `ansible-core>=2.18,<2.20`).

2. **Upgrade `ansible-core` and `kolla-ansible` in `~/kolla-venv` to the Latest Stable Release:**
   ```bash
   source ~/kolla-venv/bin/activate
   # For 2026.1 (or 2025.2): install the matching ansible-core constraint from requirements.txt
   pip install -U pip
   pip install -U git+https://opendev.org/openstack/kolla-ansible@stable/2026.1 || pip install -U git+https://opendev.org/openstack/kolla-ansible@stable/2025.2
   # Ensure ansible-core matches the installed kolla-ansible release's min/max version bounds
   kolla-ansible install-deps
   ```

3. **Refresh `/etc/kolla/passwords.yml` and `/etc/kolla/multinode` from the Newly Installed Templates:**
   ```bash
   cp ~/kolla-venv/share/kolla-ansible/etc_examples/kolla/passwords.yml /etc/kolla/passwords.yml
   kolla-genpwd
   sed -i 's/^keystone_admin_password:.*/keystone_admin_password: OpenStack2026!/' /etc/kolla/passwords.yml

   cp ~/kolla-venv/share/kolla-ansible/ansible/inventory/multinode /etc/kolla/multinode
   ```
   Update the top host groups in `/etc/kolla/multinode` (`[control]` -> `controller`, `[network]` -> `controller`, `[compute]` -> `compute01`, `compute02`, `[monitoring]` -> empty, `[storage]` -> `controller`).

4. **Update `/etc/kolla/globals.yml`:**
   Ensure `/etc/kolla/globals.yml` has `openstack_release` set to the verified latest release (`"2026.1"` or `"2025.2"`), `enable_fluentd: "no"`, `openstack_service_workers: "1"`, `openstack_service_rpc_workers: "1"`, and sync `/etc/kolla/globals.yml` back to `configs/kolla/globals.yml` in the repo.

5. **Run `prechecks`, `deploy`, and `post-deploy`:**
   ```bash
   kolla-ansible -i /etc/kolla/multinode prechecks
   kolla-ansible -i /etc/kolla/multinode deploy
   kolla-ansible -i /etc/kolla/multinode post-deploy
   ```

6. **Install OpenStack CLI & Capture Verification Evidence into `evidence/03-kolla-control-plane.txt`:**
   ```bash
   pip install -U python-openstackclient
   source /etc/kolla/admin-openrc.sh
   ```
   Capture into `evidence/03-kolla-control-plane.txt`:
   - `ip -br a show dev ens33` on `controller` (showing VIP `10.10.10.250/32`)
   - `sudo docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"` across `controller`, `compute01`, `compute02`
   - `openstack service list`
   - `openstack endpoint list`
   - `openstack compute service list`
   - `openstack hypervisor list`
   - `openstack network agent list`
   - `openstack volume service list`
   - `sudo docker exec openvswitch_vswitchd ovs-vsctl show` on `controller` and `compute01`

7. **Commit & Push back to `origin main`.**

---

## STATUS REPORT FROM WINDOWS AGENT
- **Last Updated:** 2026-11-05 10:46:00 UTC+08
- **Current Position:** Approved to upgrade `kolla-venv` to latest OpenStack (`2026.1` / `2025.2`) for Ubuntu 24.04 LTS (`noble`) and execute `deploy` + `post-deploy`.
