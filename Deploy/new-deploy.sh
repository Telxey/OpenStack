#! /bin/env bash

# Deploy juju

# Add MAAS cloud
juju add-cloud maas-cloud --controller=manual-controller

# Add MAAS credentials
juju add-credential maas-cloud --controller=manual-controller

# Create a model for OpenStack
juju add-model openstack maas-cloud --controller=manual-controller

## ---- Storage Configuration --#
# echo 'Now let's proceed with your storage configuration:'

# Set up OpenStack control plane on Crucial P1 NVMe
sudo pvcreate /dev/nvme2n1
sudo vgcreate openstack-vg /dev/nvme2n1
# Set up VM storage tiers
# High-performance tier (WD SN750 NVMe)
sudo pvcreate /dev/nvme0n1
sudo vgcreate tier1-vg /dev/nvme0n1
# Medium-performance tier (Samsung 870 EVO SSD)
sudo pvcreate /dev/sdb
sudo vgcreate tier2-vg /dev/sdb
# Capacity tier (WD Blue HDD)
sudo pvcreate /dev/sda
sudo vgcreate tier3-vg /dev/sda

# Create separate LVs for each OpenStack service
sudo lvcreate -L 32G -n dashboard-lv openstack-vg # Create shared dashboard LV for Horizon and Skyline
sudo lvcreate -L 75G -n mysql-lv openstack-vg # for MySQL+InnoDB and Trove
sudo lvcreate -L 10G -n rabbitmq-lv openstack-vg # rabbitMQ and zaqar
sudo lvcreate -L 200G -n glance-lv openstack-vg 
sudo lvcreate -L 10G -n keystone-lv openstack-vg # for keystone and barbican
sudo lvcreate -L 25G -n nova-api-lv openstack-vg # Your existing Nova LV will host Nova and Zun
sudo lvcreate -L 50G -n network-services-lv openstack-vg  # Create shared network services LV for Neutron, Octavia, and Designate
sudo lvcreate -L 25G -n cinder-api-lv openstack-vg 
# Storage Services
# Create shared storage services LV for Swift and Manila
sudo lvcreate -L 500G -n storage-services-lv tier3-vg # Create shared storage services LV for Swift and Manila
sudo lvcreate -L 300G -n backup-lv tier3-vg ## Create backup services LV for Freezer

# Format with XFS for better performance
sudo mkfs.xfs /dev/openstack-vg/dashboard-lv
sudo mkfs.xfs /dev/openstack-vg/mysql-lv
sudo mkfs.xfs /dev/openstack-vg/rabbitmq-lv
sudo mkfs.xfs /dev/openstack-vg/glance-lv
sudo mkfs.xfs /dev/openstack-vg/keystone-lv
sudo mkfs.xfs /dev/openstack-vg/nova-api-lv
sudo mkfs.xfs /dev/openstack-vg/network-services-lv
sudo mkfs.xfs /dev/openstack-vg/cinder-api-lv
sudo mkfs.xfs /dev/tier3-vg/storage-services-lv

# Create mount points
sudo mkdir -p /var/lib/mysql
sudo mkdir -p /var/lib/rabbitmq
sudo mkdir -p /var/lib/glance
sudo mkdir -p /var/lib/keystone
sudo mkdir -p /var/lib/nova
sudo mkdir -p /var/lib/neutron
sudo mkdir -p /var/lib/cinder
sudo mkdir -p /var/lib/mysql/{main,trove}
sudo mkdir -p /var/lib/dashboard/{horizon,skyline}

# Mount *-vl
sudo mount /dev/openstack-vg/dashboard-lv /var/lib/dashboard

# Add to fstab for persistent mounting
echo "/dev/openstack-vg/mysql-lv /var/lib/mysql xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/rabbitmq-lv /var/lib/rabbitmq xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/glance-lv /var/lib/glance xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/keystone-lv /var/lib/keystone xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/nova-api-lv /var/lib/nova xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/neutron-lv /var/lib/neutron xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/cinder-api-lv /var/lib/cinder xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

# Create storage pools in Juju
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg --controller=manual-controller
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg --controller=manual-controller
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg --controller=manual-controller

##### --------- ~~~~~~~~~~~ ----------- #######

# Tier 1: High-Performance Storage (WD SN750 NVMe)
sudo pvcreate /dev/nvme0n1
sudo vgcreate tier1-vg /dev/nvme0n1
sudo lvcreate -l 100%FREE -n tier1-lv tier1-vg
sudo mkfs.xfs /dev/tier1-vg/tier1-lv

# Tier 2: Medium-Performance Storage (Samsung 870 EVO SSD)
sudo pvcreate /dev/sdb
sudo vgcreate tier2-vg /dev/sdb
sudo lvcreate -l 100%FREE -n tier2-lv tier2-vg
sudo mkfs.xfs /dev/tier2-vg/tier2-lv

# Tier 3: Capacity Storage (WD Blue HDD)
sudo pvcreate /dev/sda
sudo vgcreate tier3-vg /dev/sda
sudo lvcreate -l 100%FREE -n tier3-lv tier3-vg
sudo mkfs.xfs /dev/tier3-vg/tier3-lv

# Deploy MySQL instead of MariaDB
juju deploy mysql --config=/path/to/mysql-config.yaml

# Deploy OpenStack base
juju deploy openstack-base \
  --config openstack-origin=cloud:focal-victoria \
  --config mysql-innodb-buffer-pool-size=4G

# Create storage pools
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg

# Configure Cinder for tiered storage
juju config cinder \
  storage-backend=lvm \
  volume-group="tier1-vg" \
  glance-api-version=2

# Configure Nova compute
juju config nova-compute \
  cpu-mode=host-passthrough \
  resume-guests-state-on-host-boot=true

# Deploy MySQL instead of MariaDB
juju deploy mysql --config=/path/to/mysql-config.yaml

# Deploy OpenStack base
juju deploy openstack-base \
  --config openstack-origin=cloud:noble-bobcat \
  --config mysql-innodb-buffer-pool-size=4G

# Create storage pools
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg

# Deploy MySQL instead of MariaDB
juju deploy mysql --config=/path/to/mysql-config.yaml

# Deploy OpenStack base
juju deploy openstack-base \
  --config openstack-origin=cloud:focal-victoria \
  --config mysql-innodb-buffer-pool-size=4G

# Create storage pools
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg

# Deploy MySQL instead of MariaDB
juju deploy mysql --config=/path/to/mysql-config.yaml

# Deploy OpenStack base
juju deploy openstack-base \
  --config openstack-origin=cloud:focal-victoria \
  --config mysql-innodb-buffer-pool-size=4G

# Create storage pools
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg


