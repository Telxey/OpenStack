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

# Create separate LVs for each OpenStack service
sudo lvcreate -L 150G -n mysql-lv openstack-vg
sudo lvcreate -L 100G -n rabbitmq-lv openstack-vg
sudo lvcreate -L 150G -n glance-lv openstack-vg
sudo lvcreate -L 100G -n keystone-lv openstack-vg
sudo lvcreate -L 100G -n nova-api-lv openstack-vg
sudo lvcreate -L 100G -n neutron-lv openstack-vg
sudo lvcreate -L 100G -n cinder-api-lv openstack-vg

# Format with XFS for better performance
sudo mkfs.xfs /dev/openstack-vg/mysql-lv
sudo mkfs.xfs /dev/openstack-vg/rabbitmq-lv
sudo mkfs.xfs /dev/openstack-vg/glance-lv
sudo mkfs.xfs /dev/openstack-vg/keystone-lv
sudo mkfs.xfs /dev/openstack-vg/nova-api-lv
sudo mkfs.xfs /dev/openstack-vg/neutron-lv
sudo mkfs.xfs /dev/openstack-vg/cinder-api-lv

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

# Database & Related Services
sudo mkdir -p /var/lib/mysql/{main,trove}

# Optimized Storage Allocation with Shared LVs
# Create shared dashboard LV for Horizon and Skyline
sudo lvcreate -L 50G -n dashboard-lv openstack-vg
sudo mkfs.xfs /dev/openstack-vg/dashboard-lv
sudo mkdir -p /var/lib/dashboard/{horizon,skyline}
sudo mount /dev/openstack-vg/dashboard-lv /var/lib/dashboard
echo "/dev/openstack-vg/dashboard-lv /var/lib/dashboard xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
# Storage Services
# Create shared storage services LV for Swift and Manila
sudo lvcreate -L 500G -n storage-services-lv tier3-vg
sudo mkfs.xfs /dev/tier3-vg/storage-services-lv
sudo mkdir -p /var/lib/storage/{swift,manila}
sudo mount /dev/tier3-vg/storage-services-lv /var/lib/storage
echo "/dev/tier3-vg/storage-services-lv /var/lib/storage xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

# Compute & Container Services
# Your existing Nova LV will host Nova and Zun
sudo mkdir -p /var/lib/nova/{compute,zun}

# Network Services
# Create shared network services LV for Neutron, Octavia, and Designate
sudo lvcreate -L 100G -n network-services-lv openstack-vg
sudo mkfs.xfs /dev/openstack-vg/network-services-lv
sudo mkdir -p /var/lib/network/{neutron,octavia,designate}
sudo mount /dev/openstack-vg/network-services-lv /var/lib/network
echo "/dev/openstack-vg/network-services-lv /var/lib/network xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
# Backup Services
# Create backup services LV for Freezer
sudo lvcreate -L 300G -n backup-lv tier3-vg
sudo mkfs.xfs /dev/tier3-vg/backup-lv
sudo mkdir -p /var/lib/backup/freezer
sudo mount /dev/tier3-vg/backup-lv /var/lib/backup
echo "/dev/tier3-vg/backup-lv /var/lib/backup xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

# Create storage pools in Juju
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg --controller=manual-controller
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg --controller=manual-controller
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg --controller=manual-controller

# Deploy OpenStack with Juju

# Deploy OpenStack base with storage configuration
juju deploy openstack-base \
  --config openstack-origin=cloud:focal-victoria \
  --config mysql-innodb-buffer-pool-size=4G \
  --model=openstack

# Full deploy
# Deploy base OpenStack
juju deploy openstack-base --config openstack-origin=cloud:noble-bobcat

# Deploy additional services
juju deploy cs:horizon
juju deploy cs:skyline
juju deploy cs:trove
juju deploy cs:swift-proxy
juju deploy cs:swift-storage
juju deploy cs:manila
juju deploy cs:zun
juju deploy cs:octavia
juju deploy cs:designate
juju deploy cs:freezer

# Configure with appropriate storage paths
juju config horizon data-dir=/var/lib/dashboard/horizon
juju config skyline data-dir=/var/lib/dashboard/skyline
juju config trove data-dir=/var/lib/mysql/trove
juju config swift-storage storage-dir=/var/lib/storage/swift
juju config manila data-dir=/var/lib/storage/manila
juju config zun data-dir=/var/lib/nova/zun
juju config octavia data-dir=/var/lib/network/octavia
juju config designate data-dir=/var/lib/network/designate
juju config freezer backup-dir=/var/lib/backup/freezer

# Set up relations
juju add-relation horizon keystone
juju add-relation skyline keystone
juju add-relation trove mysql
juju add-relation trove rabbitmq-server
juju add-relation trove keystone
juju add-relation swift-proxy keystone
juju add-relation swift-proxy swift-storage
juju add-relation manila mysql
juju add-relation manila rabbitmq-server
juju add-relation manila keystone
juju add-relation zun mysql
juju add-relation zun rabbitmq-server
juju add-relation zun keystone
juju add-relation zun nova-compute
juju add-relation octavia mysql
juju add-relation octavia rabbitmq-server
juju add-relation octavia keystone
juju add-relation octavia neutron-api
juju add-relation designate mysql
juju add-relation designate rabbitmq-server
juju add-relation designate keystone
juju add-relation freezer mysql
juju add-relation freezer keystone




