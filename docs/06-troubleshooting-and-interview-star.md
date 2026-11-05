# 06 -- Troubleshooting Case Studies (STAR Format) & Technical Interview Reference

This document captures the real engineering incidents resolved during the ground-up build of our 3-node OpenStack 2025.2 (Flamingo) cluster, structured in the **STAR (Situation, Task, Action, Result)** method for Cloud Systems Engineer technical interviews.

---

## Case Study 1: Upstream Container Registry Tag Retention & Release Alignment
- **Situation:** During initial `kolla-ansible deploy` on Ubuntu 24.04.5 LTS (`Noble Numbat`), the Ansible handler `Restart kolla-toolbox container` failed with `404 Client Error: Not Found` when attempting to pull `quay.io/openstack.kolla/kolla-toolbox:2024.1-ubuntu-noble`.
- **Task:** Diagnose why the container tag failed to resolve and align the control-plane orchestration with actively maintained Ubuntu 24.04 container images without introducing configuration template drift.
- **Action:**
  1. Queried the Quay.io v1 Repository API (`https://quay.io/api/v1/repository/openstack.kolla/kolla-toolbox/tag/`) directly from `controller` and confirmed upstream Kolla CI had pruned legacy 2024 tags in favor of modern Ubuntu Noble releases (`2025.1-ubuntu-noble`, `2025.2-ubuntu-noble`).
  2. Rejected the unsafe shortcut of overriding `openstack_tag` on an older Kolla-Ansible version (which would mismatch Jinja2 configuration templates against newer container entrypoints).
  3. Upgraded the deployment virtualenv to `kolla-ansible==21.3.0` (`stable/2025.2` Flamingo) with `ansible-core==2.19.15`, regenerated `/etc/kolla/passwords.yml` and `/etc/kolla/multinode`, and set `openstack_release: "2025.2"`.
- **Result:** `prechecks`, `deploy` (421 tasks on `controller`, 92 on `compute01`, 89 on `compute02`), and `post-deploy` completed with **0 failures** (`evidence/03-kolla-control-plane.txt`).

---

## Case Study 2: Running a 3-Node Multi-Service Cloud Inside a 16 GB Host RAM Budget
- **Situation:** Our physical hypervisor host (Intel Core i5-9400F) had 16 GB DDR4 RAM total, leaving 10.0 GiB for the 3 cluster VMs (`controller`: 5.0 GiB, `compute01`: 2.5 GiB, `compute02`: 2.5 GiB). By default, Kolla-Ansible spawns multiple Gunicorn/uWSGI and Oslo RPC worker forks per OpenStack service plus Fluentd log forwarders, consuming >7 GiB RAM on the controller alone and risking kernel OOM kills.
- **Task:** Engineer the cluster configuration so all 37 control-plane containers on `controller` and KVM guest instances on `compute01`/`compute02` run with zero swap thrashing or OOM terminations.
- **Action:**
  1. Set `openstack_service_workers: "1"` and `openstack_service_rpc_workers: "1"` in `/etc/kolla/globals.yml` to cap API and RPC worker forks across Keystone, Glance, Placement, Nova, Neutron, and Cinder.
  2. Set `enable_fluentd: "no"` to eliminate Ruby/Fluentd memory overhead on all 3 nodes.
  3. Enabled `zram-tools` (`lz4` compressed in-RAM swap) on all 3 nodes and expanded Ubuntu's default 50% LVM root volume (`11.5 GiB` -> `23.0 GiB`) via `lvextend -l +100%FREE -r /dev/ubuntu-vg/ubuntu-lv`.
- **Result:** All 37 containers on `controller` and 9 containers per compute node run stably with >2 GiB available memory headroom and sub-millisecond control-plane API response times.

---

## Case Study 3: VXLAN 50-Byte Encapsulation Overhead & MTU Blackhole Prevention
- **Situation:** In multi-node SDN overlays, virtual machines communicating across VXLAN tunnels often succeed on small ICMP pings (`64 bytes`) but hang during SSH handshakes, TLS negotiation, or large HTTP transfers.
- **Task:** Mathematically and empirically prove the VXLAN MTU boundary between `compute01` (`10.10.20.21`) and `compute02` (`10.10.20.22`) across the `ens34` (`MTU 1500`) tunnel interface.
- **Action:**
  1. Built an isolated cross-node VXLAN overlay (`vxlan100`, VNI `100`, UDP `4789`) connecting Linux network namespaces `ns-vm1` (`compute01`) and `ns-vm2` (`compute02`).
  2. Tested non-fragmented ICMP frames (`ping -M do`) at exact boundary sizes:
     - `ping -c 2 -M do -s 1422` (`1422` payload + `20B` IP + `8B` ICMP = `1450B` inner frame + `50B` outer VXLAN/UDP/IP/Eth header = `1500B` on wire) -> **0% packet loss (`0.418 ms`)**.
     - `ping -c 2 -M do -s 1472` (`1500B` inner frame + `50B` VXLAN overhead = `1550B`) -> **100% packet loss (`message too long, mtu=1450`)**.
- **Result:** Verified that Neutron's DHCP agent automatically advertises `mtu 1450` (`Option 26`) to tenant VMs (`cirros-vm-01` and `cirros-vm-02`), preventing silent MTU blackholes (`evidence/02-week2-sdn-vxlan-mtu.txt` & `evidence/04-workloads-and-drills.txt`).

---

## Case Study 4: Control-Plane vs. Data-Plane Decoupling During SDN Agent Outage
- **Situation:** During production maintenance or container restarts, the `neutron-openvswitch-agent` daemon on a hypervisor may stop or lose connection to RabbitMQ.
- **Task:** Verify whether an outage of `neutron_openvswitch_agent` on `compute01` interrupts active East-West or North-South network traffic for running VMs (`cirros-vm-01`).
- **Action:**
  1. Initiated continuous North-South ICMP traffic to `cirros-vm-01` (`10.10.30.132`) and stopped the `neutron_openvswitch_agent` container on `compute01` (`sudo docker stop neutron_openvswitch_agent`).
  2. Verified that `openvswitch_vswitchd` and the Linux kernel OVS datapath retained all programmed OpenFlow rules in `br-int`, `br-tun`, and `br-ex`, resulting in **0% packet loss** for existing workloads.
  3. Restarted `neutron_openvswitch_agent` and verified automatic AMQP reconnection and state synchronization (`Alive: :-)`, `State: UP`).
- **Result:** Confirmed high-availability separation between the SDN control agent (which programs flows for *new* ports) and the Open vSwitch forwarding plane (`evidence/04-workloads-and-drills.txt`).
