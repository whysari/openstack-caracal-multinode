#!/usr/bin/env bash
#
# Imperative fallback for the OVS provider bridge on the controller.
#
# Prefer the declarative netplan file (configs/netplan/controller.yaml).
# Use this only when netplan's OVS integration is unavailable. The script
# moves the management/provider address from the physical NIC to br-ex, so it
# WILL interrupt an SSH session that runs over that NIC. Set ALLOW_LOCKOUT=1
# only when you have console access.
#
#   sudo ALLOW_LOCKOUT=1 PROVIDER_IF=enp1s0 ./configs/ovs/br-ex.sh
#
set -euo pipefail

PROVIDER_IF="${PROVIDER_IF:-enp1s0}"
BRIDGE="${BRIDGE:-br-ex}"
HOST_IP="${HOST_IP:-192.168.100.24}"
PREFIX="${PREFIX:-24}"
GATEWAY="${GATEWAY:-192.168.100.1}"

if ! ip link show "$PROVIDER_IF" >/dev/null 2>&1; then
    echo "error: interface $PROVIDER_IF does not exist (set PROVIDER_IF=...)" >&2
    exit 1
fi

if ip route show default | grep -q "dev $PROVIDER_IF" && [[ "${ALLOW_LOCKOUT:-0}" != "1" ]]; then
    echo "error: $PROVIDER_IF carries the default route; this would cut your SSH session" >&2
    echo "       re-run with ALLOW_LOCKOUT=1 from a console, or use netplan" >&2
    exit 1
fi

if ! command -v ovs-vsctl >/dev/null; then
    echo "error: openvswitch-switch is not installed" >&2
    exit 1
fi

if ! ovs-vsctl br-exists "$BRIDGE"; then
    ovs-vsctl add-br "$BRIDGE"
    echo "created bridge $BRIDGE"
fi

ovs-vsctl --may-exist add-port "$BRIDGE" "$PROVIDER_IF"
ip addr flush dev "$PROVIDER_IF"
ip addr add "${HOST_IP}/${PREFIX}" dev "$BRIDGE"
ip link set "$BRIDGE" up
ip link set "$PROVIDER_IF" up
ip route replace default via "$GATEWAY" dev "$BRIDGE"

echo "ok: $PROVIDER_IF enslaved to $BRIDGE; ${HOST_IP}/${PREFIX} moved to $BRIDGE"
ip -br address show "$BRIDGE"
ovs-vsctl show | sed -n "/$BRIDGE/,/^$/p"
