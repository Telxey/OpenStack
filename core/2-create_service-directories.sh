#!/bin/bash

echo 'Part 2: Create Service-Specific Directories'
# Create service subdirectories within shared LVs

# Create service subdirectories within shared LVs
sudo mkdir -p /var/lib/database/{mysql,trove,barbican,vault}
sudo mkdir -p /var/lib/compute/{nova,ironic,zun,magnum}
sudo mkdir -p /var/lib/compute/ironic/{api,conductor,tftpboot,httpboot,image-cache}
sudo mkdir -p /var/lib/network/{neutron,octavia,designate,kuryr}
sudo mkdir -p /var/lib/dashboard/{horizon,skyline,heat,kitty}
sudo mkdir -p /var/lib/storage/{glance,cinder,manila,swift}
sudo mkdir -p /var/lib/monitoring/{ceilometer,gnocchi,aodh,placement}
sudo mkdir -p /var/lib/backup/{freezer,archive,swift-objects}

# Set correct permissions for MySQL
sudo chown -R 999:999 /var/lib/database/mysql # Default MySQL UID:GID
sudo chmod -R 750 /var/lib/database/mysql



