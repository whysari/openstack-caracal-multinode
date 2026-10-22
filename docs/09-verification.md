# 09 — Verification

The smoke test is scripted, but the interesting failures are below the API. This page records
what to check at each layer and what "good" looks like.

---

## 0. Automated run

```bash
source ~/admin-openrc
./scripts/20-smoke-test.sh
```

The script checks identity, control-plane services, agents, image/flavor, instance boot, fixed
and floating IPs, metadata (when run from the provider LAN), volume attach and a Swift
round-trip. Exit code 0 means every executed check passed; checks requiring provider-LAN access
report `SKIP` rather than failing.

Capture the raw state for the repository:

```bash
# controller01
./scripts/30-collect-evidence.sh

# network01 and compute01 — OVS, namespaces, agent logs
./scripts/30-collect-evidence.sh
```

Evidence lands in `evidence/<UTC timestamp>-<host>/`.

---

## 1. Identity

```bash
openstack token issue
openstack endpoint list --service identity
```

Good: a token with `project_id` for `admin`, three endpoints for `keystone` on port 5000.

## 2. Nova

```bash
openstack compute service list
openstack hypervisor list
openstack hypervisor show compute01 -c state -c vcpus -c memory_mb -c running_vms
```

Good: `nova-conductor`, `nova-scheduler`, two `nova-compute` services `enabled/up`; both
hypervisors `up`.

If a compute is missing:

```bash
journalctl -u nova-compute -n 100 --no-pager
grep -E 'transport_url|my_ip' /etc/nova/nova.conf
```

## 3. Neutron agents

```bash
openstack network agent list
```

Good: six agents (three OVS, one L3, one DHCP, one metadata), all `Alive: True`, `State: UP`.

```bash
openstack network agent show <agent-id> -c alive -c state -c heartbeat_timestamp
```

A stale `heartbeat_timestamp` means the agent process is dead even if the API still lists it.

## 4. OVS data path

On `network01`:

```bash
sudo ovs-vsctl show
sudo ovs-vsctl list-br
sudo ovs-ofctl dump-ports br-int
sudo ovs-ofctl dump-flows br-tun | grep -c 'tun_id'
```

Good:

- `br-ex` with `enp2s0` as its only port and `fail_mode` not `secure`-only weirdness.
- `br-int` with `patch-tun` and `patch-ex` ports.
- `br-tun` with one `vxlan` port per peer (`remote_ip="10.10.10.21"`, `.22`), plus `patch-int`.
- Non-zero tunnel flows after an instance is running.

On `compute01`:

```bash
sudo ovs-vsctl show
sudo ovs-vsctl get Interface br-ex type 2>/dev/null || echo "no br-ex (expected)"
```

Good: `br-int`, `br-tun`, a `vxlan` port pointing at `10.10.10.31` and at the other compute.

## 5. Namespaces and NAT

On `network01`:

```bash
sudo ip netns
sudo ip netns exec qrouter-<uuid> ip -4 addr
sudo ip netns exec qrouter-<uuid> ip route
sudo ip netns exec qrouter-<uuid> iptables -t nat -S
sudo ip netns exec qdhcp-<uuid> ip -4 addr
```

Good:

```
# qrouter
10.0.0.1/24 dev qr-...
192.168.100.150/24 dev qg-...
default via 192.168.100.1 dev qg-...
10.0.0.0/24 dev qr-...

# nat
-A POSTROUTING -s 10.0.0.0/24 -j SNAT --to-source 192.168.100.150
-A PREROUTING -d 192.168.100.150/32 -j DNAT --to-destination 10.0.0.12
```

## 6. Instance and metadata

```bash
openstack server show cirros-01 -c status -c addresses -c flavor
openstack port list --server cirros-01
```

Good: `ACTIVE`, one fixed IPv4 on `private`, one port `binding:vif_type=ovs`, `binding:host_id`
set to a compute.

Inside the guest:

```bash
ip addr show eth0           # mtu 1450
ip route                    # default via 10.0.0.1
curl -s http://169.254.169.254/latest/meta-data/instance-id
curl -s http://169.254.169.254/latest/meta-data/local-ipv4
```

If metadata hangs, the problem is between the DHCP namespace and the metadata agent, not Nova:

```bash
# network01
sudo journalctl -u neutron-metadata-agent -n 50
grep metadata_proxy_shared_secret /etc/neutron/metadata_agent.ini
grep metadata_proxy_shared_secret /etc/nova/nova.conf
```

## 7. East–west between computes

Boot one instance on each compute (use an availability zone or `--hint` if needed), then:

```bash
# from cirros-01
ping -c3 <cirros-02 fixed IP>
```

A failure here with both instances `ACTIVE` points at `br-tun`/VXLAN, not at security groups:

```bash
sudo ovs-vsctl show | grep -A3 vxlan
sudo ovs-ofctl dump-flows br-tun table=22     # 22 = VXLAN flood table in ML2/OVS
```

Check that `local_ip` differs per node and that UDP/4789 is open between the computes:

```bash
nc -vzu 10.10.10.21 4789
```

## 8. North–south with a floating IP

From a host on `192.168.100.0/24`:

```bash
ping -c3 192.168.100.150
ssh cirros@192.168.100.150
```

Then verify the return path is NATed:

```bash
# inside the guest
ip route
curl -s ifconfig.me        # should show the provider address, not 10.0.0.12
```

On `network01`, watch the translation:

```bash
sudo ip netns exec qrouter-<uuid> conntrack -L 2>/dev/null | grep 192.168.100.150
```

## 9. Cinder

```bash
openstack volume service list
openstack volume create --size 1 verify-vol
openstack volume show verify-vol -c status
openstack server add volume cirros-01 verify-vol
openstack volume show verify-vol -c status -c attachments
```

On `storage01`:

```bash
sudo tgtadm --mode target --op show
sudo lvs -o lv_name,vg_name,lv_size
```

Good: a target IQN, an ACL for the compute's initiator, and an LV named `volume-<uuid>`.

## 10. Swift

```bash
openstack object store account show
openstack container create verify-container
openstack object create verify-container README.md
openstack object list verify-container
openstack object save verify-container README.md --file /tmp/verify.md
cmp README.md /tmp/verify.md
```

On each storage node:

```bash
sudo swift-ring-builder /etc/swift/object.builder
sudo find /srv/node/d1/objects -type f | wc -l
sudo tail -20 /var/log/swift/object.log
```

Good: three zones, three devices, three replicas, balance 0; object data present on all nodes;
no `ERROR` lines in the object log.

## 11. Known-good results

| Layer | Command | Expected |
|---|---|---|
| Identity | `openstack token issue` | token issued |
| Nova | `openstack compute service list` | 4 services `up` |
| Neutron | `openstack network agent list` | 6 agents `UP` |
| OVS | `ovs-vsctl list-br` | `br-ex br-int br-tun` on network01 |
| Namespaces | `ip netns` | `qrouter-*`, `qdhcp-*` |
| Instance | `openstack server list` | `ACTIVE` with fixed IP |
| Metadata | `curl 169.254.169.254` | instance-id returned |
| Floating IP | `ping <fip>` | replies from provider LAN |
| Cinder | `openstack volume show` | `in-use`, attached |
| Swift | `cmp` after download | identical bytes |

The exact UUIDs, timestamps and counters from a run land in [`evidence/`](../evidence/) when you
execute `scripts/30-collect-evidence.sh`.

---

Next: [10 — Troubleshooting](10-troubleshooting.md)
