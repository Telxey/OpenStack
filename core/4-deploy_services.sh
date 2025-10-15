#!/bin/bash
echo 'Part 4: Deploy Core OpenStack Services'
# Create a bundle configuration file
cat > openstack-bundle.yaml << 'EOF'
series: noble
applications:
  mysql:
    charm: mysql-innodb-cluster
    channel: latest/edge
    num_units: 3
    options:
      dataset-size: 50%
      data-directory: /var/lib/database/mysql
      innodb-buffer-pool-size: 4G
      max-connections: 1000
  vault:
    charm: vault
    channel: 1.17/stable
    num_units: 2
    options:
      data-directory: /var/lib/database/vault    
  rabbitmq-server:
    charm: rabbitmq-server
    channel: latest/stable
    num_units: 2
    options:
      data-directory: /var/lib/messaging
  keystone:
    charm: keystone
    channel: noble/stable
    num_units: 3
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/identity
  glance:
    charm: glance
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/storage/glance
  nova-cloud-controller:
    charm: nova-cloud-controller
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/compute/nova
  nova-compute:
    charm: nova-compute
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/compute/nova
  neutron-api:
    charm: neutron-api
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/network/neutron
  neutron-gateway:
    charm: neutron-gateway
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/network/neutron
  cinder:
    charm: cinder
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/storage/cinder
      block-device: "none"
      volume-group: "tier1-vg"
  horizon:
    charm: horizon
    channel: noble/stable
    num_units: 1
    options:
      openstack-origin: cloud:noble-numbat
      service-directory: /var/lib/dashboard/horizon
relations:
  - ["keystone:shared-db", "mysql-innodb-cluster:shared-db"]
  - ["nova-cloud-controller:shared-db", "mysql-innodb-cluster:shared-db"]
  - ["nova-cloud-controller:amqp", "rabbitmq-server:amqp"]
  - ["nova-cloud-controller:identity-service", "keystone:identity-service"]
  - ["nova-cloud-controller:cloud-compute", "nova-compute:cloud-compute"]
  - ["nova-compute:amqp", "rabbitmq-server:amqp"]
  - ["nova-compute:image-service", "glance:image-service"]
  - ["glance:shared-db", "mysql-innodb-cluster:shared-db"]
  - ["glance:identity-service", "keystone:identity-service"]
  - ["glance:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:shared-db", "mysql-innodb-cluster:shared-db"]
  - ["neutron-api:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:neutron-plugin-api", "neutron-gateway:neutron-plugin-api"]
  - ["neutron-api:identity-service", "keystone:identity-service"]
  - ["neutron-gateway:amqp", "rabbitmq-server:amqp"]
  - ["cinder:shared-db", "mysql-innodb-cluster:shared-db"]
  - ["cinder:identity-service", "keystone:identity-service"]
  - ["cinder:amqp", "rabbitmq-server:amqp"]
  - ["horizon:identity-service", "keystone:identity-service"]
EOF
# Deploy core OpenStack services
juju deploy ./openstack-bundle.yaml