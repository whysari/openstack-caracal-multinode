# 03 — Glance and Placement

**Goal:** an image catalog and a resource-placement API, both registered in Keystone.

Run on `controller`.

---

## 1. Glance database and credentials

```bash
sudo mysql <<'SQL'
CREATE DATABASE glance;
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'localhost' IDENTIFIED BY 'GLANCE_DBPASS';
GRANT ALL PRIVILEGES ON glance.* TO 'glance'@'%' IDENTIFIED BY 'GLANCE_DBPASS';
SQL

source ~/admin-openrc
openstack user create --domain default --password GLANCE_PASS glance
openstack role add --project service --user glance admin
openstack service create --name glance --description "OpenStack Image" image
openstack endpoint create --region RegionOne image public   http://controller:9292
openstack endpoint create --region RegionOne image internal http://controller:9292
openstack endpoint create --region RegionOne image admin    http://controller:9292
```

## 2. Glance API

```bash
sudo apt install -y glance
```

Copy [`configs/controller/glance-api.conf`](../configs/controller/glance-api.conf) to
`/etc/glance/glance-api.conf`. Key values:

```ini
[DEFAULT]
bind_host = 192.168.100.24

[database]
connection = mysql+pymysql://glance:GLANCE_DBPASS@controller/glance

[glance_store]
stores = file,http
default_store = file
filesystem_store_datadir = /var/lib/glance/images

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
project_domain_name = Default
user_domain_name = Default
project_name = service
username = glance
password = GLANCE_PASS
```

```bash
sudo su -s /bin/sh -c "glance-manage db_sync" glance
sudo systemctl enable --now glance-api
```

Verify and upload CirrOS:

```bash
source ~/admin-openrc
openstack image list

curl -fsSL -o /tmp/cirros.img \
  https://download.cirros-cloud.net/0.6.2/cirros-0.6.2-x86_64-disk.img

openstack image create cirros \
  --disk-format qcow2 --container-format bare \
  --file /tmp/cirros.img
openstack image list          # cirros should be active
```

## 3. Placement database and credentials

```bash
sudo mysql <<'SQL'
CREATE DATABASE placement;
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'localhost' IDENTIFIED BY 'PLACEMENT_DBPASS';
GRANT ALL PRIVILEGES ON placement.* TO 'placement'@'%' IDENTIFIED BY 'PLACEMENT_DBPASS';
SQL

source ~/admin-openrc
openstack user create --domain default --password PLACEMENT_PASS placement
openstack role add --project service --user placement admin
openstack service create --name placement --description "Placement API" placement
openstack endpoint create --region RegionOne placement public   http://controller:8778
openstack endpoint create --region RegionOne placement internal http://controller:8778
openstack endpoint create --region RegionOne placement admin    http://controller:8778
```

## 4. Placement API

```bash
sudo apt install -y placement-api
```

Copy [`configs/controller/placement.conf`](../configs/controller/placement.conf) to
`/etc/placement/placement.conf`:

```ini
[placement_database]
connection = mysql+pymysql://placement:PLACEMENT_DBPASS@controller/placement

[api]
auth_strategy = keystone

[keystone_authtoken]
www_authenticate_uri = http://controller:5000
auth_url = http://controller:5000
project_domain_name = Default
user_domain_name = Default
project_name = service
username = placement
password = PLACEMENT_PASS
```

```bash
sudo su -s /bin/sh -c "placement-manage db sync" placement
sudo systemctl restart apache2
```

Verify:

```bash
source ~/admin-openrc
placement-status upgrade check
curl -i http://controller:8778/
```

The root endpoint may return `404`; that is normal. The upgrade check and the authenticated
`openstack resource provider list` are the meaningful tests:

```bash
openstack resource provider list
```

## 5. Gate check

- `openstack image list` shows `cirros` as `active`.
- `placement-status upgrade check` reports no errors.
- `openstack resource provider list` returns an empty list (before computes register) or the
  compute providers after Nova is configured.

---

Next: [04 — Nova](04-nova.md)
