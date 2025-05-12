# Production Deployment Guide

## MAAS 3.6 + Juju 3.x + OpenStack Bobcat on Ubuntu 24.04 LTS

> **Goal**  Deploy a fully‑featured, highly‑available OpenStack cloud on a single hardware cluster using MAAS as bare‑metal orchestrator, Juju as application manager, and tiered LVM storage.  The same host set will run the MAAS region+rack controller, the Juju controller, and the OpenStack control‑plane and compute services.

---

### 1. Environment Overview

| Item               | Example Value                     | Notes                                |
| ------------------ | --------------------------------- | ------------------------------------ |
| OS                 | Ubuntu 24.04 **Noble**            | All nodes, including the MAAS server |
| MAAS version       | **3.6**                           | Ships with PG 17 support             |
| Juju version       | **3.6** (snap)                    | Matches latest LTS channel           |
| OpenStack release  | **Bobcat**                        | cloud\:noble‑bobcat pocket           |
| Control‑plane NVMe | `/dev/nvme2n1` (Crucial P1 1 TB)  | OpenStack databases & services       |
| Fast VM NVMe       | `/dev/nvme0n1` (WD SN750 1 TB)    | Tier‑1 Cinder backend                |
| SSD                | `/dev/sdb` (Samsung 870 EVO 2 TB) | Tier‑2 Cinder backend                |
| HDD                | `/dev/sda` (WD Blue 4 TB)         | Tier‑3 Cinder & object storage       |
| Management network | `192.168.10.0/24`                 | MAAS provides DHCP & PXE             |
| API/L2 networks    | Adjust to your fabric plan        | VLAN trunks defined in MAAS          |

> **Adjust device names** to match your server.

---

### 2. High‑Level Workflow

1. **Prepare the MAAS host** (OS hardening, time‑sync, SSH keys).
2. **Install MAAS 3.6** in region + rack mode with external PostgreSQL 17.
3. **Commission and tag** the same machine (and any additional hardware) for Juju & OpenStack roles.
4. **Install Juju CLI** and **bootstrap** a controller on MAAS.
5. **Build LVM tiers** (control‑plane VG + three Cinder VGs).
6. **Register Juju storage‑pools** mapped to the VGs.rhtgieirlo
7. **Deploy the `openstack-base` bundle** pinned to Bobcat.
8. **Add optional services** (Horizon, Skyline, Swift, Manila, Zun, Octavia, Designate, Freezer).
9. **Configure multi‑backend Cinder**, Nova CPU options, Neutron, SSL, etc.
10. **Integrate monitoring** (Prometheus + Grafana) and **backup jobs**.
11. **Validate** the cloud functions (launch instances, live‑migration, volume attach).

---

### 3. Step‑by‑Step Instructions

#### 3.1 Base OS & MAAS

```bash
# On the bare‑metal host
sudo apt update && sudo apt full-upgrade -y
sudo snap install maas --channel=3.6/stable
# Initialise MAAS with built‑in PG 17 (or point to external cluster)
sudo maas init region+rack --database-uri "postgres://maas:STRONGPASS@localhost/maas"
# Create the first admin user
sudo maas createadmin --username $USER --email you@example.com --password 'STRONGPASS'
```

Open the MAAS UI on `http://<hostIP>:5240/MAAS` to:

* Import Ubuntu 24.04 and any required images
* Define fabrics, VLANs, subnets, IP ranges, DNS, and routable spaces

#### 3.2 Juju CLI & Controller

```bash
sudo snap install juju --classic
juju clouds         # should list maas-cloud automatically
# Bootstrap controller on the MAAS host itself (8 GB RAM / 4 vCPU)
juju bootstrap maas-cloud maas-controller \
  --constraints="mem=8G cores=4" \
  --bootstrap-series=noble
```

(If you tested with a manual controller earlier, delete it: `juju kill-controller manual-controller --no-prompt`.)

#### 3.3 LVM Storage Design

| VG             | Device         | Purpose                        |
| -------------- | -------------- | ------------------------------ |
| `openstack-vg` | `/dev/nvme2n1` | Databases & core services      |
| `tier1-vg`     | `/dev/nvme0n1` | High‑IOPS VM disks (Cinder)    |
| `tier2-vg`     | `/dev/sdb`     | Mid‑tier VM disks              |
| `tier3-vg`     | `/dev/sda`     | Capacity tier, Swift & backups |

Create the VGs and logical volumes:

