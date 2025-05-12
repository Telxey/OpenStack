#! /bin/bash

echo 'Part 10: Additional Configuration'

# Configure network settings
juju config neutron-api flat-network-providers=physnet1
juju config neutron-gateway bridge-mappings="physnet1:br-ex"

# Configure Cinder tiers
juju config cinder storage-backend=lvm
juju config cinder volume-group="tier1-vg"
juju config cinder storage-pools="fast:tier1-vg,standard:tier2-vg,value:tier3-vg"

# Configure Ironic network
juju config ironic-conductor provisioning-network="10.0.0.0/24"
juju config ironic-conductor cleaning-network="10.0.0.0/24"

# Configure Kitti billing
juju config kitti rate-standard=0.05
juju config kitti rate-premium=0.10
juju config kitti billing-cycle="monthly"