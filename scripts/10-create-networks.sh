#!/usr/bin/env bash
#
# Create the provider network, tenant network, router and baseline
# security group rules. Safe to re-run: existing objects are skipped.
#
#   source ~/admin-openrc
#   ./scripts/10-create-networks.sh
#
set -euo pipefail

: "${OS_AUTH_URL:?source an admin openrc file first}"

PROVIDER_CIDR="${PROVIDER_CIDR:-192.168.100.0/24}"
PROVIDER_GATEWAY="${PROVIDER_GATEWAY:-192.168.100.1}"
FIP_START="${FIP_START:-192.168.100.150}"
FIP_END="${FIP_END:-192.168.100.200}"
DNS="${DNS:-1.1.1.1}"
PRIVATE_CIDR="${PRIVATE_CIDR:-10.0.0.0/24}"

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

echo "== tenant network =="
if ! exists openstack network show private; then
    openstack network create private
fi

if ! exists openstack subnet show private-subnet; then
    openstack subnet create private-subnet \
        --network private \
        --subnet-range "$PRIVATE_CIDR" \
        --dns-nameserver "$DNS"
fi

echo "== router =="
if ! exists openstack router show router01; then
    openstack router create router01
fi

openstack router add subnet router01 private-subnet 2>/dev/null || true
openstack router set --external-gateway provider router01

echo "== default security group =="
openstack security group rule create --proto icmp default 2>/dev/null || true
openstack security group rule create --proto tcp --dst-port 22 default 2>/dev/null || true
openstack security group rule create --proto tcp --dst-port 80 default 2>/dev/null || true

echo
echo "networks ready:"
openstack network list
openstack router list