```bash
# Control‑plane
sudo pvcreate /dev/nvme2n1
sudo vgcreate openstack-vg /dev/nvme2n1
for lv in mysql rabbitmq glance keystone nova-api network-services cinder-api dashboard; do
  sudo lvcreate -L 50G -n ${lv}-lv openstack-vg
done

# Tiered backends
sudo pvcreate /dev/nvme0n1 && vgcreate tier1-vg /dev/nvme0n1
sudo pvcreate /dev/sdb      && vgcreate tier2-vg /dev/sdb
sudo pvcreate /dev/sda      && vgcreate tier3-vg /dev/sda

lvcreate -l 100%FREE -n tier1-lv tier1-vg
lvcreate -l 100%FREE -n tier2-lv tier2-vg
lvcreate -l 100%FREE -n tier3-lv tier3-vg

mkfs.xfs /dev/{openstack-vg/mysql-lv,openstack-vg/rabbitmq-lv,openstack-vg/glance-lv,
  openstack-vg/keystone-lv,openstack-vg/nova-api-lv,openstack-vg/network-services-lv,
  openstack-vg/cinder-api-lv,openstack-vg/dashboard-lv,
  tier1-vg/tier1-lv,tier2-vg/tier2-lv,tier3-vg/tier3-lv}
```

Mount points (sample):

```bash
sudo mkdir -p /var/lib/{mysql,rabbitmq,glance,keystone,nova,neutron,cinder}
sudo mkdir -p /var/lib/dashboard/{horizon,skyline}
# one‑liner to append to /etc/fstab (adjust UUIDs as desired)
cat << 'EOF' | sudo tee -a /etc/fstab
/dev/openstack-vg/mysql-lv           /var/lib/mysql      xfs defaults,noatime 0 0
/dev/openstack-vg/rabbitmq-lv        /var/lib/rabbitmq   xfs defaults,noatime 0 0
/dev/openstack-vg/glance-lv          /var/lib/glance     xfs defaults,noatime 0 0
/dev/openstack-vg/keystone-lv        /var/lib/keystone   xfs defaults,noatime 0 0
/dev/openstack-vg/nova-api-lv        /var/lib/nova       xfs defaults,noatime 0 0
/dev/openstack-vg/network-services-lv /var/lib/neutron   xfs defaults,noatime 0 0
/dev/openstack-vg/cinder-api-lv      /var/lib/cinder     xfs defaults,noatime 0 0
/dev/openstack-vg/dashboard-lv       /var/lib/dashboard  xfs defaults,noatime 0 0
EOF
sudo systemctl daemon-reload && sudo mount -a
```

#### 3.4 Register Storage Pools in Juju

```bash
juju create-storage-pool nvme-fast  lvm volume-group=tier1-vg
juju create-storage-pool ssd-medium lvm volume-group=tier2-vg
juju create-storage-pool hdd-capacity lvm volume-group=tier3-vg
```

#### 3.5 Deploy OpenStack Base

```bash
juju add-model openstack
juju deploy openstack-base \
  --config openstack-origin=cloud:noble-bobcat \
  --config enable-live-migration=true \
  --config enable-resize=true \
  --config worker-multiplier=0.25 \
  --config virt-type=kvm
```

(The `openstack-base` bundle already brings MySQL‑InnoDB‑Cluster and RabbitMQ.)

#### 3.6 Add Optional Services

```bash
for svc in horizon skyline trove swift-proxy swift-storage manila zun octavia designate freezer; do
  juju deploy cs:$svc
done
```

Bind services to data directories:

```bash
juju config horizon    data-dir=/var/lib/dashboard/horizon
juju config skyline    data-dir=/var/lib/dashboard/skyline
juju config trove      data-dir=/var/lib/mysql/trove
juju config swift-storage storage-dir=/var/lib/storage/swift
juju config manila     data-dir=/var/lib/storage/manila
juju config zun        data-dir=/var/lib/nova/zun
juju config octavia    data-dir=/var/lib/neutron/octavia
juju config designate  data-dir=/var/lib/neutron/designate
juju config freezer    backup-dir=/var/lib/backup/freezer
```

Add relations (most will auto‑relate with `openstack-integrator`):

```bash
juju add-relation horizon  keystone
juju add-relation skyline  keystone
juju add-relation trove    mysql
juju add-relation trove    rabbitmq-server
# …continue per service…
```

#### 3.7 Cinder Multi‑Backend Example (`cinder.conf` fragment)

```ini
[DEFAULT]
enabled_backends = fast, ssd, hdd

[fast]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group  = tier1-vg
volume_backend_name = nvme-fast

[ssd]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group  = tier2-vg
volume_backend_name = ssd-medium

[hdd]
volume_driver = cinder.volume.drivers.lvm.LVMVolumeDriver
volume_group  = tier3-vg
volume_backend_name = hdd-capacity
```

Apply via:

```bash
juju config cinder --file cinder-multibackend.yaml
```

#### 3.8 Nova Compute Tuning

```bash
juju config nova-compute \
  cpu-mode=host-passthrough \
  resume-guests-state-on-host-boot=true
```

#### 3.9 Monitoring Stack

```bash
juju deploy prometheus
juju deploy grafana
juju deploy telegraf
juju add-relation prometheus:target mysql:metrics
juju add-relation grafana prometheus
```

