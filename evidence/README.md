# Evidence

Verification output captured with [`scripts/30-collect-evidence.sh`](../scripts/30-collect-evidence.sh).
Each run creates `YYYYMMDDTHHMMSSZ-<hostname>/` containing plain-text command output:

| File | What it proves |
|---|---|
| `token.sha256` | Keystone issued a token (hash only, no credential) |
| `compute-service-list.txt` | Nova services enabled and up |
| `network-agent-list.txt` | Every Neutron agent alive |
| `volume-service-list.txt` | Cinder scheduler + volume up |
| `server-list.txt`, `network-list.txt`, `router-list.txt` | Tenant resources exist |
| `ovs-vsctl-show.txt`, `ovs-bridges.txt` | Bridge/tunnel topology on that host |
| `netns.txt` | Router/DHCP namespaces on the network node |
| `ip-routes.txt`, `ip-addresses.txt` | Host networking |
| `swift-rings.txt` | Ring layout: zones, devices, replicas |
| `journal-*.txt` | Last 200 lines of each service log |

Commit the directory for the run referenced in the README. Do not commit `admin-openrc`,
passwords, private keys, or the full token (the script stores only a SHA-256 of it).
