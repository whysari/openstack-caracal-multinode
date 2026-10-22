#!/usr/bin/env bash
#
# Tear down the resources created by 10-create-networks.sh and
# 20-smoke-test.sh. Destructive — requires --yes.
#
#   source ~/admin-openrc
#   ./scripts/99-teardown.sh --yes
#
set -euo pipefail

if [[ "${1:-}" != "--yes" ]]; then
    echo "refusing to delete without --yes" >&2
    exit 1
fi

: "${OS_AUTH_URL:?source an admin openrc file first}"

SERVER="${SERVER:-smoke-01}"
VOLUME="${VOLUME:-smoke-vol}"
CONTAINER="${CONTAINER:-smoke-container}"

echo "== instance =="
if openstack server show "$SERVER" >/dev/null 2>&1; then
    for fip in $(openstack server show "$SERVER" -f json | python3 -c '
import json, sys
d = json.load(sys.stdin)
for addrs in d.get("addresses", {}).values():
    for a in addrs:
        if a.get("OS-EXT-IPS:type") == "floating":
            print(a["addr"])
'); do
        openstack server remove floating ip "$SERVER" "$fip" || true
        openstack floating ip delete "$fip" || true
    done
    openstack server delete --wait "$SERVER"
fi

echo "== volume =="
openstack volume delete "$VOLUME" 2>/dev/null || true

echo "== swift =="
openstack object delete "$CONTAINER" README.md 2>/dev/null || true
openstack container delete "$CONTAINER" 2>/dev/null || true

echo "== router and networks =="
openstack router remove subnet router01 private-subnet 2>/dev/null || true
openstack router unset --external-gateway router01 2>/dev/null || true
openstack router delete router01 2>/dev/null || true
openstack subnet delete private-subnet 2>/dev/null || true
openstack network delete private 2>/dev/null || true
openstack subnet delete provider-subnet 2>/dev/null || true
openstack network delete provider 2>/dev/null || true

echo "teardown complete"
