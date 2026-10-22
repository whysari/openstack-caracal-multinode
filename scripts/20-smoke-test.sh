#!/usr/bin/env bash
#
# End-to-end smoke test: token, services, network, instance, floating IP,
# volume attach and Swift round-trip. Run from the controller with an admin
# RC file sourced.
#
#   source ~/admin-openrc
#   ./scripts/20-smoke-test.sh
#
# Exit code 0 means every executed check passed. Checks that need a host on
# the provider LAN report SKIP instead of failing.
#
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
: "${OS_AUTH_URL:?source an admin openrc file first}"

IMAGE="${IMAGE:-cirros}"
FLAVOR="${FLAVOR:-m1.nano}"
NETWORK="${NETWORK:-selfservice}"
KEY_NAME="${KEY_NAME:-smoke}"
SERVER="${SERVER:-smoke-01}"
VOLUME="${VOLUME:-smoke-vol}"
CONTAINER="${CONTAINER:-smoke-container}"
OBJECT="${OBJECT:-README.md}"
SSH_KEY="${SSH_KEY:-/tmp/openstack-smoke-key}"
CIRROS_URL="${CIRROS_URL:-https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img}"

PASS=0
FAIL=0
SKIP=0

ok()   { printf '  \033[32mPASS\033[0m  %s\n' "$*"; PASS=$((PASS + 1)); }
bad()  { printf '  \033[31mFAIL\033[0m  %s\n' "$*"; FAIL=$((FAIL + 1)); }
skip() { printf '  \033[33mSKIP\033[0m  %s\n' "$*"; SKIP=$((SKIP + 1)); }

json_get() { python3 -c "$1"; }

echo "== 1. identity =="
if openstack token issue -f value -c id >/dev/null 2>&1; then
    ok "Keystone issues a token"
else
    bad "Keystone token request failed"
    exit 1
fi

echo "== 2. control plane =="
NOVA_UP=$(openstack compute service list -f value -c State | grep -c '^up$' || true)
if (( NOVA_UP >= 3 )); then
    ok "Nova services up: $NOVA_UP (conductor, scheduler, at least one compute)"
else
    bad "Nova services up: $NOVA_UP (expected >= 3)"
fi

AGENTS_DOWN=$(openstack network agent list -f value -c Alive | grep -ci 'false' || true)
if (( AGENTS_DOWN == 0 )); then
    ok "all Neutron agents alive"
else
    bad "$AGENTS_DOWN Neutron agent(s) down (start compute2's OVS agent if needed)"
fi

if openstack volume service list -f value -c Binary -c State | grep -q '^cinder-volume.*up$'; then
    ok "cinder-volume up"
else
    bad "cinder-volume not up (check the block node)"
fi

echo "== 3. networks =="
"$REPO_ROOT/scripts/10-create-networks.sh" >/dev/null
ok "provider + selfservice networks and router present"

echo "== 4. image and flavor =="
if openstack image show "$IMAGE" >/dev/null 2>&1; then
    ok "image $IMAGE present"
else
    TMP_IMG="$(mktemp -t cirros.XXXXXX.img)"
    if curl -fsSL "$CIRROS_URL" -o "$TMP_IMG"; then
        openstack image create "$IMAGE" \
            --disk-format qcow2 --container-format bare \
            --file "$TMP_IMG" >/dev/null
        ok "image $IMAGE uploaded"
    else
        bad "image $IMAGE missing and download failed"
        rm -f "$TMP_IMG"
        exit 1
    fi
    rm -f "$TMP_IMG"
fi

if openstack flavor show "$FLAVOR" >/dev/null 2>&1; then
    ok "flavor $FLAVOR present"
else
    openstack flavor create --vcpus 1 --ram 128 --disk 1 "$FLAVOR" >/dev/null
    ok "flavor $FLAVOR created"
fi

echo "== 5. keypair =="
if ! openstack keypair show "$KEY_NAME" >/dev/null 2>&1; then
    [[ -f "$SSH_KEY" ]] || ssh-keygen -t ed25519 -N '' -f "$SSH_KEY" -q
    openstack keypair create --public-key "$SSH_KEY.pub" "$KEY_NAME" >/dev/null
    ok "keypair $KEY_NAME created"
else
    ok "keypair $KEY_NAME present"
fi

echo "== 6. instance =="
if ! openstack server show "$SERVER" >/dev/null 2>&1; then
    openstack server create \
        --image "$IMAGE" --flavor "$FLAVOR" --network "$NETWORK" \
        --security-group default --key-name "$KEY_NAME" \
        --wait "$SERVER" >/dev/null
    ok "instance $SERVER created and ACTIVE"
else
    ok "instance $SERVER already exists"
fi

STATUS=$(openstack server show "$SERVER" -f value -c status)
[[ "$STATUS" == ACTIVE ]] && ok "instance state ACTIVE" || bad "instance state $STATUS"

