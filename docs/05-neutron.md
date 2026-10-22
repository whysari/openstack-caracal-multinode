# 05 — Neutron: ML2, OVS, VXLAN, routers

**Goal:** a self-service VXLAN network, a flat provider network, a router with a gateway, and
floating IPs that work from the physical LAN.

Roles:

- `controller01` — `neutron-server` only (API, ML2, DB)
- `network01` — OVS agent, L3 agent, DHCP agent, metadata agent, `br-ex`
- `compute01/02` — OVS agent (`br-int`, `br-tun`), no provider bridge

---

## 1. Database and credentials (controller01)

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
for iface in public internal; do
  openstack endpoint create --region RegionOne network "$iface" http://controller01:9696
done
openstack endpoint create --region RegionOne network admin http://controller01:9696
```

## 2. Controller server

```bash
sudo apt install -y neutron-server neutron-plugin-ml2
```

Install:

- [`configs/controller/neutron.conf`](../configs/controller/neutron.conf) → `/etc/neutron/neutron.conf`
- [`configs/controller/ml2_conf.ini`](../configs/controller/ml2_conf.ini) → `/etc/neutron/plugins/ml2/ml2_conf.ini`

Neutron expects the plugin config at a stable path:

```bash
sudo ln -sf /etc/neutron/plugins/ml2/ml2_conf.ini /etc/neutron/plugin.ini
```

Populate the database with **both** config files:

```bash
sudo su -s /bin/sh -c "neutron-db-manage \
  --config-file /etc/neutron/neutron.conf \
  --config-file /etc/neutron/plugins/ml2/ml2_conf.ini \
  upgrade head" neutron
```

## 3. Network node

```bash
sudo apt install -y neutron-openvswitch-agent neutron-l3-agent \
  neutron-dhcp-agent neutron-metadata-agent
```

Install:

- [`configs/network/neutron.conf`](../configs/network/neutron.conf)
- [`configs/network/openvswitch_agent.ini`](../configs/network/openvswitch_agent.ini)
- [`configs/network/l3_agent.ini`](../configs/network/l3_agent.ini)
- [`configs/network/dhcp_agent.ini`](../configs/network/dhcp_agent.ini)
- [`configs/network/metadata_agent.ini`](../configs/network/metadata_agent.ini)

The critical values:

```ini
# openvswitch_agent.ini
[ovs]
bridge_mappings = provider:br-ex
local_ip = 10.10.10.31
```

`br-ex` already exists from [host prep](01-host-preparation.md) with `enp2s0` as its port.
Confirm before starting the agent:

```bash
ovs-vsctl list-ports br-ex          # enp2s0
ip addr show br-ex                  # no inet address
```

## 4. Compute agents

On both computes:

```bash
sudo apt install -y neutron-openvswitch-agent
```

Install [`configs/compute/neutron.conf`](../configs/compute/neutron.conf) and
[`configs/compute/openvswitch_agent.ini`](../configs/compute/openvswitch_agent.ini). There is **no
`bridge_mappings`** on computes: floating IPs are handled by the router on `network01`.

## 5. Start and verify

```bash
# controller01
sudo systemctl enable --now neutron-server

# network01
sudo systemctl enable --now neutron-openvswitch-agent neutron-l3-agent \
  neutron-dhcp-agent neutron-metadata-agent

# compute01 / compute02
sudo systemctl enable --now neutron-openvswitch-agent
```

```bash
source ~/admin-openrc
openstack network agent list
```

Expected — six agents, all `Alive: True`, `State: UP`:

| Agent Type | Host |
|---|---|
| Open vSwitch agent | network01 |
| Open vSwitch agent | compute01 |
| Open vSwitch agent | compute02 |
| L3 agent | network01 |
| DHCP agent | network01 |
| Metadata agent | network01 |

The agents create the bridges themselves:

```bash
# network01
ovs-vsctl list-br          # br-ex br-int br-tun
ovs-vsctl show             # patch-int/patch-tun, vxlan port with remote_ip per peer

# compute01
ovs-vsctl list-br          # br-int br-tun
```

## 6. Networks, router, floating IPs

```bash
source ~/admin-openrc
./scripts/10-create-networks.sh
```

This creates:

| Object | Values |
|---|---|
| `provider` network | external, flat, physical network `provider` |
| `provider-subnet` | `192.168.100.0/24`, gateway `.1`, pool `.150–.200`, no DHCP, DNS `1.1.1.1` |
| `private` network | VXLAN tenant network |
| `private-subnet` | `10.0.0.0/24` |
| `router01` | gateway on `provider`, interface on `private-subnet` |
| default SG rules | ICMP, TCP/22, TCP/80 |

Verify the namespaces on `network01`:

```bash
sudo ip netns
# qrouter-<router-uuid>
# qdhcp-<private-net-uuid>

sudo ip netns exec qrouter-<uuid> ip -4 addr
# 10.0.0.1/24 on qr-...
# 192.168.100.150/24 on qg-...

sudo ip netns exec qrouter-<uuid> ip route
# default via 192.168.100.1 dev qg-...
# 10.0.0.0/24 dev qr-...
```

The `qg-` interface comes from the provider bridge; `qr-` is the tenant side.

## 7. First instance and floating IP

```bash
openstack server create --image cirros --flavor m1.tiny \
  --network private --security-group default --key-name smoke --wait cirros-01

openstack floating ip create provider
openstack server add floating ip cirros-01 192.168.100.150

ping -c3 192.168.100.150
ssh cirros@192.168.100.150     # gocubsgo
```

From inside the guest, check the overlay MTU and metadata:

```bash
ip addr show eth0             # mtu 1450 on VXLAN
curl http://169.254.169.254/latest/meta-data/instance-id
```

## 8. Gate check

- Six agents `UP`.
- `qrouter` and `qdhcp` namespaces exist.
- The router has one address on `10.0.0.0/24` and one on `192.168.100.0/24`.
- Ping and SSH to the floating IP work from the provider LAN.

If the instance gets an IP but cannot reach the internet, check NAT inside the router namespace:

```bash
sudo ip netns exec qrouter-<uuid> iptables -t nat -S | grep -E 'SNAT|DNAT'
sudo ip netns exec qrouter-<uuid> sysctl net.ipv4.ip_forward
```

---

Next: [06 — Cinder](06-cinder.md)
