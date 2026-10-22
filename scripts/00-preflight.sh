#!/usr/bin/env bash
#
# Preflight checks. Run on every node before building anything.
#
#   ./scripts/00-preflight.sh
#
set -euo pipefail

EXPECTED_HOST="${EXPECTED_HOST:-$(hostname -s)}"
HOSTS=(controller compute1 compute2 block object)
IPS=(192.168.100.24 192.168.100.25 192.168.100.26 192.168.100.27 192.168.100.28)
FAIL=0

pass() { printf '  [ok]   %s\n' "$*"; }
fail() { printf '  [FAIL] %s\n' "$*"; FAIL=1; }
warn() { printf '  [warn] %s\n' "$*"; }

echo "== identity =="
echo "  host: $EXPECTED_HOST"
echo "  kernel: $(uname -r)"
if . /etc/os-release && [[ "${VERSION_ID:-}" == "22.04" ]]; then
    pass "Ubuntu 22.04 LTS"
else
    fail "expected Ubuntu 22.04 LTS"
fi

echo "== name resolution =="
for h in "${HOSTS[@]}"; do
    if getent hosts "$h" >/dev/null; then
        pass "$h -> $(getent hosts "$h" | awk '{print $1}')"
    else
        fail "$h does not resolve (check /etc/hosts)"
    fi
done

echo "== management/provider reachability =="
for ip in "${IPS[@]}"; do
    if ping -c1 -W1 "$ip" >/dev/null 2>&1; then
        pass "$ip reachable"
    else
        warn "$ip did not answer ICMP (could be firewalled or stopped)"
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

echo "== role-specific checks =="
case "$EXPECTED_HOST" in
    controller)
        if command -v ovs-vsctl >/dev/null; then
            pass "openvswitch-switch installed"
            if ovs-vsctl br-exists br-ex; then
                pass "br-ex exists"
                if ip -4 -o addr show br-ex | grep -q '192.168.100.24/24'; then
                    pass "br-ex carries 192.168.100.24/24"
                else
                    fail "br-ex does not carry 192.168.100.24/24"
                fi
                ovs-vsctl list-ports br-ex | sed 's/^/         port: /'
            else
                fail "br-ex missing (apply netplan/controller.yaml)"
            fi
        else
            fail "openvswitch-switch missing"
        fi
        for svc in mariadb rabbitmq-server memcached; do
            if systemctl is-active --quiet "$svc"; then
                pass "$svc active"
            else
                warn "$svc is not active yet"
            fi
        done
        ;;
    compute1|compute2)
        if grep -Eq '(vmx|svm)' /proc/cpuinfo; then
            pass "hardware virtualisation exposed"
        else
            warn "no vmx/svm — set [libvirt] virt_type = qemu in nova.conf"
        fi
        if command -v ovs-vsctl >/dev/null; then
            pass "openvswitch-switch installed"
        else
            fail "openvswitch-switch missing"
        fi
        ;;
    block)
        if command -v vgs >/dev/null && vgs cinder-volumes >/dev/null 2>&1; then
            pass "LVM volume group cinder-volumes present"
        else
            fail "LVM volume group cinder-volumes missing"
        fi
        if systemctl is-active --quiet tgt; then
            pass "tgt active"
        else
            warn "tgt is not active yet"
        fi
        ;;
    object)
        for d in 1 2 3 4; do
            if [[ -d "/srv/node/$d" ]]; then
                pass "/srv/node/$d present"
            else
                fail "/srv/node/$d missing"
            fi
        done
        if command -v swift-ring-builder >/dev/null; then
            pass "swift-ring-builder present"
        else
            warn "swift packages not installed yet"
        fi
        ;;
    *)
        warn "unknown hostname '$EXPECTED_HOST'; skipping role checks"
        ;;
esac

if [[ "$EXPECTED_HOST" == "controller" && -f /etc/swift/object.ring.gz ]]; then
    echo "== Swift rings =="
    if swift-ring-builder /etc/swift/object.builder 2>/dev/null | grep -q '3.000000 replicas'; then
        pass "object ring reports 3 replicas"
    else
        warn "object ring not built or not 3 replicas"
    fi
fi

echo
if (( FAIL )); then
    echo "preflight failed — fix the items above before continuing"
    exit 1
fi

echo "preflight passed on $EXPECTED_HOST"