FIXED_IP=$(openstack server show "$SERVER" -f json | json_get '
import json, sys
d = json.load(sys.stdin)
for addrs in d.get("addresses", {}).values():
    for a in addrs:
        if a.get("version") == 4 and a.get("OS-EXT-IPS:type") == "fixed":
            print(a["addr"])
            raise SystemExit(0)
raise SystemExit(1)
')
[[ -n "$FIXED_IP" ]] && ok "fixed IP $FIXED_IP assigned" || bad "no fixed IPv4 address"

echo "== 7. floating IP =="
FIP=$(openstack floating ip list -f json | json_get '
import json, sys
for f in json.load(sys.stdin):
    if not f.get("Fixed IP Address"):
        print(f["Floating IP Address"])
        break
')
if [[ -z "$FIP" ]]; then
    FIP=$(openstack floating ip create provider -f value -c floating_ip_address)
    ok "floating IP $FIP allocated"
else
    ok "reused unassociated floating IP $FIP"
fi

if openstack server show "$SERVER" -f json | grep -q "$FIP"; then
    ok "floating IP already associated"
else
    openstack server add floating ip "$SERVER" "$FIP"
    ok "floating IP $FIP associated with $SERVER"
fi

# The controller sits on 192.168.100.0/24, so this test runs without an
# external jump host. If the gateway is unreachable, the script is running
# off the provider LAN and the FIP checks are skipped.
if ping -c1 -W1 192.168.100.1 >/dev/null 2>&1; then
    if ping -c3 -W2 "$FIP" >/dev/null 2>&1; then
        ok "floating IP answers ICMP from the controller"
    else
        bad "floating IP $FIP does not answer ICMP"
    fi

    if [[ ! -f "${SSH_KEY}" ]]; then
        skip "private key ${SSH_KEY} missing; cannot test SSH/metadata"
    elif ssh -i "${SSH_KEY}" -o BatchMode=yes -o StrictHostKeyChecking=no \
           -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
           "cirros@$FIP" true >/dev/null 2>&1; then
        ok "SSH to instance works"
        META=$(ssh -i "${SSH_KEY}" -o BatchMode=yes -o StrictHostKeyChecking=no \
                   -o UserKnownHostsFile=/dev/null -o ConnectTimeout=5 \
                   "cirros@$FIP" \
                   'wget -qO- --timeout=3 http://169.254.169.254/latest/meta-data/instance-id' || true)
        [[ -n "$META" ]] && ok "metadata service reachable ($META)" || bad "metadata service returned nothing"
    else
        bad "SSH to $FIP failed"
    fi
else
    skip "controller is not on the provider LAN; run ping/ssh checks from 192.168.100.0/24"
fi

echo "== 8. volume =="
if ! openstack volume show "$VOLUME" >/dev/null 2>&1; then
    openstack volume create --size 1 "$VOLUME" >/dev/null
fi

VSTATUS=""
for _ in $(seq 1 30); do
    VSTATUS=$(openstack volume show "$VOLUME" -f value -c status)
    [[ "$VSTATUS" == available || "$VSTATUS" == in-use ]] && break
    sleep 2
done

if [[ "$VSTATUS" == available ]]; then
    openstack server add volume "$SERVER" "$VOLUME" >/dev/null
    ok "volume $VOLUME created and attached"
elif [[ "$VSTATUS" == in-use ]]; then
    ok "volume $VOLUME already attached"
else
    bad "volume $VOLUME state $VSTATUS"
fi

for _ in $(seq 1 30); do
    VSTATUS=$(openstack volume show "$VOLUME" -f value -c status)
    [[ "$VSTATUS" == in-use ]] && break
    sleep 2
done
[[ "$VSTATUS" == in-use ]] && ok "volume state in-use" || bad "volume state $VSTATUS"

echo "== 9. Swift =="
openstack container create "$CONTAINER" >/dev/null 2>&1 || true
if openstack object create "$CONTAINER" "$REPO_ROOT/$OBJECT" >/dev/null 2>&1; then
    ok "object uploaded to $CONTAINER"
else
    bad "object upload failed"
fi

TMP_OBJECT=$(mktemp)
if openstack object save "$CONTAINER" "$OBJECT" --file "$TMP_OBJECT" >/dev/null 2>&1; then
    if cmp -s "$REPO_ROOT/$OBJECT" "$TMP_OBJECT"; then
        ok "downloaded object matches uploaded file"
    else
        bad "downloaded object differs from source"
    fi
else
    bad "object download failed"
fi
rm -f "$TMP_OBJECT"

if command -v swift-ring-builder >/dev/null && [[ -f /etc/swift/object.builder ]]; then
    RING=$(swift-ring-builder /etc/swift/object.builder 2>&1 || true)
    if grep -q '10 partitions' <<<"$RING" && grep -q '3.000000 replicas' <<<"$RING" \
       && grep -q '4 devices' <<<"$RING"; then
        ok "object ring: 10 partitions / 3 replicas / 4 devices"
    else
        bad "object ring does not match 10 partitions / 3 replicas / 4 devices"
    fi
else
    skip "swift-ring-builder or /etc/swift/object.builder not present"
fi

echo
echo "----------------------------------------"
printf 'passed: %d   failed: %d   skipped: %d\n' "$PASS" "$FAIL" "$SKIP"
echo "----------------------------------------"
echo "note: compute2's services may be stopped from the original demo;"
echo "      start them with docs/11-completing-the-build.md before re-running."

(( FAIL == 0 ))
