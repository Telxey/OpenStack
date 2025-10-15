#!/bin/bash

echo 'Part 5: Deploy Additional Services'

# Deploy additional OpenStack services
juju deploy cs:skyline --config service-directory=/var/lib/dashboard/skyline
juju deploy cs:trove --config service-directory=/var/lib/database/trove
juju deploy cs:swift-proxy --config service-directory=/var/lib/storage/swift
juju deploy cs:swift-storage --config service-directory=/var/lib/backup/swift-objects
juju deploy cs:manila --config service-directory=/var/lib/storage/manila
juju deploy cs:zun --config service-directory=/var/lib/compute/zun
juju deploy cs:octavia --config service-directory=/var/lib/network/octavia
juju deploy cs:designate --config service-directory=/var/lib/network/designate
juju deploy cs:freezer --config backup-dir=/var/lib/backup/freezer
juju deploy cs:kitti --config service-directory=/var/lib/dashboard/kitti

# Deploy Ironic and its dependencies
juju deploy cs:ironic-api --config service-directory=/var/lib/compute/ironic/api
juju deploy cs:ironic-conductor --config service-directory=/var/lib/compute/ironic/conductor --config image-cache-dir=/var/lib/compute/ironic/image-cache
juju deploy cs:tftp --config tftp-root=/var/lib/compute/ironic/tftpboot
juju deploy cs:apache2 --config document-root=/var/lib/compute/ironic/httpboot

# Configure services
juju config ironic-conductor enabled-hardware-types=ipmi,redfish
juju config ironic-conductor enabled-deploy-interfaces=direct,iscsi
juju config cinder storage-tiers="fast:tier1-vg,standard:tier2-vg,value:tier3-vg"
juju config swift-storage storage-directory=/var/lib/backup/swift-objects
juju config freezer backup-schedule="0 2 * * *"

