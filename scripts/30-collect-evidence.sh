#!/usr/bin/env bash
#
# Capture verification evidence into evidence/<timestamp>-<host>/.
#
# Run on controller01 for cloud-level state, then repeat on network01 and
# compute01 for the host-level data path:
#
#   source ~/admin-openrc
#   ./scripts/30-collect-evidence.sh
#
# No secrets are written: token output is hashed, not stored.
#
set -uo pipefail

HOST="$(hostname -s)"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="$REPO_ROOT/evidence/$STAMP-$HOST"
mkdir -p "$OUT"

run() {
    local name="$1"; shift
    {
        echo "\$ $*"
        echo
        "$@" 2>&1
    } >"$OUT/$name.txt"
    echo "captured $name"
}

echo "writing to $OUT"

if [[ -n "${OS_AUTH_URL:-}" ]]; then
    openstack token issue -f value -c id 2>/dev/null | sha256sum | awk '{print $1}' >"$OUT/token.sha256"

    run compute-service-list      openstack compute service list
    run network-agent-list        openstack network agent list
    run volume-service-list       openstack volume service list
    run server-list               openstack server list --all-projects
    run network-list              openstack network list
    run subnet-list               openstack subnet list
    run router-list               openstack router list
    run floating-ip-list          openstack floating ip list
    run volume-list               openstack volume list --all-projects
    run image-list                openstack image list
    run hypervisor-list           openstack hypervisor list
    run flavor-list               openstack flavor list

    if openstack network agent list -f value -c "Agent Type" | grep -q "Open vSwitch"; then
        run ovs-agent-list openstack network agent list --agent-type openvswitch
    fi
else
    echo "warning: OS_AUTH_URL unset, cloud commands skipped" | tee "$OUT/README.txt"
fi

echo "== host state =="
run hostname            hostname -f
run uptime              uptime
run ip-addresses        ip -br address
run ip-routes           ip route
run failed-units        systemctl --failed --no-pager
run ovs-vsctl-show      ovs-vsctl show
run ovs-bridges         ovs-vsctl list-br
run netns               ip netns

for unit in neutron-openvswitch-agent neutron-l3-agent neutron-dhcp-agent \
            neutron-metadata-agent nova-compute cinder-volume tgt; do
    if systemctl list-unit-files "$unit.service" >/dev/null 2>&1; then
        run "journal-$unit" journalctl -u "$unit" -n 200 --no-pager
    fi
done

if [[ -d /etc/swift && $(ls /etc/swift/*.ring.gz 2>/dev/null | wc -l) -gt 0 ]]; then
    run swift-rings bash -c 'for b in /etc/swift/*.builder; do echo "== $b =="; swift-ring-builder "$b" 2>&1; done'
fi

echo
echo "done: $OUT"
