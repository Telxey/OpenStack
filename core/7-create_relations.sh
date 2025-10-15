#!/bin/bash

echo 'Part 7: Create All Necessary Relations'

# Relations for additional dashboards
juju add-relation skyline:identity-service keystone:identity-service
juju add-relation kitti:identity-service keystone:identity-service
juju add-relation kitti:shared-db mysql:shared-db

# Relations for Trove (Database as a Service)
juju add-relation trove:shared-db mysql:shared-db
juju add-relation trove:amqp rabbitmq-server:amqp
juju add-relation trove:identity-service keystone:identity-service

# Relations for Swift (Object Storage)
juju add-relation swift-proxy:shared-db mysql:shared-db
juju add-relation swift-proxy:identity-service keystone:identity-service
juju add-relation swift-proxy:swift-storage swift-storage:swift-storage

# Relations for Manila (Shared File System)
juju add-relation manila:shared-db mysql:shared-db
juju add-relation manila:amqp rabbitmq-server:amqp
juju add-relation manila:identity-service keystone:identity-service

# Relations for Zun (Containers Service)
juju add-relation zun:shared-db mysql:shared-db
juju add-relation zun:amqp rabbitmq-server:amqp
juju add-relation zun:identity-service keystone:identity-service
juju add-relation zun:compute-api nova-cloud-controller:cloud-compute-api

# Relations for Octavia (Load Balancer)
juju add-relation octavia:shared-db mysql:shared-db
juju add-relation octavia:amqp rabbitmq-server:amqp
juju add-relation octavia:identity-service keystone:identity-service
juju add-relation octavia:neutron-api neutron-api:neutron-api

# Relations for Designate (DNS)
juju add-relation designate:shared-db mysql:shared-db
juju add-relation designate:amqp rabbitmq-server:amqp
juju add-relation designate:identity-service keystone:identity-service

# Relations for Freezer (Backup)
juju add-relation freezer:shared-db mysql:shared-db
juju add-relation freezer:identity-service keystone:identity-service

# Relations for Ironic (Bare Metal)
juju add-relation ironic-api:shared-db mysql:shared-db
juju add-relation ironic-api:amqp rabbitmq-server:amqp
juju add-relation ironic-api:identity-service keystone:identity-service
juju add-relation ironic-conductor:shared-db mysql:shared-db
juju add-relation ironic-conductor:amqp rabbitmq-server:amqp
juju add-relation ironic-conductor:identity-service keystone:identity-service
juju add-relation ironic-conductor:image-service glance:image-service
juju add-relation ironic-api:api-service ironic-conductor:api-service
juju add-relation ironic-conductor:tftp-service tftp:tftp-service
juju add-relation ironic-conductor:http-service apache2:website
juju add-relation ironic-api:neutron-api neutron-api:neutron-api
juju add-relation ironic-conductor:neutron-api neutron-api:neutron-api
juju add-relation nova-compute:ironic-api ironic-api:compute-service



