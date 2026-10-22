# 11 — Completing the build and capturing final evidence

The configuration in this repository describes the full five-node design. The lab capture was
taken before the last operational steps: `compute2` was intentionally stopped for the demo,
`compute1` stayed up and hosted the demo instance, and the capture did not include a
floating-IP/SSH or volume-attach screenshot.

This page is the checklist that turns the as-built cluster into a fully verified one. Run it on
the real hosts, then update the README with the output — not with assumptions.

---

## 1. Check the current state

From `controller`:

```bash
source ~/admin-openrc

openstack compute service list
openstack network agent list
openstack volume service list
openstack hypervisor list
openstack server list
```

Typical findings from the lab capture:

- `nova-compute` on `compute1`: `up`; on `compute2`: `down` (intentional).
- OVS agent on `compute1`: `up`; on `compute2`: `down` (intentional).
- A stale `nova-compute` service record on `controller` (from an earlier all-in-one attempt).
- `selfservice-demo0` still `ACTIVE` on `compute1`, created 22 hours before the capture.

## 2. Start both computes

On `compute1` and `compute2`:

```bash
sudo systemctl enable --now nova-compute
sudo systemctl enable --now neutron-openvswitch-agent
sudo systemctl status nova-compute --no-pager
sudo systemctl status neutron-openvswitch-agent --no-pager
```

If `nova-compute` fails, read the reason before changing config:

```bash
sudo journalctl -u nova-compute -n 100 --no-pager
sudo journalctl -u neutron-openvswitch-agent -n 100 --no-pager
```

On the controller, discover the hosts and verify:

```bash
sudo su -s /bin/sh -c "nova-manage cell_v2 discover_hosts --verbose" nova
openstack compute service list
openstack network agent list
openstack hypervisor list
```

Expected: four Nova services (conductor, scheduler, two computes) and six Neutron agents, all
up.

## 3. Remove the stale controller compute record

If `openstack compute service list` shows `nova-compute` on `controller` and the controller is
not meant to run instances:

```bash
openstack compute service list --service nova-compute
# find the row whose Host is "controller"

sudo systemctl disable --now nova-compute 2>/dev/null || true
openstack compute service delete <service-id>
```

Then re-run `openstack compute service list` and `openstack hypervisor list`. Do not delete the
record while the service is still running; Nova will recreate it.

## 4. Test floating IP and SSH

```bash
openstack floating ip create provider
# note the address, e.g. 192.168.100.101

openstack server add floating ip selfservice-demo0 192.168.100.101
ping -c3 192.168.100.101
ssh cirros@192.168.100.101          # password: gocubsgo
```

If ping fails, check the router namespace and `br-ex`:

```bash
ROUTER_NS=$(sudo ip netns | awk '/qrouter/{print $1; exit}')
sudo ip netns exec "$ROUTER_NS" ip -4 addr
sudo ip netns exec "$ROUTER_NS" ip route
sudo ip netns exec "$ROUTER_NS" iptables -t nat -S | grep -E 'SNAT|DNAT'
sudo ovs-vsctl show
```

Inside the guest:

```bash
ip addr show eth0
curl http://169.254.169.254/latest/meta-data/instance-id
```

Capture:

```bash
openstack floating ip list | tee evidence/manual/floating-ips.txt
ping -c3 192.168.100.101 | tee evidence/manual/fip-ping.txt
```

## 5. Test volume attach

```bash
openstack volume create --size 1 demo-vol
openstack volume list

openstack server add volume selfservice-demo0 demo-vol
openstack volume show demo-vol -c status -c attachments
```

Expected: `in-use`, attached to `selfservice-demo0`. In the guest:

```bash
cat /proc/partitions
# vdb with 1 GiB
```

If the volume stays `creating`, check `vgs cinder-volumes` and `systemctl status cinder-volume`
on `block`.

## 6. Finish the Swift ring

