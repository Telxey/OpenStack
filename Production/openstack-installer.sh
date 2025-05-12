#!/bin/bash

#####################################################
#                                                   #
#       OpenStack Full-Stack Automated Installer    #
#                                                   #
#####################################################

# Color codes for better visibility
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Utility functions
print_section_header() {
    echo -e "\n${BOLD}${BLUE}==============================================${NC}"
    echo -e "${BOLD}${BLUE}   $1${NC}"
    echo -e "${BOLD}${BLUE}==============================================${NC}\n"
}

print_step() {
    echo -e "${YELLOW}[$(date +%H:%M:%S)]${NC} ${BOLD}${CYAN}STEP $1:${NC} ${GREEN}$2${NC}"
}

print_substep() {
    echo -e "  ${YELLOW}→${NC} ${CYAN}$1${NC}"
}

print_command() {
    echo -e "    ${PURPLE}»${NC} ${WHITE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ ERROR: $1${NC}"
}

execute_step() {
    local step_num=$1
    local step_desc=$2
    local command=$3
    
    print_step "$step_num" "$step_desc"
    print_command "$command"
    
    if eval "$command"; then
        print_success "Step $step_num completed successfully"
    else
        print_error "Step $step_num failed with exit code $?"
        print_warning "The installation process will continue, but you may need to fix this issue manually"
    fi
    
    # Short pause for readability
    sleep 1
}

