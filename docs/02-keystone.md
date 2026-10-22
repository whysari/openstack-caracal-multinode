# 02 — MariaDB, RabbitMQ, Memcached, Etcd and Keystone

**Goal:** shared backing services on the controller and a working Keystone v3 API.

All steps run on `controller` unless marked otherwise.

---

## 1. MariaDB

Edit `/etc/mysql/mariadb.conf.d/50-server.cnf`:

```ini
[mysqld]
bind-address = 192.168.100.24
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8_general_ci
character-set-server = utf8
```

```bash
sudo systemctl enable --now mariadb
sudo mysql_secure_installation
```

The original build used a single MariaDB instance, not Galera. Do not describe it as a cluster.

Create the databases and users:

```bash
sudo mysql <<'SQL'
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';
SQL
```

Repeat for `glance`, `placement`, `nova`, `nova_api`, `nova_cell0`, `neutron` and `cinder` with
the matching `*_DBPASS` placeholders. The service-specific docs create each database at the
point it is needed; doing them all here is fine.

## 2. RabbitMQ

```bash
sudo systemctl enable --now rabbitmq-server
sudo rabbitmqctl add_user openstack RABBIT_PASS
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
```

Verify:

```bash
sudo rabbitmqctl list_users
sudo rabbitmqctl status | head -20
```

## 3. Memcached

Edit `/etc/memcached.conf`:

```ini
-l 192.168.100.24
```

```bash
sudo systemctl enable --now memcached
ss -lntp | grep 11211
```

Memcached is used for Keystone token caching, the Horizon session store and the Swift proxy
cache.

## 4. Etcd (single node)

The Caracal service set installs Etcd on the controller. The original build did not wire it
into Cinder's active-active coordination; it is a single-node baseline.

Copy [`configs/controller/etcd.conf`](../configs/controller/etcd.conf) to `/etc/default/etcd`,
then:

```bash
sudo systemctl enable --now etcd
sudo etcdctl endpoint health
```

## 5. Keystone

Install:

```bash
sudo apt install -y keystone
```

Copy [`configs/controller/keystone.conf`](../configs/controller/keystone.conf) to
`/etc/keystone/keystone.conf`. The important values:

```ini
[database]
connection = mysql+pymysql://keystone:KEYSTONE_DBPASS@controller/keystone

[token]
provider = fernet

[memcache]
servers = controller:11211
```

Populate the database:

```bash
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone
```

Initialise Fernet keys and bootstrap the admin user:

```bash
sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

sudo keystone-manage bootstrap --bootstrap-password ADMIN_PASS \
  --bootstrap-admin-url http://controller:5000/v3/ \
  --bootstrap-internal-url http://controller:5000/v3/ \
  --bootstrap-public-url http://controller:5000/v3/ \
  --bootstrap-region-id RegionOne
```

Configure Apache:

```bash
sudo ln -sf /usr/share/keystone/wsgi-keystone.conf /etc/apache2/sites-enabled/
sudo systemctl enable --now apache2
```

Create `~/admin-openrc`:

```bash
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_AUTH_URL=http://controller:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
```

Verify:

```bash
source ~/admin-openrc
openstack token issue
openstack project list
openstack user list
```

## 6. Service project and roles

```bash
openstack project create --domain default --description "Service Project" service
openstack role create user
```

Every subsequent service (Glance, Placement, Nova, Neutron, Cinder, Swift) gets its own user in
the `service` project and the `admin` role.

## 7. Gate check

- `openstack token issue` returns a token.
- `openstack project list` shows `admin`, `service` and `demo`.
- MariaDB is listening on `192.168.100.24:3306`.
- RabbitMQ, Memcached and Etcd are active.

---

Next: [03 — Glance and Placement](03-glance-placement.md)