Import the **OpenStack Cloud Overview** Grafana dashboard (JSON ID 158)

#### 3.10 Backups

```bash
sudo mkdir -p /var/backups/{maas,juju,mysql}
# MAAS (daily via cron)
0 1 * * * postgres pg_dump -Fc maasdb > /var/backups/maas/maas-$(date +\%F).dump
# Juju controller snapshot
0 2 * * * juju create-backup --filename=/var/backups/juju/juju-$(date +\%F).tar.gz
# MySQL (OpenStack) dump script
0 3 * * * /usr/local/bin/backup-mysql.sh
```

`/usr/local/bin/backup-mysql.sh`:

```bash
#!/bin/bash
set -euo pipefail
TIMESTAMP=$(date +%F-%H%M)
MYSQL_PWD='your_root_pw'
DBLIST="nova keystone glance neutron cinder"
for DB in $DBLIST; do
  mysqldump --single-transaction -u root $DB > /var/backups/mysql/${DB}-${TIMESTAMP}.sql
done
find /var/backups/mysql -type f -mtime +7 -delete
```

#### 3.11 TLS & Security Hardening

```bash
juju config keystone ssl-cert="$(cat /etc/ssl/certs/cloud.crt)" ssl-key="$(cat /etc/ssl/private/cloud.key)"
juju config neutron-api enable-security-groups=true
```

Enable UEFI Secure‑Boot, SELinux/AppArmor enforcing, and limit API exposure via firewall rules.

---

### 4. Validation Checklist

* [ ] `juju status` shows all applications **green**
* [ ] `openstack compute service list` reports **enabled | up**
* [ ] Launch a test VM (NVMe backend) ➜ attach Cinder volume (HDD backend)
* [ ] Live‑migrate instance ➜ verify reachability
* [ ] Dashboard reachable at `https://cloud.example.com/horizon/`
* [ ] Prometheus targets **up**, Grafana dashboard populated

---

### 5. Appendix

* **MAAS CLI reference:** [https://maas.io/docs](https://maas.io/docs)
* **Juju charm store:** `charmhub.io`
* **OpenStack Bobcat docs:** [https://docs.openstack.org/bobcat/](https://docs.openstack.org/bobcat/)

---

**Author:** *(generated by ChatGPT)*  •  **Date:** 2025‑05‑05

---

## Optimized Storage Allocation with Shared LVs

* Dashboard Services

```bash
# Create shared dashboard LV for Horizon and Skyline
sudo lvcreate -L 50G -n dashboard-lv openstack-vg
sudo mkfs.xfs /dev/openstack-vg/dashboard-lv
sudo mkdir -p /var/lib/dashboard/{horizon,skyline}
sudo mount /dev/openstack-vg/dashboard-lv /var/lib/dashboard
echo "/dev/openstack-vg/dashboard-lv /var/lib/dashboard xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
```

* Database & Related Services

```bash
# Your existing MySQL LV will host MySQL and Trove
 sudo mkdir -p /var/lib/mysql/{main,trove}
```

* Storage Services

```bash
# Create shared storage services LV for Swift and Manila
sudo lvcreate -L 500G -n storage-services-lv tier3-vg
sudo mkfs.xfs /dev/tier3-vg/storage-services-lv
sudo mkdir -p /var/lib/storage/{swift,manila}
sudo mount /dev/tier3-vg/storage-services-lv /var/lib/storage
echo "/dev/tier3-vg/storage-services-lv /var/lib/storage xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
```

* Compute & Container Services

```bash
# Your existing Nova LV will host Nova and Zun
sudo mkdir -p /var/lib/nova/{compute,zun}
```

* Network Services

```bash
# Create shared network services LV for Neutron, Octavia, and Designate
sudo lvcreate -L 100G -n network-services-lv openstack-vg
sudo mkfs.xfs /dev/openstack-vg/network-services-lv
sudo mkdir -p /var/lib/network/{neutron,octavia,designate}
sudo mount /dev/openstack-vg/network-services-lv /var/lib/network
echo "/dev/openstack-vg/network-services-lv /var/lib/network xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab
```

* Backup Services

```bash

# Create backup services LV for Freezer
sudo lvcreate -L 300G -n backup-lv tier3-vg
sudo mkfs.xfs /dev/tier3-vg/backup-lv
sudo mkdir -p /var/lib/backup/freezer
sudo mount /dev/tier3-vg/backup-lv /var/lib/backup
echo "/dev/tier3-vg/backup-lv /var/lib/backup xfs defaults,noatime 0 0" | sudo tee -a /etc/fstab

```

## Deploying with Juju

```bach
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

```

This consolidated approach gives you several benefits:

Fewer logical volumes to manage
Better utilization of space
Simplified backup and monitoring
Flexibility to reallocate space between related services

Each service category shares a logical volume, making your storage setup more efficient while still maintaining good performance through your tiered storage approach.
