#!/usr/bin/env bash
#
# Create the flat provider network, the self-service VXLAN network, the
# router and baseline security-group rules. Safe to re-run: existing objects
# are skipped.
#
#   source ~/admin-openrc
#   ./scripts/10-create-networks.sh
#
set -euo pipefail

: "${OS_AUTH_URL:?source an admin openrc file first}"

PROVIDER_CIDR="${PROVIDER_CIDR:-192.168.100.0/24}"
PROVIDER_GATEWAY="${PROVIDER_GATEWAY:-192.168.100.1}"
FIP_START="${FIP_START:-192.168.100.101}"
FIP_END="${FIP_END:-192.168.100.250}"
DNS="${DNS:-1.1.1.1}"
PRIVATE_CIDR="${PRIVATE_CIDR:-172.16.1.0/24}"
PRIVATE_NET="${PRIVATE_NET:-selfservice}"
PRIVATE_SUBNET="${PRIVATE_SUBNET:-selfservice-subnet}"
ROUTER="${ROUTER:-router}"

exists() { "$@" >/dev/null 2>&1; }

echo "== provider (external) network =="
if ! exists openstack network show provider; then
    openstack network create --external \
        --provider-physical-network provider \
        --provider-network-type flat \
        provider
fi

if ! exists openstack subnet show provider-subnet; then
    openstack subnet create provider-subnet \
        --network provider \
        --subnet-range "$PROVIDER_CIDR" \
        --gateway "$PROVIDER_GATEWAY" \
        --allocation-pool "start=$FIP_START,end=$FIP_END" \
        --dns-nameserver "$DNS" \
        --no-dhcp
fi

echo "== self-service network =="
if ! exists openstack network show "$PRIVATE_NET"; then
    openstack network create "$PRIVATE_NET"
fi

if ! exists openstack subnet show "$PRIVATE_SUBNET"; then
    openstack subnet create "$PRIVATE_SUBNET" \
        --network "$PRIVATE_NET" \
        --subnet-range "$PRIVATE_CIDR" \
        --gateway 172.16.1.1 \
        --dns-nameserver "$DNS"
fi

echo "== router =="
if ! exists openstack router show "$ROUTER"; then
    openstack router create "$ROUTER"
fi

openstack router add subnet "$ROUTER" "$PRIVATE_SUBNET" 2>/dev/null || true
openstack router set --external-gateway provider "$ROUTER"

echo "== default security group =="
openstack security group rule create --proto icmp default 2>/dev/null || true
openstack security group rule create --proto tcp --dst-port 22 default 2>/dev/null || true
openstack security group rule create --proto tcp --dst-port 80 default 2>/dev/null || true

echo
echo "networks ready:"
openstack network list
openstack router list
