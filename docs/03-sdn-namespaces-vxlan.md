# 03 -- Software-Defined Networking (SDN): Linux Namespaces, veth, Cross-Node VXLAN & MTU 1450 vs 1500

## 1. Architectural Purpose

Before deploying OpenStack Neutron (`ML2/Open vSwitch`), we built and verified a functional **Layer-2-over-Layer-3 VXLAN Overlay Network** across `compute01` (`10.10.20.21`) and `compute02` (`10.10.20.22`) using native Linux kernel primitives (`ip netns`, `veth`, `bridge`, `vxlan`).

### 1.1 Mapping Linux SDN Primitives to OpenStack Neutron
| Linux Kernel Primitive (This Lab) | OpenStack Neutron Equivalent | Architectural Role |
| :--- | :--- | :--- |
| `ip netns` (`ns-vm1`, `ns-vm2`) | Guest VM / `qrouter-*` / `qdhcp-*` | Isolated network stack (private interfaces, routing table, iptables). |
| `veth` pair (`veth-vm1` <-> `veth-br1`) | `tap*` / `qvo*` <-> `qvb*` | Virtual patch cable connecting a workload/namespace to the local virtual switch. |
| Linux Bridge (`br-sdn`) | OVS `br-int` (Integration Bridge) | Local virtual switch connecting workloads on the same hypervisor. |
| `vxlan100` (`VNI 100`, `UDP 4789` on `ens34`) | OVS `br-tun` (Tunnel Bridge) | Encapsulates Layer-2 tenant frames inside UDP packets across the physical underlay (`10.10.20.0/24`). |
| `iptables -t nat MASQUERADE` on `ens33` | OVS `br-ex` + `qrouter` SNAT/DNAT | Translates private tenant IPs (`192.168.100.0/24`) to external routable IPs. |

### 1.2 The 50-Byte VXLAN Encapsulation Math (`MTU 1450`)
When an inner Ethernet frame leaves `ns-vm1` (`192.168.100.11`) and enters `vxlan100`, the Linux kernel prepends **50 bytes** of outer headers before transmitting it over `ens34` (`MTU 1500`):
- **Outer Ethernet Header:** `14 bytes`
- **Outer IPv4 Header (`10.10.20.21` -> `10.10.20.22`):** `20 bytes`
- **Outer UDP Header (`Dst Port 4789`):** `8 bytes`
- **VXLAN Header (`VNI 100`):** `8 bytes`
- **Total Overhead:** `14 + 20 + 8 + 8 = 50 bytes`

Therefore, the maximum unfragmented inner IP packet size is **`1500 - 50 = 1450 bytes`** (`1422 bytes` ICMP payload + `20 bytes` inner IP + `8 bytes` ICMP header). Any `1500-byte` inner packet with the `DF` (Don't Fragment) bit set will be dropped immediately (**MTU Blackhole**).

---

## 2. Executed Commands

### 2.1 `compute01` (`10.10.20.21`) Overlay Setup
```bash
sudo ip netns add ns-vm1
sudo ip link add br-sdn type bridge
sudo ip link set br-sdn up

sudo ip link add veth-vm1 type veth peer name veth-br1
sudo ip link set veth-vm1 netns ns-vm1
sudo ip link set veth-br1 master br-sdn
sudo ip link set veth-br1 up

sudo ip netns exec ns-vm1 ip link set lo up
sudo ip netns exec ns-vm1 ip addr add 192.168.100.11/24 dev veth-vm1
sudo ip netns exec ns-vm1 ip link set veth-vm1 up

sudo ip link add vxlan100 type vxlan id 100 local 10.10.20.21 remote 10.10.20.22 dev ens34 dstport 4789
sudo ip link set vxlan100 master br-sdn
sudo ip link set vxlan100 up
```

### 2.2 `compute02` (`10.10.20.22`) Overlay Setup
```bash
sudo ip netns add ns-vm2
sudo ip link add br-sdn type bridge
sudo ip link set br-sdn up

sudo ip link add veth-vm2 type veth peer name veth-br2
sudo ip link set veth-vm2 netns ns-vm2
sudo ip link set veth-br2 master br-sdn
sudo ip link set veth-br2 up

sudo ip netns exec ns-vm2 ip link set lo up
sudo ip netns exec ns-vm2 ip addr add 192.168.100.12/24 dev veth-vm2
sudo ip netns exec ns-vm2 ip link set veth-vm2 up

sudo ip link add vxlan100 type vxlan id 100 local 10.10.20.22 remote 10.10.20.21 dev ens34 dstport 4789
sudo ip link set vxlan100 master br-sdn
sudo ip link set vxlan100 up
```

### 2.3 Cross-Node VXLAN & MTU Boundary Verification (`compute01`)
```bash
# 1. Verify cross-node overlay ping
sudo ip netns exec ns-vm1 ping -c 2 192.168.100.12

# 2. Inspect VXLAN encapsulation parameters and learned MACs in FDB
ip -d link show vxlan100
bridge fdb show dev vxlan100

# 3. 1450-byte inner packet (1422 payload + 28 IP/ICMP) with DF bit -> PASS
sudo ip netns exec ns-vm1 ping -c 2 -M do -s 1422 192.168.100.12

# 4. 1500-byte inner packet (1472 payload + 28 IP/ICMP) with DF bit -> FAIL (MTU Blackhole)
sudo ip netns exec ns-vm1 ping -c 2 -M do -s 1472 192.168.100.12
```

---

## 3. Verified Live Results

### 3.1 VXLAN Interface & FDB Table (`compute01`)
```text
11: vxlan100: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue master br-sdn state UNKNOWN
    vxlan id 100 remote 10.10.20.22 dev ens34 srcport 0 0 dstport 4789 ttl auto ageing 300

=== COMPUTE01: FDB TABLE (VXLAN100) ===
00:00:00:00:00:00 dst 10.10.20.22 via ens34 self permanent
fe:bf:6a:e1:c8:d9 dst 10.10.20.22 self
```
*(Notice how `vxlan100` dynamically learned the MAC address `fe:bf:6a:e1:c8:d9` of `ns-vm2`'s `veth-vm2` interface on remote VTEP `10.10.20.22`).*

### 3.2 `MTU 1450` vs `MTU 1500` Proof
```text
=== COMPUTE01: PING 1450 BYTES (-s 1422 -M do) -> PASS PROOF ===
PING 192.168.100.12 (192.168.100.12) 1422(1450) bytes of data.
1430 bytes from 192.168.100.12: icmp_seq=1 ttl=64 time=0.418 ms
1430 bytes from 192.168.100.12: icmp_seq=2 ttl=64 time=1.10 ms
--- 192.168.100.12 ping statistics ---
2 packets transmitted, 2 received, 0% packet loss, time 1009ms

=== COMPUTE01: PING 1500 BYTES (-s 1472 -M do) -> FAIL PROOF ===
PING 192.168.100.12 (192.168.100.12) 1472(1500) bytes of data.
--- 192.168.100.12 ping statistics ---
2 packets transmitted, 0 received, +2 errors, 100% packet loss, time 1007ms
```

- **Full Raw Evidence Log:** [`evidence/02-week2-sdn-vxlan-mtu.txt`](../evidence/02-week2-sdn-vxlan-mtu.txt)