The initial lab ring builder added only device 1 to each ring, even though `/srv/node/{1,2,3,4}`
exist. A 3-replica ring with one device places all replicas on the same directory. Add the other
three devices on `object`:

```bash
cd /etc/swift

for dev in 2 3 4; do
  swift-ring-builder account.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6002 --device "$dev" --weight 100
  swift-ring-builder container.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6001 --device "$dev" --weight 100
  swift-ring-builder object.builder add \
    --region 1 --zone 1 --ip 192.168.100.28 --port 6000 --device "$dev" --weight 100
done

for b in account.builder container.builder object.builder; do
  swift-ring-builder "$b" rebalance
done

swift-ring-builder object.builder
# 10 partitions, 3.000000 replicas, 1 zones, 4 devices
```

The `min_part_hours` is 1 hour; if `rebalance` refuses because the ring changed recently, wait
or use `--force` only in a lab.

Copy the rings to the controller and restart the proxy:

```bash
for f in /etc/swift/*.ring.gz; do
  sudo scp "$f" controller:/etc/swift/
done
ssh controller 'sudo chown swift:swift /etc/swift/*.ring.gz && sudo systemctl restart swift-proxy'
```

On `object`, restart the data servers:

```bash
sudo systemctl restart swift-account swift-container swift-object
# or: sudo swift-init all restart
```

Verify:

```bash
source ~/demo-openrc
swift stat
openstack container create final-check
openstack object create final-check README.md
openstack object list final-check
```

This is still a **single-node** Swift: four devices improve placement, not node-level
redundancy. Real replication requires `object2`/`object3` and a ring rebalance.

## 7. Run the acceptance test and capture evidence

```bash
cd ~/openstack-caracal-multinode
source ~/admin-openrc

./scripts/20-smoke-test.sh
./scripts/30-collect-evidence.sh
```

Then run the evidence script on the other hosts:

```bash
ssh compute1 'cd ~/openstack-caracal-multinode && ./scripts/30-collect-evidence.sh'
ssh compute2 'cd ~/openstack-caracal-multinode && ./scripts/30-collect-evidence.sh'
ssh block    'cd ~/openstack-caracal-multinode && ./scripts/30-collect-evidence.sh'
ssh object   'cd ~/openstack-caracal-multinode && ./scripts/30-collect-evidence.sh'
```

Commit the resulting `evidence/<timestamp>-*/` directories. The smoke test creates
`smoke-01`, `smoke-vol` and `smoke-container`; remove them with:

```bash
./scripts/99-teardown.sh --yes
```

## 8. Update the README truthfully

Replace the "Capture notes" paragraph with the current results. A useful table:

| Check | Result | Evidence file |
|---|---|---|
| Nova services (4) | up | `evidence/.../compute-service-list.txt` |
| Neutron agents (6) | up | `evidence/.../network-agent-list.txt` |
| Cinder `block@lvm` | up | `evidence/.../volume-service-list.txt` |
| Floating IP ping/SSH | pass | `evidence/manual/fip-ping.txt` |
| Volume attach | `in-use` | `evidence/manual/volume-attach.txt` |
| Swift round-trip | pass | `evidence/.../swift-rings.txt` + smoke output |
| Horizon login | pass | screenshot |

Do not mark a row as passing because the configuration looks right. Run the test.

## 9. Optional next steps

- **Control-plane HA:** three controllers, Galera, RabbitMQ quorum queues, HAProxy/Keepalived,
  and Etcd-backed Cinder coordination.
- **Swift redundancy:** add `object2` and `object3`, put each in its own zone, rebalance.
- **Dedicated networks:** separate management, provider and VXLAN tunnel NICs; keep `br-ex` on
  the provider NIC only.
- **Monitoring:** Prometheus node/OpenStack exporters, Grafana, Loki.
- **Automation:** Kolla-Ansible or OpenStack-Helm, then compare with this hand-built baseline.

---

Back to [09 — Verification](09-verification.md) · [README](../README.md)
