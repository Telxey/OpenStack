#!/bin/bash

echo 'Part 2: Create Service-Specific Directories'
# Create service subdirectories within shared LVs

# Create service subdirectories within shared LVs
sudo mkdir -p /var/lib/database/{mysql,trove}
sudo mkdir -p /var/lib/compute/{nova,ironic,zun}
sudo mkdir -p /var/lib/compute/ironic/{api,conductor,tftpboot,httpboot,image-cache}
sudo mkdir -p /var/lib/network/{neutron,octavia,designate}
sudo mkdir -p /var/lib/dashboard/{horizon,skyline,kitti}
sudo mkdir -p /var/lib/storage/{glance,cinder,manila,swift}
sudo mkdir -p /var/lib/backup/{freezer,archive,swift-objects}

# Set correct permissions for MySQL
sudo chown -R 999:999 /var/lib/database/mysql # Default MySQL UID:GID
sudo chmod -R 750 /var/lib/database/mysql



