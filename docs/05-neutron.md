# 05 — Neutron: ML2, OVS, VXLAN, router

**Goal:** a self-service VXLAN network, a flat provider network, a router with an external
gateway, and floating IPs that work from the physical LAN.

Roles:

- `controller` — `neutron-server`, ML2, OVS agent, L3 agent, DHCP agent, metadata agent,
  `br-ex`. **The controller is the network node.**
- `compute1`, `compute2` — OVS agent only (`br-int`, `br-tun`), no provider bridge.

---

## 1. Database and credentials (controller)

```bash
sudo mysql <<'SQL'
CREATE DATABASE neutron;
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'localhost' IDENTIFIED BY 'NEUTRON_DBPASS';
GRANT ALL PRIVILEGES ON neutron.* TO 'neutron'@'%' IDENTIFIED BY 'NEUTRON_DBPASS';
SQL

source ~/admin-openrc
openstack user create --domain default --password NEUTRON_PASS neutron
openstack role add --project service --user neutron admin
openstack service create --name neutron --description "OpenStack Networking" network
for iface in public internal admin; do
  openstack endpoint create --region RegionOne network "$iface" http://controller:9696
done
```

## 2. Controller: server and agents

```bash
sudo apt install -y neutron-server neutron-plugin-ml2 \
  neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent \
  neutron-metadata-agent
```

Copy:

- [`configs/controller/neutron.conf`](../configs/controller/neutron.conf) → `/etc/neutron/neutron.conf`
- [`configs/controller/ml2_conf.ini`](../configs/controller/ml2_conf.ini) → `/etc/neutron/plugins/ml2/ml2_conf.ini`
- [`configs/controller/openvswitch_agent.ini`](../configs/controller/openvswitch_agent.ini) → `/etc/neutron/plugins/ml2/openvswitch_agent.ini`
- [`configs/controller/l3_agent.ini`](../configs/controller/l3_agent.ini) → `/etc/neutron/l3_agent.ini`
- [`configs/controller/dhcp_agent.ini`](../configs/controller/dhcp_agent.ini) → `/etc/neutron/dhcp_agent.ini`
- [`configs/controller/metadata_agent.ini`](../configs/controller/metadata_agent.ini) → `/etc/neutron/metadata_agent.ini`

The critical values:

```ini
# ml2_conf.ini
[ml2]
type_drivers = flat,vlan,vxlan
tenant_network_types = vxlan
mechanism_drivers = openvswitch,l2population

[ml2_type_flat]
flat_networks = provider

# openvswitch_agent.ini
[ovs]
bridge_mappings = provider:br-ex
local_ip = 192.168.100.24
```

Neutron expects the plugin config at a stable path:

```bash
sudo ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

Populate the database:

```bash
sudo su -s /bin/sh -c "neutron-db-manage \
  --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
  upgrade head" neutron
```

Confirm `br-ex` before starting the agents:

```bash
ip -br address show br-ex          # 192.168.100.24/24
ovs-vsctl list-ports br-ex         # the physical NIC
```

Start:

```bash
sudo systemctl enable --now neutron-server neutron-openvswitch-agent \
  neutron-l3-agent neutron-dhcp-agent neutron-metadata-agent
```

## 3. Compute agents

On **both** computes:

```bash
sudo apt install -y neutron-openvswitch-agent
```

Copy:

- [`configs/compute1/neutron.conf`](../configs/compute1/neutron.conf) →
  `/etc/neutron/neutron.conf` (same for `compute2`)
- [`configs/compute1/openvswitch_agent.ini`](../configs/compute1/openvswitch_agent.ini) →
  `/etc/neutron/plugins/ml2/openvswitch_agent.ini`
- [`configs/compute2/openvswitch_agent.ini`](../configs/compute2/openvswitch_agent.ini) for
  `compute2`

There is **no `bridge_mappings`** on computes: floating IPs terminate in the router namespace
on the controller.

```bash
sudo systemctl enable --now neutron-openvswitch-agent
```

## 4. Verify the agents

```bash
source ~/admin-openrc
openstack network agent list
```

Expected — six agents, all `Alive: True`, `State: UP`:

| Agent Type | Host |
|---|---|
| Open vSwitch agent | `controller` |
| Open vSwitch agent | `compute1` |
| Open vSwitch agent | `compute2` |
| L3 agent | `controller` |
| DHCP agent | `controller` |
| Metadata agent | `controller` |

The agents create the bridges themselves:

```bash
# controller
ovs-vsctl list-br          # br-ex br-int br-tun
ovs-vsctl show             # patch-int/patch-tun, vxlan port per peer

# compute1 / compute2
ovs-vsctl list-br          # br-int br-tun
```

## 5. Networks, router, floating IPs

```bash
source ~/admin-openrc
./scripts/10-create-networks.sh
```

This creates:

| Object | Values |
|---|---|
| `provider` network | external, flat, physical network `provider` |
| `provider-subnet` | `192.168.100.0/24`, gateway `.1`, pool `.101–.250`, no DHCP, DNS `1.1.1.1` |
| `selfservice` network | VXLAN tenant network |
| `selfservice-subnet` | `172.16.1.0/24`, gateway `172.16.1.1` |
| `router` | gateway on `provider`, interface on `selfservice-subnet` |
| default SG rules | ICMP, TCP/22, TCP/80 |

Verify the namespaces on the controller:

```bash
sudo ip netns
# qrouter-<router-uuid>
# qdhcp-<selfservice-net-uuid>

sudo ip netns exec qrouter-<uuid> ip -4 addr
# 172.16.1.1/24 on qr-...
# 192.168.100.101/24 on qg-...  (after a floating IP is allocated)

sudo ip netns exec qrouter-<uuid> ip route
# default via 192.168.100.1 dev qg-...
# 172.16.1.0/24 dev qr-...
```

## 6. First instance and floating IP

```bash
openstack server create --image cirros --flavor m1.nano \
  --network selfservice --security-group default --key-name smoke --wait selfservice-demo0

openstack floating ip create provider
openstack server add floating ip selfservice-demo0 192.168.100.101

ping -c3 192.168.100.101
ssh cirros@192.168.100.101     # gocubsgo
```

Inside the guest, check the overlay MTU and metadata:

```bash
ip addr show eth0             # mtu 1450 on VXLAN
curl http://169.254.169.254/latest/meta-data/instance-id
```

## 7. Gate check

- Six agents `UP`.
- `qrouter` and `qdhcp` namespaces exist on the controller.
- The router has one address on `172.16.1.0/24` and one on `192.168.100.0/24`.
- Ping and SSH to the floating IP work from the controller or another host on
  `192.168.100.0/24`.

If the instance gets an IP but cannot reach the internet, check NAT inside the router
namespace:

```bash
sudo ip netns exec qrouter-<uuid> iptables -t nat -S | grep -E 'SNAT|DNAT'
sudo ip netns exec qrouter-<uuid> sysctl net.ipv4.ip_forward
```

---

Next: [06 — Cinder](06-cinder.md)
