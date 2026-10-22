#!/usr/bin/env bash
#
# Bootstrap / recover the OVS provider bridge on network01.
#
# Use this only if you are NOT letting netplan own br-ex (see
# configs/netplan/network01.yaml). Running both paths can fight over the
# bridge. The script refuses to enslave the interface carrying the default
# route, which is the usual way to lock yourself out of a remote box.
#
set -euo pipefail

PROVIDER_IF="${PROVIDER_IF:-enp2s0}"
BRIDGE="${BRIDGE:-br-ex}"

if ! ip link show "$PROVIDER_IF" >/dev/null 2>&1; then
    echo "error: interface $PROVIDER_IF does not exist (set PROVIDER_IF=...)" >&2
    exit 1
fi

if ip route show default | grep -q "dev $PROVIDER_IF"; then
    echo "error: $PROVIDER_IF carries the default route; refusing to enslave it" >&2
    echo "       move management to another NIC or override PROVIDER_IF" >&2
    exit 1
fi

if ! ovs-vsctl br-exists "$BRIDGE"; then
    ovs-vsctl add-br "$BRIDGE"
    echo "created bridge $BRIDGE"
fi

ovs-vsctl --may-exist add-port "$BRIDGE" "$PROVIDER_IF"
ip link set "$BRIDGE" up
ip link set "$PROVIDER_IF" up

echo "ok: $PROVIDER_IF enslaved to $BRIDGE"
ovs-vsctl show | sed -n "/$BRIDGE/,/^$/p"
