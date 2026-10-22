# 03 — Glance and Placement

**Goal:** image storage and the resource inventory that Nova's scheduler reads.
All steps run on `controller01`.

---

## 1. Databases

```bash
sudo mysql <<'SQL'
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';

CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';
SQL
```

## 2. Service credentials and endpoints

```bash
source ~/admin-openrc

# Glance
openstack user create --domain default --password GLANCE_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
for iface in public internal; do
  openstack endpoint create --region RegionOne image "$iface" http://controller01:9292
done
openstack endpoint create --region RegionOne image admin http://controller01:9292

# Placement
openstack user create --domain default --password PLACEMENT_PASS placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
for iface in public internal; do
  openstack endpoint create --region RegionOne placement "$iface" http://controller01:8778
done
openstack endpoint create --region RegionOne placement admin http://controller01:8778
```

## 3. Glance

```bash
sudo apt install -y glance
```

Install [`configs/controller/glance-api.conf`](../configs/controller/glance-api.conf) as
`/etc/glance/glance-api.conf`, replacing `GLANCE_DBPASS` and `GLANCE_PASS`.

```bash
sudo su -s /bin/sh -c "glance-manage db_sync" glance
sudo systemctl enable --now glance-api
```

The file backend writes to `/var/lib/glance/images/`; make sure it is on a filesystem with room
for your images.

## 4. Placement

```bash
sudo apt install -y placement-api
```

Install [`configs/controller/placement.conf`](../configs/controller/placement.conf) as
`/etc/placement/placement.conf`.

```bash
sudo su -s /bin/sh -c "placement-manage db sync" placement
sudo systemctl restart apache2        # Ubuntu ships Placement as a WSGI app
sudo systemctl status placement-api --no-pager 2>/dev/null || true
```

## 5. Verify

```bash
source ~/admin-openrc

openstack image list                 # empty, but HTTP 200
openstack resource provider list     # empty until computes register
openstack endpoint list --service image
openstack endpoint list --service placement
```

Upload a test image (CirrOS is ~20 MB):

```bash
curl -LO https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img

openstack image create cirros \
  --file cirros-0.6.2-x86_64-disk.img \
  --disk-format qcow2 \
  --container-format bare \
  --public

openstack image list
openstack image show cirros -c status -c size
```

Expected: `status: active`, size ~21 MB. If Glance returns 500, check
`journalctl -u glance-api` — the usual causes are the DB URL or a missing `[glance_store]` section.

## 6. Gate check

```bash
openstack image list
openstack resource provider list
```

Image `cirros` is `active`. Placement responds (an empty provider list is correct until the
computes check in).

---

Next: [04 — Nova](04-nova.md)
