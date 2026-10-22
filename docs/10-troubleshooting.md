# 10 — Troubleshooting

Work from the bottom of the stack up: host → database/AMQP → API → agent → namespace → guest.
Most "OpenStack bugs" are a stopped service, a wrong IP, or a clock/credential mismatch.

---

## Service and API

| Symptom | Check | Fix |
|---|---|---|
| `Unable to establish connection to http://controller:5000` | `systemctl status apache2`, `ss -lntp \| grep 5000` | Start Apache; check the Keystone WSGI symlink |
| `AMQPChannelAddressError` / `ConnectionRefusedError 5672` | `rabbitmqctl status`, `rabbitmqctl list_users` | Start RabbitMQ; recreate the `openstack` user/permissions |
| `Access denied for user 'nova'@'controller'` | `mysql -u nova -p -h controller` | Re-grant the service user for `'%'` as well as `localhost` |
| `401 Unauthorized` from every client | `openstack token issue`, `chronyc tracking` | Fix NTP; re-source the RC file; check the password placeholder |
| `404` on a service endpoint | `openstack endpoint list` | Recreate the endpoint with the right port/version |

## Nova

| Symptom | Check | Fix |
|---|---|---|
| `nova-compute` down | `systemctl status nova-compute`, `journalctl -u nova-compute -n 100` | Fix the config/AMQP error; `systemctl enable --now nova-compute` |
| Instance stuck `BUILD` | `openstack server show <id>`, `nova-compute` log | Usually a port binding failure — see the Neutron table |
| `No valid host was found` | `openstack hypervisor list`, `openstack resource provider list` | Compute down, or not discovered: `nova-manage cell_v2 discover_hosts` |
| `libvirtError: unsupported configuration: host doesn't support...` | `egrep -c '(vmx\|svm)' /proc/cpuinfo` | Set `[libvirt] virt_type = qemu` |
| Console blank | `systemctl status nova-novncproxy`, port 6080 | Start novncproxy; check `novncproxy_base_url` uses `.24` |

## Neutron

| Symptom | Check | Fix |
|---|---|---|
| OVS agent down | `journalctl -u neutron-openvswitch-agent -n 100` | Fix `local_ip` / `bridge_mappings`; restart |
| `binding:failed` on a port | `openstack network agent list` | The compute's OVS agent is down or the host is not in the agents list |
| No DHCP | `ip netns`, `journalctl -u neutron-dhcp-agent` | Start the DHCP agent; check `interface_driver = openvswitch` |
| Metadata 500 | Compare `metadata_proxy_shared_secret` in `nova.conf` and `metadata_agent.ini` | Make them identical; restart both services |
| Floating IP unreachable | `ovs-vsctl show`, `ip netns exec qrouter-... ip route` | `br-ex` missing the NIC, wrong gateway, or `rp_filter` |
| Router namespace missing | `openstack router show router`, `ip netns` | Re-add the external gateway and the selfservice subnet |
| VXLAN traffic not passing | `ovs-vsctl show` on both ends, `ping <local_ip>` | Check `local_ip` on each host and UDP 4789 reachability |

## Cinder

| Symptom | Check | Fix |
|---|---|---|
| `cinder-volume` down on `block` | `journalctl -u cinder-volume -n 100` | Fix the DB/AMQP connection or the LVM filter |
| `No valid backend` | `openstack volume service list` | `enabled_backends = lvm` must match the `[lvm]` section |
| Attach fails | `systemctl status tgt`, `tgtadm --mode target --op show` | Start `tgt`; check the include file and TCP/3260 |
| Volume stuck `creating` | `vgs cinder-volumes`, `lvs` | The VG is missing or the LVM filter hides `/dev/sdb` |
| Guest does not see the disk | `cat /proc/partitions` | The image may need the virtio-scsi driver; check the compute log |

## Swift

| Symptom | Check | Fix |
|---|---|---|
| `503 Service Unavailable` | `journalctl -u swift-proxy`, `/var/log/swift/proxy.log` | Ring missing on the controller, or object servers down |
| `401` from `openstack object` | `swift stat`; check `authtoken`/`keystoneauth` pipeline | Keystone endpoint/password mismatch |
| `Account not found` | `swift stat` | `account_autocreate = true` in the proxy; create the container first |
| Object servers not starting | `mount_check` and `/srv/node` | Set `mount_check = false` for directory devices |
| Ring says `0 devices` | `swift-ring-builder *.builder` | Re-run the `add` commands and `rebalance` |
| Replication never completes | `swift-init all status`, `rsync` | Single node has no peers; this is expected |

## Horizon

| Symptom | Check | Fix |
|---|---|---|
| `OfflineGenerationError` | `/etc/openstack-dashboard/local_settings.py` | Set `COMPRESS_OFFLINE = False`; restart Apache |
| Login loops | `OPENSTACK_KEYSTONE_URL`, Memcached | Use `http://controller:5000/v3`; start Memcached |
| `SECRET_KEY` error | `/etc/openstack-dashboard/local_settings.py` | Set a unique `SECRET_KEY` |
| 500 on every page | `/var/log/apache2/error.log` | Usually a Python package mismatch after an upgrade |

## Host and network

| Symptom | Check | Fix |
|---|---|---|
| Controller unreachable after netplan | `ip -br address`, `ovs-vsctl show` | The IP must be on `br-ex`, not the physical NIC; use `netplan try` |
| Hosts cannot resolve each other | `getent hosts controller` | Fix `/etc/hosts` on all five nodes |
| Clock skew | `chronyc tracking` | Start/configure chrony; allow NTP on the LAN |
| SSH to instance times out, ping works | `openstack security group rule list default` | Add TCP/22 |
| Large packets hang | `ip addr` in the guest | VXLAN MTU 1450; set `path_mtu = 1500` |

---

More commands and expected outputs: [09 — Verification](09-verification.md).
