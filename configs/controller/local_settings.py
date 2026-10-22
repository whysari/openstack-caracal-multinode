# /etc/openstack-dashboard/local_settings.py — controller01
# Only the values that differ from the Ubuntu package defaults are shown.

import os

DEBUG = False
ALLOWED_HOSTS = ['*']

OPENSTACK_HOST = "controller01"
OPENSTACK_KEYSTONE_URL = "http://%s:5000/v3" % OPENSTACK_HOST
OPENSTACK_KEYSTONE_DEFAULT_ROLE = "user"
OPENSTACK_KEYSTONE_MULTIDOMAIN_SUPPORT = True
OPENSTACK_KEYSTONE_DEFAULT_DOMAIN = "Default"

OPENSTACK_API_VERSIONS = {
    "identity": 3,
    "image": 2,
    "volume": 3,
}

# Flat provider network is the only external network.
OPENSTACK_NEUTRON_NETWORK = {
    "enable_router": True,
    "enable_quotas": True,
    "enable_ipv6": False,
    "enable_distributed_router": False,
    "enable_ha_router": False,
    "enable_fip_topology_check": True,
}

TIME_ZONE = "Asia/Ulaanbaatar"
SESSION_ENGINE = "django.contrib.sessions.backends.cache"
CACHES = {
    "default": {
        "BACKEND": "django.core.cache.backends.memcached.PyMemcacheCache",
        "LOCATION": "controller01:11211",
    },
}
