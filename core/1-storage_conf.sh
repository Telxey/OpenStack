#!/bin/bash

echo 'Part 1: Optimized Storage Configuration'

# Wipe existing data if needed (BE CAREFUL - this will erase data!)
sudo wipefs -a /dev/nvme2n1
sudo wipefs -a /dev/nvme0n1
sudo wipefs -a /dev/sda
sudo wipefs -a /dev/sdb

# Create physical volumes
sudo pvcreate /dev/nvme2n1
sudo pvcreate /dev/nvme0n1
sudo pvcreate /dev/sda
sudo pvcreate /dev/sdb

# Create volume groups
sudo vgcreate openstack-vg /dev/nvme2n1     # Primary OpenStack services
sudo vgcreate tier1-vg /dev/nvme0n1         # High-performance tier
sudo vgcreate tier2-vg /dev/sdb             # Medium-performance tier
sudo vgcreate tier3-vg /dev/sda             # Capacity tier

# Create SHARED logical volumes - fewer LVs with related services grouped
sudo lvcreate -L 100G -n database-lv openstack-vg    # MySQL, Trove
sudo lvcreate -L 20G -n messaging-lv openstack-vg   # RabbitMQ
sudo lvcreate -L 150G -n compute-lv openstack-vg     # Nova, Ironic, Zun
sudo lvcreate -L 30G -n network-lv openstack-vg     # Neutron, Octavia, Designate
sudo lvcreate -L 50G -n dashboard-lv openstack-vg    # Horizon, Skyline, Kitti
sudo lvcreate -L 150G -n storage-lv openstack-vg     # Glance, Cinder, Manila
sudo lvcreate -L 25G -n identity-lv openstack-vg     # Keystone
sudo lvcreate -L 25G -n monitoring-lv openstack-vg     # Ceilemeter


# Create tier logical volumes
sudo lvcreate -L 900G -n tier1-lv tier1-vg           # High-performance VMs/volumes
sudo lvcreate -L 900G -n tier2-lv tier2-vg           # Standard VMs/volumes
sudo lvcreate -L 1.7T -n tier3-lv tier3-vg           # Capacity storage, backups, Swift, Freezer

# Format the logical volumes with XFS
sudo mkfs.xfs /dev/openstack-vg/database-lv
sudo mkfs.xfs /dev/openstack-vg/messaging-lv
sudo mkfs.xfs /dev/openstack-vg/compute-lv
sudo mkfs.xfs /dev/openstack-vg/network-lv
sudo mkfs.xfs /dev/openstack-vg/dashboard-lv
sudo mkfs.xfs /dev/openstack-vg/storage-lv
sudo mkfs.xfs /dev/openstack-vg/identity-lv
sudo mkfs.xfs /dev/openstack-vg/monitoring-lv
sudo mkfs.xfs /dev/tier3-vg/tier3-lv

# Create mount directories
sudo mkdir -p /var/lib/database
sudo mkdir -p /var/lib/messaging
sudo mkdir -p /var/lib/compute
sudo mkdir -p /var/lib/network
sudo mkdir -p /var/lib/dashboard
sudo mkdir -p /var/lib/storage
sudo mkdir -p /var/lib/identity
sudo mkdir -p /var/lib/monitoring
sudo mkdir -p /var/lib/backup

# Mount the logical volumes
sudo mount /dev/openstack-vg/database-lv /var/lib/database
sudo mount /dev/openstack-vg/messaging-lv /var/lib/messaging
sudo mount /dev/openstack-vg/compute-lv /var/lib/compute
sudo mount /dev/openstack-vg/network-lv /var/lib/network
sudo mount /dev/openstack-vg/dashboard-lv /var/lib/dashboard
sudo mount /dev/openstack-vg/storage-lv /var/lib/storage
sudo mount /dev/openstack-vg/identity-lv /var/lib/identity
sudo mount /dev/tier3-vg/tier3-lv /var/lib/backup

# Update /etc/fstab for persistent mounts
echo "/dev/openstack-vg/database-lv /var/lib/database xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/messaging-lv /var/lib/messaging xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/compute-lv /var/lib/compute xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/network-lv /var/lib/network xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/dashboard-lv /var/lib/dashboard xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/storage-lv /var/lib/storage xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/identity-lv /var/lib/identity xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/openstack-vg/monitoring-lv /var/lib/monitoring xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
echo "/dev/tier3-vg/tier3-lv /var/lib/backup xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab