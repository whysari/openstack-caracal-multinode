# 10 — Troubleshooting

Symptom → likely layer → command. Work from the bottom up: most "OpenStack is broken" reports are
a dead agent, a full disk, or a clock that drifted.

---

## First three commands for any failure

```bash
source ~/admin-openrc
openstack network agent list
openstack compute service list
openstack volume service list
```

Any `down`/`False` row is the first thing to fix. Logs:

```bash
journalctl -u neutron-server -n 100 --no-pager
journalctl -u nova-compute -n 100 --no-pager
journalctl -u cinder-volume -n 100 --no-pager
tail -100 /var/log/swift/proxy.log
```

---

## Identity and messaging

| Symptom | Check | Fix |
|---|---|---|
| `Unable to establish connection to http://controller01:5000` | `ss -lntp \| grep 5000`, `systemctl status apache2` | Apache/Keystone down; check `/var/log/apache2/keystone-error.log` |
| `The request you have made requires authentication` | `openstack token issue`, compare `OS_PASSWORD` | wrong password or domain; re-source `admin-openrc` |
| `AMQPChannelAddressError` / `ConnectionRefusedError` | `nc -vz controller01 5672`, `rabbitmqctl status` | RabbitMQ down or `transport_url` typo |
| `Access refused for user 'openstack'` | `rabbitmqctl list_permissions` | re-run `set_permissions openstack ".*" ".*" ".*"` |
| Token validation slow / random 401s | `chronyc tracking`, `date` on all nodes | enable chrony everywhere; clock skew breaks Fernet |
| `DBConnectionError` | `mysql -h controller01 -u nova -p`, `ss -lntp \| grep 3306` | MariaDB bind address or grant missing |

## Nova

| Symptom | Check | Fix |
|---|---|---|
| Instance stuck `BUILD` | `openstack server show -c fault`, `journalctl -u nova-compute` | read `fault.message`; usually port binding or image |
| `No valid host was found` | `openstack hypervisor list`, `openstack resource provider list` | computes not registered; `nova-manage cell_v2 discover_hosts` |
| `Port binding failed` | `openstack network agent list` | OVS agent down or wrong `bridge_mappings` |
| Instance boots but no console | `openstack console url show`, `ss -lntp \| grep 6080` | `nova-novncproxy` down or `novncproxy_base_url` wrong |
| Compute disappears after reboot | `systemctl is-enabled nova-compute` | enable the unit, then re-run `discover_hosts` |

## Neutron / OVS

| Symptom | Check | Fix |
|---|---|---|
| No DHCP address | `ip netns`, `journalctl -u neutron-dhcp-agent` | `qdhcp` namespace missing; restart DHCP agent |
| DHCP offer but no metadata | `curl 169.254.169.254` from guest | shared secret mismatch; compare both configs |
| Floating IP unreachable | `ip netns exec qrouter-… ip route`, `iptables -t nat -S` | missing gateway or NAT rule; check `br-ex` mapping |
| Ping works, SSH times out | `openstack security group rule list default` | add TCP/22 ingress |
| East–west fails across computes | `ovs-vsctl show \| grep vxlan`, `nc -vzu <peer> 4789` | wrong `local_ip`, firewall on UDP/4789, or MTU |
| Large packets hang, small work | guest MTU, `ip link show br-tun` | VXLAN overhead; set MTU 1450 on tenant nets |
| `br-ex` has an IP and traffic loops | `ip addr show br-ex` | remove the address; the router namespace owns it |
| Agent `UP` but no flows | `ovs-ofctl dump-flows br-int` | agent/OVS version mismatch or `openvswitch` service restarted |

Reset a single agent without touching the whole cloud:

```bash
sudo systemctl restart neutron-openvswitch-agent
sudo systemctl restart neutron-l3-agent
sudo systemctl restart neutron-dhcp-agent
```

## Cinder

| Symptom | Check | Fix |
|---|---|---|
| Volume stuck `creating` | `journalctl -u cinder-volume`, `vgs` | VG missing or `tgt` down |
| `No valid backend` | `openstack volume service list` | cinder-volume down; check `enabled_backends` spelling |
| Attach succeeds, no `/dev/vdb` | `iscsiadm -m session`, `journalctl -u nova-compute` | `open-iscsi` missing on compute |
| `target already exists` | `tgtadm --mode target --op show` | stale target; restart `tgt` and cinder-volume |
| Volume delete hangs | `lvs`, `tgtadm` | LV still mapped; detach from guest first |

## Swift

| Symptom | Check | Fix |
|---|---|---|
| Proxy 503 | `ss -lntp \| grep -E '6200\|6201\|6202'` | storage services down |
| 503 on one node only | `swift-ring-builder …`, ring files | ring not distributed or hash mismatch |
| `Mount check failed` | `mount \| grep /srv/node` | device not mounted; `mount -a` |
| Objects only on one node | `find /srv/node/d1/objects` on each | replicas not 3 or ring not rebalanced |
| Replication errors | `tail /var/log/rsyncd.log`, `nc -vz <peer> 873` | rsync daemon/firewall |
| 401 from Swift | `openstack token issue`, `operator_roles` | user lacks `admin`/`user` role on the project |

## Full-disk and resource issues

```bash
df -h /var/lib/nova /var/lib/cinder /srv/node /var/log
openstack hypervisor show compute01 -c free_disk_gb -c free_ram_mb
```

Nova refuses to schedule when the instance disk cannot fit; Cinder refuses to create volumes when
the VG is full; Swift goes read-only-ish when a device fills. Clean up old images/volumes before
blaming the scheduler.

## Rebuild order after a host reboot

1. `network01`: `openvswitch-switch`, then neutron agents (systemd ordering handles it).
2. `storage01`: `tgt`, `cinder-volume`, Swift services, and re-attach any loopback VG.
3. computes: `libvirtd`, `nova-compute`, `neutron-openvswitch-agent`.
4. `controller01`: MariaDB, RabbitMQ, memcached, then the APIs.

Check `systemctl --failed` on every node after boot; the repo's evidence script captures it.

---

Back to: [README](../README.md) · [09 — Verification](09-verification.md)
