#!/usr/bin/env bash
#
# Preflight checks. Run on every node before building anything.
#
#   ./scripts/00-preflight.sh
#
set -euo pipefail

EXPECTED_HOST="${EXPECTED_HOST:-$(hostname -s)}"
HOSTS=(controller01 compute01 compute02 network01 storage01)
MGMT_IPS=(10.10.10.11 10.10.10.21 10.10.10.22 10.10.10.31 10.10.10.41)
FAIL=0

pass() { printf '  [ok]   %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAIL=1; }
warn() { printf '  [warn] %s\n' "$*"; }

echo "== identity =="
echo "  host: $EXPECTED_HOST"
echo "  kernel: $(uname -r)"
pass "running Ubuntu $(. /etc/os-release && echo "$VERSION_ID")"

echo "== name resolution =="
for h in "${HOSTS[@]}"; do
    if getent hosts "$h" >/dev/null; then
        pass "$h -> $(getent hosts "$h" | awk '{print $1}')"
    else
        fail "$h does not resolve (check /etc/hosts)"
    fi
done

echo "== management reachability =="
for ip in "${MGMT_IPS[@]}"; do
    if ping -c1 -W1 "$ip" >/dev/null 2>&1; then
        pass "$ip reachable"
    else
        warn "$ip did not answer ICMP (could be firewalled)"
    fi
done

echo "== time sync =="
if timedatectl show -p NTPSynchronized --value 2>/dev/null | grep -q yes; then
    pass "NTP synchronised"
else
    fail "clock not synchronised — Keystone tokens and RabbitMQ will misbehave"
fi

echo "== OpenStack packages =="
if command -v openstack >/dev/null; then
    pass "openstack CLI present"
else
    fail "python3-openstackclient missing"
fi

echo "== virtualisation (compute nodes only) =="
if [[ "$EXPECTED_HOST" == compute* ]]; then
    if egrep -q '(vmx|svm)' /proc/cpuinfo; then
        pass "hardware virtualisation exposed"
    else
        warn "no vmx/svm — set [libvirt] virt_type = qemu in nova.conf"
    fi
fi

echo "== OVS (network/compute nodes) =="
if [[ "$EXPECTED_HOST" == network* || "$EXPECTED_HOST" == compute* ]]; then
    if command -v ovs-vsctl >/dev/null; then
        pass "openvswitch-switch installed"
        if [[ "$EXPECTED_HOST" == network* ]]; then
            if ovs-vsctl br-exists br-ex; then
                pass "br-ex exists"
                ovs-vsctl list-ports br-ex | sed 's/^/         port: /'
            else
                fail "br-ex missing (apply netplan or run configs/ovs/br-ex.sh)"
            fi
        fi
    else
        fail "openvswitch-switch missing"
    fi
fi

echo
if (( FAIL )); then
    echo "preflight failed — fix the items above before continuing"
    exit 1
fi

echo "preflight passed on $EXPECTED_HOST"