# Bootstrap Juju controller using physical hardware
# This creates a dedicated controller machine
juju bootstrap maas-cloud maas-controller \
  --constraints "mem=8G cores=4" \
  --bootstrap-series=noble-bobcat



# Create storage pools
juju create-storage-pool nvme-fast lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg

# Create OpenStack model
juju add-model openstack

# Deploy production OpenStack with high availability
juju deploy openstack-base \
  --config openstack-origin=cloud:focal-wallaby \
  --config enable-live-migration=true \
  --config enable-resize=true \
  --config worker-multiplier=0.25 \
  --config virt-type=kvm \
  --config debug=false

# Configure Cinder with tiered storage
juju config cinder \
  storage-backend=lvm \
  volume-group="tier1-vg" \
  glance-api-version=2

# Add SSD tier
juju deploy cinder-ceph ssd-tier \
  --config volume-group="tier2-vg"

# Add HDD tier
juju deploy cinder-ceph hdd-tier \
  --config volume-group="tier3-vg"

# Configure Nova compute
juju config nova-compute \
  cpu-mode=host-passthrough \
  resume-guests-state-on-host-boot=true

# Add monitoring
juju deploy prometheus
juju deploy grafana
juju deploy telegraf

# Connect monitoring to OpenStack
juju add-relation prometheus:target mysql:metrics
juju add-relation prometheus:target rabbitmq-server:metrics
juju add-relation prometheus:target keystone:metrics
juju add-relation prometheus:target nova-compute:metrics
juju add-relation prometheus:target cinder:metrics
juju add-relation grafana prometheus  

# Create backup directories
sudo mkdir -p /var/backups/maas
sudo mkdir -p /var/backups/juju
sudo mkdir -p /var/backups/openstack

# Set up PostgreSQL backup for MAAS
sudo -u postgres pg_dump --format=custom maasdb > /var/backups/maas/maasdb-$(date +%Y%m%d).dump

# Set up Juju backup
juju create-backup --filename=/var/backups/juju/juju-$(date +%Y%m%d).tar.gz

# Secure OpenStack API endpoints
juju config keystone ssl-cert="$(cat /path/to/ssl.cert)" ssl-key="$(cat /path/to/ssl.key)"

# Enable security hardening
juju config neutron-api enable-security-groups=true

# Create backup directory
sudo mkdir -p /var/backups/mysql

# Set up MySQL backup script
sudo tee /usr/local/bin/backup-mysql.sh > /dev/null << EOF
#!/bin/bash
TIMESTAMP=\$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/backups/mysql"
MYSQL_USER="root"
MYSQL_PASSWORD="your_mysql_root_password"

# Backup all databases
mysqldump --user=\$MYSQL_USER --password=\$MYSQL_PASSWORD --all-databases > \$BACKUP_DIR/all-databases-\$TIMESTAMP.sql

# Backup individual OpenStack databases
for DB in nova keystone glance neutron cinder; do
  mysqldump --user=\$MYSQL_USER --password=\$MYSQL_PASSWORD \$DB > \$BACKUP_DIR/\$DB-\$TIMESTAMP.sql
done

# Remove backups older than 7 days
find \$BACKUP_DIR -name "*.sql" -type f -mtime +7 -delete
EOF

# Make script executable
sudo chmod +x /usr/local/bin/backup-mysql.sh

# Add to crontab to run daily
echo "0 2 * * * /usr/local/bin/backup-mysql.sh" | sudo tee -a /etc/crontab

# Bootstrap Juju to the dedicated VM (after it's deployed)
juju bootstrap maas-cloud maas-controller \
  --constraints "tags=juju-controller" \
  --bootstrap-series=noble-bobcat

# Remove the manual controller
juju kill-controller manual-controller --no-prompt

# Bootstrap a new controller directly with MAAS
juju bootstrap maas-cloud maas-controller

# Add MAAS cloud with force
juju add-cloud maas-cloud --controller=manual-controller --force

# Add MAAS credentials
juju add-credential maas-cloud --controller=manual-controller

# Create model
juju add-model openstack maas-cloud --controller=manual-controller

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
sudo lvcreate -L 10G -n dashboard-lv openstack-vg
sudo lvcreate -L 50G -n mysql-lv openstack-vg
sudo lvcreate -L 10G -n rabbitmq-lv openstack-vg
sudo lvcreate -L 150G -n glance-lv openstack-vg
sudo lvcreate -L 10G -n keystone-lv openstack-vg
sudo lvcreate -L 100G -n nova-api-lv openstack-vg
sudo lvcreate -L 100G -n network-services-lv openstack-vg
sudo lvcreate -L 100G -n cinder-api-lv openstack-vg
# Storage Services
# Create shared storage services LV for Swift and Manila
sudo lvcreate -L 500G -n storage-services-lv tier3-vg
sudo lvcreate -L 300G -n backup-lv tier3-vg

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


