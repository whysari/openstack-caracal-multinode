# 08 — Horizon

**Goal:** a working dashboard at `http://10.10.10.11/dashboard/`.

---

## 1. Install

```bash
sudo apt install -y openstack-dashboard
```

## 2. Configure

Install [`configs/controller/local_settings.py`](../configs/controller/local_settings.py) as
`/etc/openstack-dashboard/local_settings.py`. The values that matter:

```python
OPENSTACK_HOST = "controller01"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"
OPENSTACK_API_VERSIONS = {"identity": 3, "image": 2, "volume": 3}
```

`ALLOWED_HOSTS = ['*']` is fine behind a lab firewall; restrict it to the dashboard hostname in
anything reachable from untrusted networks.

## 3. Apply

```bash
sudo systemctl reload apache2
sudo systemctl status apache2 --no-pager
```

Ubuntu serves Horizon through the `openstack-dashboard` Apache site. If the site is disabled:

```bash
sudo a2ensite openstack-dashboard
sudo systemctl reload apache2
```

## 4. Verify

Open `http://10.10.10.11/dashboard/` and log in:

| Field | Value |
|---|---|
| Domain | `Default` |
| Username | `admin` |
| Password | the `ADMIN_PASS` from the Keystone bootstrap |

Then check:

- **Project → Compute → Instances** lists `cirros-01`.
- **Project → Network → Network Topology** shows `router01`, `private`, `provider`.
- **Project → Volumes → Volumes** lists `demo-vol`.
- **Project → Object Store → Containers** lists `demo-container`.
- **Admin → Hypervisors** shows `compute01` and `compute02`.

## 5. Gate check

The dashboard loads with static assets (no broken CSS), login succeeds, and the panels above show
the resources created in the previous phases. A login loop almost always means
`OPENSTACK_KEYSTONE_URL` is wrong or the `default` domain is missing.

---

Next: [09 — Verification](09-verification.md)
