# 08 — Horizon

**Goal:** the OpenStack dashboard on `controller`, using Keystone v3 and the cluster's
Memcached instance.

---

## 1. Install

On `controller`:

```bash
sudo apt install -y openstack-dashboard
```

## 2. Configuration

Copy [`configs/controller/local_settings.py`](../configs/controller/local_settings.py) to
`/etc/openstack-dashboard/local_settings.py`. The important values:

```python
OPENSTACK_HOST = "controller"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}

SESSION_ENGINE = "django.contrib.sessions.backends.cache"
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.memcached.PyMemcacheCache",
        "LOCATION": "controller:11211",
    },
}

TIME_ZONE = "Asia/Ulaanbaatar"

# The Ubuntu package default (True) tries to regenerate the compressed
# asset bundle on first request and fails on a minimal install.
COMPRESS_OFFLINE = False
```

If your dashboard version uses the older Memcached backend, replace
`PyMemcacheCache` with `MemcachedCache`.

## 3. Apache

```bash
sudo systemctl restart apache2
sudo systemctl status apache2 --no-pager
```

Open `http://192.168.100.24/` (or `http://controller/`) and log in with the admin credentials
from `admin-openrc`. The domain is `Default`.

## 4. Verify from the dashboard

- **Compute → Instances** shows `selfservice-demo0` as `Active`.
- **Compute → Images** shows `cirros`.
- **Network → Network Topology** shows `router`, `selfservice` and the instance.
- **Volumes → Volumes** shows the Cinder volume.
- **Object Store → Containers** shows the Swift container.

If the dashboard shows `OfflineGenerationError`, confirm `COMPRESS_OFFLINE = False` and restart
Apache. If login fails, check `OPENSTACK_KEYSTONE_URL` and the Memcached address.

## 5. Gate check

- The login page loads.
- Admin login succeeds.
- Instances, images, networks and volumes are visible.
- No traceback in `/var/log/apache2/error.log`.

---

Next: [09 — Verification](09-verification.md)
