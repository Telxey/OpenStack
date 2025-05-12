#!/bin/bash

echo 'Part 4: Deploy Core OpenStack Services'

# Create a bundle configuration file
cat > openstack-bundle.yaml << 'EOF'
series: noble
applications:
  mysql:
    charm: cs:mysql
    num_units: 1
    options:
      dataset-size: 50%
      data-directory: /var/lib/database/mysql
      innodb-buffer-pool-size: 4G
      max-connections: 1000
  rabbitmq-server:
    charm: cs:rabbitmq-server
    num_units: 1
    options:
      data-directory: /var/lib/messaging
  keystone:
    charm: cs:keystone
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/identity
  glance:
    charm: cs:glance
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/storage/glance
  nova-cloud-controller:
    charm: cs:nova-cloud-controller
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/compute/nova
  nova-compute:
    charm: cs:nova-compute
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/compute/nova
  neutron-api:
    charm: cs:neutron-api
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/network/neutron
  neutron-gateway:
    charm: cs:neutron-gateway
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/network/neutron
  cinder:
    charm: cs:cinder
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/storage/cinder
      block-device: "none"
      volume-group: "tier1-vg"
  horizon:
    charm: cs:horizon
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/dashboard/horizon
relations:
  - ["keystone:shared-db", "mysql:shared-db"]
  - ["nova-cloud-controller:shared-db", "mysql:shared-db"]
  - ["nova-cloud-controller:amqp", "rabbitmq-server:amqp"]
  - ["nova-cloud-controller:identity-service", "keystone:identity-service"]
  - ["nova-cloud-controller:cloud-compute", "nova-compute:cloud-compute"]
  - ["nova-compute:amqp", "rabbitmq-server:amqp"]
  - ["nova-compute:image-service", "glance:image-service"]
  - ["glance:shared-db", "mysql:shared-db"]
  - ["glance:identity-service", "keystone:identity-service"]
  - ["glance:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:shared-db", "mysql:shared-db"]
  - ["neutron-api:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:neutron-plugin-api", "neutron-gateway:neutron-plugin-api"]
  - ["neutron-api:identity-service", "keystone:identity-service"]
  - ["neutron-gateway:amqp", "rabbitmq-server:amqp"]
  - ["cinder:shared-db", "mysql:shared-db"]
  - ["cinder:identity-service", "keystone:identity-service"]
  - ["cinder:amqp", "rabbitmq-server:amqp"]
  - ["horizon:identity-service", "keystone:identity-service"]
EOF

# Deploy core OpenStack services
juju deploy ./openstack-bundle.yaml


