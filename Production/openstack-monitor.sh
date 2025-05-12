#!/bin/bash

#####################################################
#                                                   #
#       OpenStack Monitoring & Status Script        #
#                                                   #
#####################################################

# Color codes
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
print_header() {
    echo -e "\n${BOLD}${BLUE}==============================================${NC}"
    echo -e "${BOLD}${BLUE}   $1${NC}"
    echo -e "${BOLD}${BLUE}==============================================${NC}\n"
}

print_section() {
    echo -e "\n${BOLD}${CYAN}$1${NC}"
    echo -e "${CYAN}$(printf '=%.0s' $(seq 1 ${#1}))${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

# Check if juju is installed
if ! command -v juju &> /dev/null; then
    print_error "Juju is not installed. Please install it first."
    exit 1
fi

# Check if OpenStack clients are installed
if ! command -v openstack &> /dev/null; then
    print_warning "OpenStack client is not installed. Some checks will be skipped."
    OPENSTACK_CLIENT=false
else
    OPENSTACK_CLIENT=true
fi

# Display welcome message
clear
echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║       OPENSTACK MONITORING & STATUS CHECKER           ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Source OpenStack credentials if available
if [ -f ~/adminrc ]; then
    source ~/adminrc
    print_success "Sourced OpenStack credentials from ~/adminrc"
else
    print_warning "OpenStack credentials file not found. Some checks will be limited."
fi

#####################################################
# DEPLOYMENT STATUS
#####################################################
print_header "JUJU DEPLOYMENT STATUS"

echo -e "${YELLOW}Checking Juju controller status...${NC}"
juju controllers

echo -e "\n${YELLOW}Checking overall model status...${NC}"
juju status --format=short

#####################################################
# SERVICE STATUS
#####################################################
print_header "OPENSTACK SERVICE STATUS"

# Function to check service status using juju
check_juju_service() {
    local service=$1
    echo -e "\n${CYAN}Checking $service status:${NC}"
    juju status $service --format=yaml | grep -E 'status:|message:'
    
    # Check relations
    echo -e "${CYAN}$service relations:${NC}"
    juju show-application $service | grep -A 5 relations
}

# Core services to check
core_services=(
    "mysql"
    "rabbitmq-server"
    "keystone"
    "glance"
    "nova-cloud-controller"
    "nova-compute"
    "neutron-api"
    "neutron-gateway"
    "cinder"
    "horizon"
)

# Additional services to check
additional_services=(
    "skyline"
    "trove"
    "swift-proxy"
    "swift-storage"
    "manila"
    "zun"
    "octavia"
    "designate"
    "freezer"
    "kitti"
    "ironic-api"
    "ironic-conductor"
)

print_section "CORE SERVICES"
for service in "${core_services[@]}"; do
    check_juju_service $service
done

print_section "ADDITIONAL SERVICES"
for service in "${additional_services[@]}"; do
    # Check if service exists before querying
    if juju status $service --format=yaml 2>/dev/null | grep -q 'status:'; then
        check_juju_service $service
    else
        print_warning "$service not deployed, skipping"
    fi
done

#####################################################
# OPENSTACK VERIFICATION
#####################################################
if [ "$OPENSTACK_CLIENT" = true ]; then
    print_header "OPENSTACK API VERIFICATION"
    
    # Check OpenStack services
    print_section "SERVICE CATALOG"
    openstack service list
    
    print_section "COMPUTE SERVICES"
    openstack compute service list
    
    print_section "VOLUME SERVICES"
    openstack volume service list
    
    print_section "NETWORK AGENTS"
    openstack network agent list
    
    print_section "HYPERVISORS"
    openstack hypervisor list
    
    # Check for resources
    print_section "CURRENT RESOURCES"
    
    echo -e "${CYAN}Images:${NC}"
    openstack image list
    
    echo -e "\n${CYAN}Flavors:${NC}"
    openstack flavor list
    
    echo -e "\n${CYAN}Networks:${NC}"
    openstack network list
    
    echo -e "\n${CYAN}Volumes:${NC}"
    openstack volume list
    
    echo -e "\n${CYAN}Instances:${NC}"
    openstack server list
    
    # If Ironic is deployed, check baremetal nodes
    if juju status ironic-api --format=yaml 2>/dev/null | grep -q 'status:'; then
        echo -e "\n${CYAN}Baremetal Nodes:${NC}"
        openstack baremetal node list
    fi
fi

#####################################################
# SYSTEM RESOURCES
#####################################################
print_header "SYSTEM RESOURCES"

print_section "STORAGE STATUS"
echo -e "${CYAN}Logical Volumes:${NC}"
sudo lvs

echo -e "\n${CYAN}Volume Groups:${NC}"
sudo vgs

echo -e "\n${CYAN}Mount Points:${NC}"
df -h | grep -E '/var/lib/(database|messaging|compute|network|dashboard|storage|identity|backup)'

print_section "SYSTEM LOAD"
echo -e "${CYAN}CPU Usage:${NC}"
top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1"%"}'

echo -e "\n${CYAN}Memory Usage:${NC}"
free -h

echo -e "\n${CYAN}Disk I/O:${NC}"
iostat -xh 1 1 | grep -v "^$" | grep -v "avg-cpu"

#####################################################
# LOGS SUMMARY
#####################################################
print_header "RECENT LOG ENTRIES"

# Function to display recent logs
show_recent_logs() {
    local service=$1
    local log_path=$2
    
    if [ -f "$log_path" ]; then
        echo -e "${CYAN}Recent logs for $service:${NC}"
        tail -n 10 "$log_path" | grep -E 'ERROR|CRITICAL|WARNING|FATAL' --color=auto
    else
        print_warning "Log file for $service not found at $log_path"
    fi
}

# Check for common OpenStack logs
log_files=(
    "keystone:/var/log/keystone/keystone.log"
    "nova-api:/var/log/nova/nova-api.log"
    "glance-api:/var/log/glance/glance-api.log"
    "neutron-server:/var/log/neutron/neutron-server.log"
    "cinder-api:/var/log/cinder/cinder-api.log"
    "horizon:/var/log/apache2/horizon_error.log"
)

for log in "${log_files[@]}"; do
    IFS=':' read -r service log_path <<< "$log"
    show_recent_logs "$service" "$log_path"
    echo ""
done

#####################################################
# SUMMARY
#####################################################
print_header "MONITORING SUMMARY"

echo -e "${BOLD}${GREEN}"
echo "╔═══════════════════════════════════════════════════════╗"
echo "║                                                       ║"
echo "║       OPENSTACK MONITORING COMPLETED                  ║"
echo "║                                                       ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${CYAN}Your OpenStack deployment has been checked.${NC}"
echo ""
echo -e "${YELLOW}To view specific logs from Juju services:${NC}"
echo " • juju debug-log -i <service-name>"
echo ""
echo -e "${YELLOW}To access the various dashboards:${NC}"
echo " • Horizon: http://<horizon-ip>/horizon"
echo " • Skyline: http://<skyline-ip>/"
echo " • Kitti: http://<kitti-ip>/"
echo ""
echo -e "${CYAN}Run this script periodically to monitor system health${NC}"