execute_critical_step() {
    local step_num=$1
    local step_desc=$2
    local command=$3
    
    print_step "$step_num" "$step_desc"
    print_command "$command"
    
    if eval "$command"; then
        print_success "Step $step_num completed successfully"
    else
        print_error "Step $step_num failed with exit code $?"
        print_error "This is a critical step. Aborting installation."
        exit 1
    fi
    
    # Short pause for readability
    sleep 1
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    print_warning "This script should be run as root or with sudo"
    print_warning "Trying to continue but some operations might fail"
fi

# Display welcome message
clear
echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║       OPENSTACK AUTOMATED FULL STACK INSTALLER        ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo -e "${CYAN}This script will install and configure a complete OpenStack environment${NC}"
echo -e "${CYAN}including all core and additional services.${NC}"
echo ""
echo -e "${YELLOW}The installation includes:${NC}"
echo " • Storage configuration with tiered volumes"
echo " • Core OpenStack services (Nova, Neutron, Cinder, etc.)"
echo " • Additional services (Ironic, Swift, Manila, etc.)"
echo " • Proper monitoring and backup configuration"
echo ""
echo -e "${RED}WARNING: This will modify your storage configuration.${NC}"
echo -e "${RED}         Ensure you have backups of important data.${NC}"
echo ""
read -p "Press ENTER to continue or CTRL+C to abort..."

# Create a log file
LOG_FILE="/tmp/openstack-install-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1

print_section_header "STARTING INSTALLATION ($(date))"
print_warning "Full logs will be saved to $LOG_FILE"

# System prerequisites
print_section_header "CHECKING PREREQUISITES"

# Check for required tools
for tool in wipefs pvcreate lvcreate mkfs.xfs snap; do
    if command -v $tool >/dev/null 2>&1; then
        print_success "Found required tool: $tool"
    else
        print_warning "Required tool not found: $tool"
        echo -e "Installing required packages..."
        if [[ "$tool" == "snap" ]]; then
            apt update && apt install -y snapd
        else
            apt update && apt install -y lvm2 xfsprogs
        fi
    fi
done

###############################################################
# PART 1: STORAGE CONFIGURATION
###############################################################
print_section_header "PART 1: STORAGE CONFIGURATION"

# Ask for confirmation before wiping disks
echo -e "${RED}WARNING: This will erase ALL DATA on the following devices:${NC}"
echo -e "${RED}  - /dev/nvme2n1${NC}"
echo -e "${RED}  - /dev/nvme0n1${NC}"
echo -e "${RED}  - /dev/sda${NC}"
echo -e "${RED}  - /dev/sdb${NC}"
echo ""
echo -e "${YELLOW}Please confirm these are the correct devices for OpenStack.${NC}"
read -p "Type 'YES' to confirm and continue: " confirmation

if [[ "$confirmation" != "YES" ]]; then
    print_error "Confirmation not received. Aborting."
    exit 1
fi

print_step "1.1" "Wiping existing data from storage devices"
print_warning "This will ERASE ALL DATA on the specified devices!"

devices=("/dev/nvme2n1" "/dev/nvme0n1" "/dev/sda" "/dev/sdb")
for device in "${devices[@]}"; do
    print_substep "Wiping $device"
    if [ -e "$device" ]; then
        execute_command "wipefs -af $device"
    else
        print_warning "$device not found, skipping"
    fi
done

print_step "1.2" "Creating physical volumes"
for device in "${devices[@]}"; do
    if [ -e "$device" ]; then
        execute_command "pvcreate $device"
    fi
done

print_step "1.3" "Creating volume groups"
execute_command "vgcreate openstack-vg /dev/nvme2n1"  # Primary OpenStack services
execute_command "vgcreate tier1-vg /dev/nvme0n1"      # High-performance tier
execute_command "vgcreate tier2-vg /dev/sdb"          # Medium-performance tier
execute_command "vgcreate tier3-vg /dev/sda"          # Capacity tier

print_step "1.4" "Creating logical volumes"
# Create SHARED logical volumes
execute_command "lvcreate -L 100G -n database-lv openstack-vg"   # MySQL, Trove
execute_command "lvcreate -L 20G -n messaging-lv openstack-vg"   # RabbitMQ
execute_command "lvcreate -L 150G -n compute-lv openstack-vg"    # Nova, Ironic, Zun
execute_command "lvcreate -L 30G -n network-lv openstack-vg"     # Neutron, Octavia, Designate
execute_command "lvcreate -L 50G -n dashboard-lv openstack-vg"   # Horizon, Skyline, Kitti
execute_command "lvcreate -L 150G -n storage-lv openstack-vg"    # Glance, Cinder, Manila
execute_command "lvcreate -L 25G -n identity-lv openstack-vg"    # Keystone

# Create tier logical volumes
execute_command "lvcreate -L 900G -n tier1-lv tier1-vg"          # High-performance VMs/volumes
execute_command "lvcreate -L 900G -n tier2-lv tier2-vg"          # Standard VMs/volumes
execute_command "lvcreate -L 1.7T -n tier3-lv tier3-vg"          # Capacity storage, backups, Swift, Freezer

print_step "1.5" "Formatting logical volumes with XFS"
volumes=(
    "/dev/openstack-vg/database-lv"
    "/dev/openstack-vg/messaging-lv"
    "/dev/openstack-vg/compute-lv"
    "/dev/openstack-vg/network-lv"
    "/dev/openstack-vg/dashboard-lv"
    "/dev/openstack-vg/storage-lv"
    "/dev/openstack-vg/identity-lv"
    "/dev/tier3-vg/tier3-lv"
)

for volume in "${volumes[@]}"; do
    if [ -e "$volume" ]; then
        execute_command "mkfs.xfs $volume"
    else
        print_warning "Volume $volume not found, skipping format"
    fi
done

print_step "1.6" "Creating mount directories"
directories=(
    "/var/lib/database"
    "/var/lib/messaging"
    "/var/lib/compute"
    "/var/lib/network"
    "/var/lib/dashboard"
    "/var/lib/storage"
    "/var/lib/identity"
    "/var/lib/backup"
)

for directory in "${directories[@]}"; do
    execute_command "mkdir -p $directory"
done

print_step "1.7" "Mounting the logical volumes"
mount_mapping=(
    "/dev/openstack-vg/database-lv:/var/lib/database"
    "/dev/openstack-vg/messaging-lv:/var/lib/messaging"
    "/dev/openstack-vg/compute-lv:/var/lib/compute"
    "/dev/openstack-vg/network-lv:/var/lib/network"
    "/dev/openstack-vg/dashboard-lv:/var/lib/dashboard"
    "/dev/openstack-vg/storage-lv:/var/lib/storage"
    "/dev/openstack-vg/identity-lv:/var/lib/identity"
    "/dev/tier3-vg/tier3-lv:/var/lib/backup"
)

for mapping in "${mount_mapping[@]}"; do
    IFS=':' read -r volume mountpoint <<< "$mapping"
    if [ -e "$volume" ]; then
        execute_command "mount $volume $mountpoint"
    else
        print_warning "Volume $volume not found, skipping mount"
    fi
done

print_step "1.8" "Updating /etc/fstab for persistent mounts"
# Clear any existing entries for these mount points
execute_command "cp /etc/fstab /etc/fstab.bak.$(date +%Y%m%d-%H%M%S)"

# Add new entries
for mapping in "${mount_mapping[@]}"; do
    IFS=':' read -r volume mountpoint <<< "$mapping"
    if [ -e "$volume" ]; then
        echo "$volume $mountpoint xfs defaults,noatime 0 0" | tee -a /etc/fstab
    fi
done

###############################################################
# PART 2: CREATE SERVICE DIRECTORIES
###############################################################
print_section_header "PART 2: SERVICE DIRECTORIES"

print_step "2.1" "Creating service subdirectories"
execute_command "mkdir -p /var/lib/database/{mysql,trove}"
execute_command "mkdir -p /var/lib/compute/{nova,ironic,zun}"
execute_command "mkdir -p /var/lib/compute/ironic/{api,conductor,tftpboot,httpboot,image-cache}"
execute_command "mkdir -p /var/lib/network/{neutron,octavia,designate}"
execute_command "mkdir -p /var/lib/dashboard/{horizon,skyline,kitti}"
execute_command "mkdir -p /var/lib/storage/{glance,cinder,manila,swift}"
execute_command "mkdir -p /var/lib/backup/{freezer,archive,swift-objects}"

print_step "2.2" "Setting correct permissions"
execute_command "chown -R 999:999 /var/lib/database/mysql" # Default MySQL UID:GID
execute_command "chmod -R 750 /var/lib/database/mysql"

###############################################################
# PART 3: INSTALL JUJU AND LXD
###############################################################
print_section_header "PART 3: INSTALLING JUJU AND LXD"

print_step "3.1" "Installing Juju and LXD via Snap"
execute_command "snap install juju --classic"
execute_command "snap install lxd"

print_step "3.2" "Initializing LXD"
execute_command "lxd init --auto"

print_step "3.3" "Bootstrapping Juju controller with LXD"
execute_command "juju bootstrap localhost lxd-controller"

print_step "3.4" "Creating OpenStack model"
execute_command "juju add-model openstack"

###############################################################
# PART 4: DEPLOY CORE OPENSTACK SERVICES
###############################################################
print_section_header "PART 4: DEPLOYING CORE OPENSTACK SERVICES"

print_step "4.1" "Creating OpenStack bundle configuration"
cat > openstack-bundle.yaml << 'EOF'
series: noble
applications:
  mysql:
    charm: cs:mysql
    num_units: 1
    options:
      dataset-size: 50%
      data-directory: /var/lib/database/mysql
      innodb-buffer-pool-size: 4G
      max-connections: 1000
  rabbitmq-server:
    charm: cs:rabbitmq-server
    num_units: 1
    options:
      data-directory: /var/lib/messaging
  keystone:
    charm: cs:keystone
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/identity
  glance:
    charm: cs:glance
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/storage/glance
  nova-cloud-controller:
    charm: cs:nova-cloud-controller
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/compute/nova
  nova-compute:
    charm: cs:nova-compute
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/compute/nova
  neutron-api:
    charm: cs:neutron-api
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/network/neutron
  neutron-gateway:
    charm: cs:neutron-gateway
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/network/neutron
  cinder:
    charm: cs:cinder
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/storage/cinder
      block-device: "none"
      volume-group: "tier1-vg"
  horizon:
    charm: cs:horizon
    num_units: 1
    options:
      openstack-origin: cloud:noble-bobcat
      service-directory: /var/lib/dashboard/horizon
relations:
  - ["keystone:shared-db", "mysql:shared-db"]
  - ["nova-cloud-controller:shared-db", "mysql:shared-db"]
  - ["nova-cloud-controller:amqp", "rabbitmq-server:amqp"]
  - ["nova-cloud-controller:identity-service", "keystone:identity-service"]
  - ["nova-cloud-controller:cloud-compute", "nova-compute:cloud-compute"]
  - ["nova-compute:amqp", "rabbitmq-server:amqp"]
  - ["nova-compute:image-service", "glance:image-service"]
  - ["glance:shared-db", "mysql:shared-db"]
  - ["glance:identity-service", "keystone:identity-service"]
  - ["glance:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:shared-db", "mysql:shared-db"]
  - ["neutron-api:amqp", "rabbitmq-server:amqp"]
  - ["neutron-api:neutron-plugin-api", "neutron-gateway:neutron-plugin-api"]
  - ["neutron-api:identity-service", "keystone:identity-service"]
  - ["neutron-gateway:amqp", "rabbitmq-server:amqp"]
  - ["cinder:shared-db", "mysql:shared-db"]
  - ["cinder:identity-service", "keystone:identity-service"]
  - ["cinder:amqp", "rabbitmq-server:amqp"]
  - ["horizon:identity-service", "keystone:identity-service"]
EOF
print_success "Bundle configuration created"

print_step "4.2" "Deploying core OpenStack services"
execute_command "juju deploy ./openstack-bundle.yaml"
print_warning "This will take some time to complete. You can check status in another terminal with: juju status"

# Add a small pause to let deployment start
sleep 10

###############################################################
# PART 5: DEPLOY ADDITIONAL SERVICES
###############################################################
print_section_header "PART 5: DEPLOYING ADDITIONAL SERVICES"

print_step "5.1" "Deploying additional OpenStack services"
services=(
    "skyline:dashboard/skyline"
    "trove:database/trove"
    "swift-proxy:storage/swift"
    "swift-storage:backup/swift-objects"
    "manila:storage/manila"
    "zun:compute/zun"
    "octavia:network/octavia"
    "designate:network/designate"
    "freezer:backup/freezer"
    "kitti:dashboard/kitti"
)

for service in "${services[@]}"; do
    IFS=':' read -r name path <<< "$service"
    execute_command "juju deploy cs:$name --config service-directory=/var/lib/$path"
done

print_step "5.2" "Deploying Ironic and dependencies"
execute_command "juju deploy cs:ironic-api --config service-directory=/var/lib/compute/ironic/api"
execute_command "juju deploy cs:ironic-conductor --config service-directory=/var/lib/compute/ironic/conductor --config image-cache-dir=/var/lib/compute/ironic/image-cache"
execute_command "juju deploy cs:tftp --config tftp-root=/var/lib/compute/ironic/tftpboot"
execute_command "juju deploy cs:apache2 --config document-root=/var/lib/compute/ironic/httpboot"

print_step "5.3" "Configuring deployed services"
execute_command "juju config ironic-conductor enabled-hardware-types=ipmi,redfish"
execute_command "juju config ironic-conductor enabled-deploy-interfaces=direct,iscsi"
execute_command "juju config cinder storage-tiers='fast:tier1-vg,standard:tier2-vg,value:tier3-vg'"
execute_command "juju config swift-storage storage-directory=/var/lib/backup/swift-objects"
execute_command "juju config freezer backup-schedule='0 2 * * *'"

###############################################################
# PART 6: CONFIGURE MYSQL FOR INNODB
###############################################################
print_section_header "PART 6: CONFIGURING MYSQL"

print_step "6.1" "Creating MySQL tuning configuration"
cat > mysql-tuning.yaml << 'EOF'
mysql:
  settings:
    innodb-buffer-pool-size: 4G
    innodb-log-file-size: 512M
    innodb-flush-log-at-trx-commit: 1
    innodb-lock-wait-timeout: 50
    max-connections: 1000
    query-cache-size: 64M
    query-cache-limit: 2M
    thread-cache-size: 8
    max-allowed-packet: 16M
    character-set-server: utf8
    collation-server: utf8_general_ci
EOF
print_success "MySQL tuning configuration created"

print_step "6.2" "Applying MySQL tuning"
execute_command "juju config mysql --file=mysql-tuning.yaml"

###############################################################
# PART 7: CREATE RELATIONS
###############################################################
print_section_header "PART 7: CREATING SERVICE RELATIONS"

print_step "7.1" "Creating relations for additional dashboards"
execute_command "juju add-relation skyline:identity-service keystone:identity-service"
execute_command "juju add-relation kitti:identity-service keystone:identity-service"
execute_command "juju add-relation kitti:shared-db mysql:shared-db"

print_step "7.2" "Creating relations for database services"
execute_command "juju add-relation trove:shared-db mysql:shared-db"
execute_command "juju add-relation trove:amqp rabbitmq-server:amqp"
execute_command "juju add-relation trove:identity-service keystone:identity-service"

print_step "7.3" "Creating relations for storage services"
execute_command "juju add-relation swift-proxy:shared-db mysql:shared-db"
execute_command "juju add-relation swift-proxy:identity-service keystone:identity-service"
execute_command "juju add-relation swift-proxy:swift-storage swift-storage:swift-storage"
execute_command "juju add-relation manila:shared-db mysql:shared-db"
execute_command "juju add-relation manila:amqp rabbitmq-server:amqp"
execute_command "juju add-relation manila:identity-service keystone:identity-service"

print_step "7.4" "Creating relations for compute services"
execute_command "juju add-relation zun:shared-db mysql:shared-db"
execute_command "juju add-relation zun:amqp rabbitmq-server:amqp"
execute_command "juju add-relation zun:identity-service keystone:identity-service"
execute_command "juju add-relation zun:compute-api nova-cloud-controller:cloud-compute-api"

print_step "7.5" "Creating relations for network services"
execute_command "juju add-relation octavia:shared-db mysql:shared-db"
execute_command "juju add-relation octavia:amqp rabbitmq-server:amqp"
execute_command "juju add-relation octavia:identity-service keystone:identity-service"
execute_command "juju add-relation octavia:neutron-api neutron-api:neutron-api"
execute_command "juju add-relation designate:shared-db mysql:shared-db"
execute_command "juju add-relation designate:amqp rabbitmq-server:amqp"
execute_command "juju add-relation designate:identity-service keystone:identity-service"

print_step "7.6" "Creating relations for backup services"
execute_command "juju add-relation freezer:shared-db mysql:shared-db"
execute_command "juju add-relation freezer:identity-service keystone:identity-service"

print_step "7.7" "Creating relations for bare metal services"
execute_command "juju add-relation ironic-api:shared-db mysql:shared-db"
execute_command "juju add-relation ironic-api:amqp rabbitmq-server:amqp"
execute_command "juju add-relation ironic-api:identity-service keystone:identity-service"
execute_command "juju add-relation ironic-conductor:shared-db mysql:shared-db"
execute_command "juju add-relation ironic-conductor:amqp rabbitmq-server:amqp"
execute_command "juju add-relation ironic-conductor:identity-service keystone:identity-service"
execute_command "juju add-relation ironic-conductor:image-service glance:image-service"
execute_command "juju add-relation ironic-api:api-service ironic-conductor:api-service"
execute_command "juju add-relation ironic-conductor:tftp-service tftp:tftp-service"
execute_command "juju add-relation ironic-conductor:http-service apache2:website"
execute_command "juju add-relation ironic-api:neutron-api neutron-api:neutron-api"
execute_command "juju add-relation ironic-conductor:neutron-api neutron-api:neutron-api"
execute_command "juju add-relation nova-compute:ironic-api ironic-api:compute-service"

###############################################################
# PART 8: SET UP DATABASE BACKUP CRON JOB
###############################################################
print_section_header "PART 8: SETTING UP DATABASE BACKUP"

print_step "8.1" "Creating MySQL backup script"
cat > /usr/local/bin/backup-mysql.sh << 'EOF'
#!/bin/bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="/var/lib/backup/mysql"
mkdir -p $BACKUP_DIR

# Hot backup using mysqldump
mysqldump --defaults-file=/etc/mysql/debian.cnf --all-databases --single-transaction | gzip > $BACKUP_DIR/all-databases-$TIMESTAMP.sql.gz

# Backup individual databases
for DB in nova keystone glance neutron cinder trove zun octavia designate kitti; do
  mysqldump --defaults-file=/etc/mysql/debian.cnf --single-transaction $DB | gzip > $BACKUP_DIR/$DB-$TIMESTAMP.sql.gz
done

# Remove backups older than 7 days
find $BACKUP_DIR -name "*.sql.gz" -type f -mtime +7 -delete
EOF
print_success "Backup script created"

print_step "8.2" "Making backup script executable"
execute_command "chmod +x /usr/local/bin/backup-mysql.sh"

print_step "8.3" "Adding backup to crontab"
echo "0 3 * * * /usr/local/bin/backup-mysql.sh" | tee -a /etc/crontab
print_success "Backup added to crontab (daily at 3 AM)"

###############################################################
# PART 9: MONITOR DEPLOYMENT
###############################################################
print_section_header "PART 9: MONITORING DEPLOYMENT"

print_step "9.1" "Checking deployment status"
execute_command "juju status --format=yaml"

###############################################################
# PART 10: ADDITIONAL CONFIGURATION
###############################################################
print_section_header "PART 10: ADDITIONAL CONFIGURATION"

print_step "10.1" "Configuring network settings"
execute_command "juju config neutron-api flat-network-providers=physnet1"
execute_command "juju config neutron-gateway bridge-mappings='physnet1:br-ex'"

print_step "10.2" "Configuring Cinder tiers"
execute_command "juju config cinder storage-backend=lvm"
execute_command "juju config cinder volume-group='tier1-vg'"
execute_command "juju config cinder storage-pools='fast:tier1-vg,standard:tier2-vg,value:tier3-vg'"

print_step "10.3" "Configuring Ironic network"
execute_command "juju config ironic-conductor provisioning-network='10.0.0.0/24'"
execute_command "juju config ironic-conductor cleaning-network='10.0.0.0/24'"

print_step "10.4" "Configuring Kitti billing"
execute_command "juju config kitti rate-standard=0.05"
execute_command "juju config kitti rate-premium=0.10"
execute_command "juju config kitti billing-cycle='monthly'"

###############################################################
# PART 11: VERIFY INSTALLATION
###############################################################
print_section_header "PART 11: VERIFY INSTALLATION"

print_step "11.1" "Installing OpenStack client"
execute_command "snap install openstackclients --classic"

print_step "11.2" "Creating admin credentials file"
cat > ~/adminrc << 'EOF'
export OS_USERNAME=admin
export OS_PASSWORD=openstack
export OS_TENANT_NAME=admin
export OS_PROJECT_NAME=admin
export OS_AUTH_URL=http://localhost:5000/v3
export OS_IDENTITY_API_VERSION=3
export OS_USER_DOMAIN_NAME=Default
export OS_PROJECT_DOMAIN_NAME=Default
EOF
print_success "Admin credentials file created at ~/adminrc"

print_step "11.3" "Sourcing credentials"
execute_command "source ~/adminrc"

print_step "11.4" "Verifying services"
execute_command "openstack service list"
execute_command "openstack compute service list"
execute_command "openstack volume service list"
execute_command "openstack network agent list"
execute_command "openstack baremetal node list"

###############################################################
# COMPLETION
###############################################################
print_section_header "INSTALLATION COMPLETE"

echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║       OPENSTACK DEPLOYMENT COMPLETED                  ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}Your OpenStack deployment has been installed and configured.${NC}"
echo ""
echo -e "${YELLOW}Summary of installed components:${NC}"
echo " • Core Services: Keystone, Nova, Neutron, Glance, Cinder, Horizon"
echo " • Additional Services: Swift, Manila, Trove, Zun, Octavia, Designate, Ironic"
echo " • Dashboard Services: Horizon, Skyline, Kitti"
echo " • Backup Services: Freezer, MySQL automated backups"
echo ""
echo -e "${GREEN}Access your OpenStack dashboard:${NC}"
echo " 1. Find the Horizon IP with: juju status horizon"
echo " 2. Open in browser: http://<HORIZON_IP>/horizon"
echo " 3. Login with admin / openstack"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo " • Create projects and users"
echo " • Configure networking (external networks, routers)"
echo " • Upload images to Glance"
echo " • Create flavors for VM instances"
echo " • Test compute and storage functionality"
echo ""
echo -e "${CYAN}For more information, refer to:${NC}"
echo " • OpenStack Documentation: https://docs.openstack.org"
echo " • Juju Documentation: https://juju.is/docs"
echo " • Log file: $LOG_FILE"
echo ""
echo -e "${GREEN}Thank you for using the OpenStack Automated Installer!${NC}"

# Exit successfully
exit 0
