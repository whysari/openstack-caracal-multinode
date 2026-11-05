# 02 — Linux Kernel Cgroups v2, OOM-Killer & Cinder LVM Block Storage

## 1. Architectural Purpose

### 1.1 Linux Cgroups v2 & Kernel OOM-Killer (`compute01`)
Every KVM virtual machine (`qemu-system-x86_64`) spawned by OpenStack Nova and every container managed by Docker/containerd is isolated by the Linux kernel's **Control Groups (Cgroups v2)** unified hierarchy (`/sys/fs/cgroup`).
- When a workload exceeds its memory ceiling (`memory.max` / systemd `MemoryMax`), the kernel triggers the **Out-Of-Memory (OOM) Killer** scoped specifically to that cgroup (`CONSTRAINT_MEMCG`) rather than crashing the physical hypervisor.
- Understanding how to identify `CONSTRAINT_MEMCG` vs. host-wide memory exhaustion (`CONSTRAINT_NONE`) in `dmesg` / `journalctl -k` is essential for production cloud troubleshooting.

### 1.2 LVM Block Storage Architecture for OpenStack Cinder (`controller`)
OpenStack Cinder (`cinder-volume`) provisions persistent block storage by carving **Logical Volumes (LVs)** out of a dedicated LVM **Volume Group (`cinder-volumes`)** and exporting them over the network via **iSCSI (`tgt` / `iscsid`)** to the hypervisors (`compute01`, `compute02`).

---

## 2. Executed Commands

### 2.1 Cgroups v2 Inspection & Deterministic OOM-Kill Drill (`compute01`)
```bash
# Verify Cgroups v2 unified hierarchy and enabled controllers
mount | grep cgroup2
cat /sys/fs/cgroup/cgroup.controllers
systemd-cgls --no-pager | head -n 30

# Launch transient systemd scope with 32 MiB hard RAM limit, 0 Swap, 50% CPU quota,
# and attempt to allocate 64 MiB in Python to trigger CONSTRAINT_MEMCG OOM-kill
sudo systemd-run --scope \
  -p MemoryMax=32M \
  -p MemorySwapMax=0M \
  -p CPUQuota=50% \
  python3 -c "a = bytearray(64 * 1024 * 1024); print('Success')"

# Inspect the kernel OOM-killer trace
sudo dmesg -T | grep -E -i "oom-kill|out of memory|killed process" | tail -n 10
```

### 2.2 LVM Physical Volume & `cinder-volumes` Volume Group (`controller`)
```bash
# Inspect raw 20 GiB block device
lsblk /dev/sdb

# Initialize LVM Physical Volume and create cinder-volumes Volume Group
sudo pvcreate /dev/sdb
sudo vgcreate cinder-volumes /dev/sdb
sudo pvs
sudo vgs

# Practice LV lifecycle (create -> format ext4 -> mount -> unmount -> remove)
sudo lvcreate -L 1G -n lv_practice cinder-volumes
sudo mkfs.ext4 /dev/cinder-volumes/lv_practice
sudo mount /dev/cinder-volumes/lv_practice /mnt
df -h /mnt
sudo umount /mnt
sudo lvremove -y /dev/cinder-volumes/lv_practice
sudo vgs
```

---

## 3. Verified Live Outputs

### 3.1 Kernel OOM-Killer Trace (`compute01`)
```text
[ 5603.364024] python3 invoked oom-killer: gfp_mask=0xcc0(GFP_KERNEL), order=0, oom_score_adj=0
[ 5603.364248] oom-kill:constraint=CONSTRAINT_MEMCG,nodemask=(null),cpuset=/,mems_allowed=0,oom_memcg=/system.slice/run-re622fd26285244bea55dab31852ed168.scope,task_memcg=/system.slice/run-re622fd26285244bea55dab31852ed168.scope,task=python3,pid=2550,uid=0
[ 5603.364258] Memory cgroup out of memory: Killed process 2550 (python3) total-vm:83524kB, anon-rss:32512kB, file-rss:6656kB, shmem-rss:0kB, UID:0 pgtables:132kB oom_score_adj:0
```
- **`anon-rss:32512kB`** (~31.75 MiB) confirms the process was terminated immediately upon hitting the `32 MiB` `MemoryMax` boundary inside its systemd scope without affecting host stability.

### 3.2 LVM Volume Group Status (`controller`)
```text
  VG             #PV #LV #SN Attr   VSize   VFree  
  cinder-volumes   1   0   0 wz--n- <20.00g <20.00g
  ubuntu-vg        1   1   0 wz--n- <23.00g      0 
```

- **Full Raw Evidence Log:** [`evidence/01-week1-linux-lvm-cgroups.txt`](../evidence/01-week1-linux-lvm-cgroups.txt)
