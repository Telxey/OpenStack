#!/bin/bash
set -euo pipefail

# Devices (adjust as needed)
DEV_NVME2N1="/dev/nvme2n1"   # Control-plane VG
DEV_NVME0N1="/dev/nvme0n1"   # Tier-1 Cinder
DEV_SDB="/dev/sdb"           # Tier-2 Cinder
DEV_SDA="/dev/sda"           # Tier-3 Cinder

# Volume Groups
VG_OS="openstack-vg"
VG_T1="tier1-vg"
VG_T2="tier2-vg"
VG_T3="tier3-vg"

# Logical Volumes for openstack-vg
LVS_OS=(mysql rabbitmq glance keystone nova-api network-services cinder-api dashboard)

# Create PVs and VGs if not exist
for dev in "$DEV_NVME2N1" "$DEV_NVME0N1" "$DEV_SDB" "$DEV_SDA"; do
  if ! pvs | grep -q "^$dev"; then
    echo "sudo pvcreate $dev"
  fi
done

if ! vgs | grep -q "^$VG_OS"; then
  echo "sudo vgcreate $VG_OS $DEV_NVME2N1"
fi
if ! vgs | grep -q "^$VG_T1"; then
  echo "sudo vgcreate $VG_T1 $DEV_NVME0N1"
fi
if ! vgs | grep -q "^$VG_T2"; then
  echo "sudo vgcreate $VG_T2 $DEV_SDB"
fi
if ! vgs | grep -q "^$VG_T3"; then
  echo "sudo vgcreate $VG_T3 $DEV_SDA"
fi

# Create LVs for openstack-vg
for lv in "${LVS_OS[@]}"; do
  if ! lvs | grep -q "^${lv}-lv"; then
    echo "sudo lvcreate -L 50G -n ${lv}-lv $VG_OS"
  fi
done

# Create tier LVs (one per VG, use all space)
for vg in "$VG_T1" "$VG_T2" "$VG_T3"; do
  lvname="${vg/tier/-lv}"
  if ! lvs | grep -q "^$lvname"; then
    echo "sudo lvcreate -l 100%FREE -n $lvname $vg"
  fi
done

# Format LVs as XFS if not already
for lv in "${LVS_OS[@]}"; do
  dev_path="/dev/${VG_OS}/${lv}-lv"
  if ! blkid "$dev_path" | grep -q xfs; then
    echo "sudo mkfs.xfs -f $dev_path"
  fi
done
for vg in "$VG_T1" "$VG_T2" "$VG_T3"; do
  lvname="${vg/tier/-lv}"
  dev_path="/dev/${vg}/$lvname"
  if ! blkid "$dev_path" | grep -q xfs; then
    echo "sudo mkfs.xfs -f $dev_path"
  fi
done

# Create mount points
MOUNT_POINTS=(
  /var/lib/mysql
  /var/lib/rabbitmq
  /var/lib/glance
  /var/lib/keystone
  /var/lib/nova
  /var/lib/neutron
  /var/lib/cinder
  /var/lib/dashboard
)
for mp in "${MOUNT_POINTS[@]}"; do
  echo "sudo mkdir -p $mp"
done

# Storage mount points for tiers
for mp in /var/lib/storage/tier1 /var/lib/storage/tier2 /var/lib/storage/tier3; do
  echo "sudo mkdir -p $mp"
done

# /etc/fstab entries (deduplicated)
FSTAB_ENTRIES=(
  "/dev/${VG_OS}/mysql-lv           /var/lib/mysql      xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/rabbitmq-lv        /var/lib/rabbitmq   xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/glance-lv          /var/lib/glance     xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/keystone-lv        /var/lib/keystone   xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/nova-api-lv        /var/lib/nova       xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/network-services-lv /var/lib/neutron   xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/cinder-api-lv      /var/lib/cinder     xfs defaults,noatime 0 0"
  "/dev/${VG_OS}/dashboard-lv       /var/lib/dashboard  xfs defaults,noatime 0 0"
  "/dev/${VG_T1}/tier1-lv           /var/lib/storage/tier1 xfs defaults,noatime 0 0"
  "/dev/${VG_T2}/tier2-lv           /var/lib/storage/tier2 xfs defaults,noatime 0 0"
  "/dev/${VG_T3}/tier3-lv           /var/lib/storage/tier3 xfs defaults,noatime 0 0"
)

for entry in "${FSTAB_ENTRIES[@]}"; do
  grep -qF -- "$entry" /etc/fstab || echo "echo '$entry' | sudo tee -a /etc/fstab"
done

echo "# To mount all filesystems after setup, run:"
echo "sudo systemctl daemon-reload && sudo mount -a" 