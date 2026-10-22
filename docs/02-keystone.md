# 02 — Keystone, MariaDB, RabbitMQ, Memcached

**Goal:** a working Identity v3 API and the shared services every other component depends on.
All steps run on `controller01`.

---

## 1. MariaDB

Edit `/etc/mysql/mariadb.conf.d/99-openstack.cnf`:

```ini
[mysqld]
bind-address = 10.10.10.11
default-storage-engine = innodb
innodb_file_per_table = on
max_connections = 4096
collation-server = utf8mb4_general_ci
character-set-server = utf8mb4
```

```bash
sudo systemctl restart mariadb
sudo mysql_secure_installation
```

Keep MariaDB on the management network only. Every service connects over `10.10.10.0/24`.

Create the Keystone database:

```bash
sudo mysql <<'SQL'
CREATE DATABASE keystone;
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'localhost' IDENTIFIED BY 'KEYSTONE_DBPASS';
GRANT ALL PRIVILEGES ON keystone.* TO 'keystone'@'%' IDENTIFIED BY 'KEYSTONE_DBPASS';
SQL
```

## 2. RabbitMQ

```bash
sudo systemctl enable --now rabbitmq-server
sudo rabbitmqctl add_user openstack RABBIT_PASS
sudo rabbitmqctl set_permissions openstack ".*" ".*" ".*"
sudo rabbitmqctl list_users
```

The `openstack` user needs configure/write/read on the default vhost. Every `transport_url` in
this repo points at it:

```ini
transport_url = rabbit://openstack:RABBIT_PASS@controller01:5672/
```

## 3. Memcached

Edit `/etc/memcached.conf`:

```
-l 10.10.10.11
-m 512
```

```bash
sudo systemctl enable --now memcached
ss -lntp | grep 11211
```

Memcached stores Keystone tokens and service catalogs. It is not a cache you can lose data from,
but if it is unreachable every API call pays a token-validation penalty.

## 4. Keystone

```bash
sudo apt install -y keystone apache2 libapache2-mod-wsgi-py3
```

Install [`configs/controller/keystone.conf`](../configs/controller/keystone.conf) as
`/etc/keystone/keystone.conf`, replacing `KEYSTONE_DBPASS`.

```bash
sudo su -s /bin/sh -c "keystone-manage db_sync" keystone

sudo keystone-manage fernet_setup --keystone-user keystone --keystone-group keystone
sudo keystone-manage credential_setup --keystone-user keystone --keystone-group keystone

sudo keystone-manage bootstrap \
  --bootstrap-password ADMIN_PASS \
  --bootstrap-admin-url http://controller01:5000/v3/ \
  --bootstrap-internal-url http://controller01:5000/v3/ \
  --bootstrap-public-url http://controller01:5000/v3/ \
  --bootstrap-region-id RegionOne
```

Point Apache at the Keystone WSGI app (the package usually does this already):

```bash
grep -R "WSGIScriptAlias / /usr/bin/keystone-wsgi-public" /etc/apache2/sites-available/
sudo systemctl restart apache2
```

## 5. CLI credentials

Create `~/admin-openrc`:

```bash
export OS_PROJECT_DOMAIN_NAME=Default
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_NAME=admin
export OS_USERNAME=admin
export OS_PASSWORD=ADMIN_PASS
export OS_AUTH_URL=http://controller01:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_IMAGE_API_VERSION=2
export OS_REGION_NAME=RegionOne
```

```bash
source ~/admin-openrc
openstack token issue
openstack project list
openstack user list
```

## 6. Service project and roles

Every service user lives in the `service` project:

```bash
openstack project create --domain default --description "Service Project" service
openstack role create reader 2>/dev/null || true
openstack role list
```

The bootstrap already created the `admin` role and user. Later steps add `glance`, `placement`,
`nova`, `neutron`, `cinder` and `swift` users to this project.

## 7. Gate check

```bash
openstack token issue -f value -c id
```

A token ID means Identity v3, the database, Fernet keys and Apache are all working. If this fails,
fix it here — nothing downstream will work.

---

Next: [03 — Glance and Placement](03-glance-placement.md)
