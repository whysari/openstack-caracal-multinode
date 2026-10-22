# 09 — Verification

**Goal:** prove the cluster works end to end, not just that the services are installed.

Run from `controller` with `source ~/admin-openrc`.

---

## 1. Service inventory

```bash
openstack compute service list
openstack network agent list
openstack volume service list
openstack hypervisor list
```

Expected:

- Nova: conductor and scheduler on `controller`; compute on `compute1` and `compute2`.
- Neutron: six agents — OVS/L3/DHCP/metadata on `controller`, OVS on both computes.
- Cinder: scheduler on `controller`; volume on `block@lvm`.
- Hypervisors: `compute1`, `compute2`.

Save the output:

```bash
mkdir -p evidence/manual
openstack compute service list      | tee evidence/manual/compute-services.txt
openstack network agent list        | tee evidence/manual/network-agents.txt
openstack volume service list       | tee evidence/manual/volume-services.txt
```

## 2. Network data path

```bash
# controller
sudo ovs-vsctl show                 | tee evidence/manual/controller-ovs.txt
sudo ovs-vsctl list-br
sudo ip netns                       | tee evidence/manual/netns.txt

# compute1 / compute2
sudo ovs-vsctl show                 | tee evidence/manual/$(hostname)-ovs.txt
```

On the controller, inspect the router namespace:

```bash
ROUTER_NS=$(sudo ip netns | awk '/qrouter/{print $1; exit}')
sudo ip netns exec "$ROUTER_NS" ip -4 addr
sudo ip netns exec "$ROUTER_NS" ip route
sudo ip netns exec "$ROUTER_NS" iptables -t nat -S | grep -E 'SNAT|DNAT'
```

Expected: `172.16.1.1/24` on the tenant side; a floating IP on the provider side after
allocation; SNAT/DNAT rules for the instance.

## 3. Instance and floating IP

```bash
openstack server list
openstack floating ip list
ping -c3 <floating-ip>
ssh cirros@<floating-ip>
```

Inside the guest:

```bash
ip addr show eth0
curl http://169.254.169.254/latest/meta-data/instance-id
```

Expected: a `172.16.1.x` address, MTU 1450 on VXLAN, and a metadata instance ID.

If the original demo instance has no floating IP, allocate one:

```bash
openstack floating ip create provider
openstack server add floating ip selfservice-demo0 <floating-ip>
```

## 4. Volume

```bash
openstack volume create --size 1 verify-vol
openstack volume list
openstack server add volume selfservice-demo0 verify-vol
openstack volume show verify-vol -c status -c attachments
```

Expected: `in-use`, attached to `selfservice-demo0`. In the guest, `cat /proc/partitions` shows
the new disk.

## 5. Swift

```bash
openstack container create verify-container
openstack object create verify-container README.md
openstack object list verify-container
openstack object save verify-container README.md --file /tmp/README.verify
cmp README.md /tmp/README.verify
swift-ring-builder /etc/swift/object.builder
```

Expected: identical files; ring 10 partitions / 3 replicas / 4 devices.

## 6. Full acceptance run

```bash
./scripts/20-smoke-test.sh
```

It creates `smoke-01`, a floating IP, `smoke-vol` and `smoke-container`. Clean up with:

```bash
./scripts/99-teardown.sh --yes
```

Capture the output and host state:

```bash
./scripts/30-collect-evidence.sh
```

The script writes to `evidence/<timestamp>-<host>/`. Run it on `controller`, `compute1`,
`compute2`, `block` and `object` to capture the full picture.

## 7. What the lab capture covers

The May 2025 lab capture is the source for the topology and addresses. Its screenshots show:

| Area | Captured |
|---|---|
| Keystone, Glance, Placement | Service registration and API checks |
| Nova | Conductor/scheduler up; `compute1` up and hosting `selfservice-demo0`; `compute2` intentionally stopped |
| Neutron | OVS/L3/DHCP/metadata on controller and OVS on compute1 up; compute2 OVS intentionally down |
| Horizon | Dashboard login and instance view |
| Cinder | `cinder-volume` on `block@lvm` up |
| Swift | `swift stat` and object create/list |
| Instance | `selfservice-demo0` Active at `172.16.1.49` on `compute1` |

The capture does **not** include a floating-IP/SSH screenshot or a volume-attach screenshot.
Those are covered by the smoke test. Do not put a green check in the README for a test that has
not been run on the current cluster.

## 8. Gate check

- `scripts/20-smoke-test.sh` exits 0.
- `evidence/` contains the current run, not an older one.
- The README's capture notes and evidence links match the current run.

---

Next: [10 — Troubleshooting](10-troubleshooting.md)
