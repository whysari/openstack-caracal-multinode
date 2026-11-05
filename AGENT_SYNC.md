# Dual-Agent Synchronization Bus (User Hands-On -> Windows Verifier -> Mac Architect/Documenter)

## CURRENT STEP: Capture Live Horizon GUI Screenshots (`http://10.10.10.250`) for `README.md`
**Target:** Windows Agent  
**Status:** `PENDING_WINDOWS_SCREENSHOT_CAPTURE`

### Instructions for Windows Agent:
The user wants real, high-resolution screenshots of our live **OpenStack 2025.2 (Flamingo) Horizon Dashboard (`http://10.10.10.250`, user: `admin`, pass: `OpenStack2026!`)** embedded directly in `README.md`!

Please use Playwright / headless Chromium / Edge / Python on the Windows host (or `controller`) to log into `http://10.10.10.250` (`admin` / `OpenStack2026!`) at `1440x900` (or `1920x1080`) resolution and save the following 5 PNG screenshots into **`docs/images/`** (matching the exact filenames linked in `README.md`):

1. **`docs/images/01-network-topology.png`**
   - Navigate to **Project -> Network -> Network Topology** (`/project/network_topology/`), switch to the **Graph** view showing `public-net`, `demo-router`, `private-net`, `cirros-vm-01`, and `cirros-vm-02`, wait 2 seconds for the SVG nodes to settle, and capture the screenshot.
2. **`docs/images/02-instances-multinode.png`**
   - Navigate to **Project -> Compute -> Instances** (`/project/instances/` or **Admin -> Compute -> Instances** `/admin/instances/` so the **Host** column `compute01` / `compute02` is visible alongside `cirros-vm-01`, `cirros-vm-02`, `10.10.30.132`, `192.168.100.237`, `192.168.100.218`, and `ACTIVE` status!).
3. **`docs/images/03-hypervisors-compute.png`**
   - Navigate to **Admin -> Compute -> Hypervisors** (`/admin/hypervisors/`) showing `compute01` and `compute02` (`QEMU`, VCPUs, RAM, Local Disk, Instances).
4. **`docs/images/04-cinder-volumes.png`**
   - Navigate to **Project -> Volumes -> Volumes** (`/project/volumes/`) showing `demo-vol-01` (`1 GiB`, `In-Use`, `Attached to cirros-vm-01 on /dev/vdb`).
5. **`docs/images/05-system-services.png`**
   - Navigate to **Admin -> System -> System Information** (`/admin/info/`) showing the active OpenStack Services / Compute Services / Network Agents tables.

### Commit & Push:
Once the 5 PNG files are saved in `docs/images/`, remove `AGENT_SYNC.md` (or update status) and commit + push to `origin main`:
```bash
git add docs/images/*.png AGENT_SYNC.md
git commit -m "docs(ui): add live OpenStack 2025.2 Horizon dashboard screenshots"
git push origin main
```
