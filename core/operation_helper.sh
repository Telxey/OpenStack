#!/bin/bash

#####################################################
#                                                   #
#       OpenStack Operations Helper Script          #
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
    echo -e "${BOLD}${BLUE}=============================================${NC}"
    echo -e "${BOLD}${BLUE}   $1${NC}"
    echo -e "${BOLD}${BLUE}=============================================${NC}"
}

print_menu_item() {
    echo -e "${BOLD}${CYAN}$1)${NC} ${WHITE}$2${NC}"
}

print_submenu_item() {
    echo -e "   ${CYAN}$1)${NC} ${WHITE}$2${NC}"
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

# Check if OpenStack clients are installed
if ! command -v openstack &> /dev/null; then
    print_error "OpenStack client is not installed. Please install it first with:"
    echo "sudo snap install openstackclients --classic"
    exit 1
fi

# Source OpenStack credentials if available
if [ -f ~/adminrc ]; then
    source ~/adminrc
    print_success "Sourced OpenStack credentials from ~/adminrc"
else
    print_warning "OpenStack credentials file not found at ~/adminrc"
    print_warning "Creating a basic template..."
    
    # Create a basic credentials file
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
    
    print_success "Created admin credentials file at ~/adminrc"
    print_warning "Please update this file with your actual OpenStack credentials"
    source ~/adminrc
fi

#####################################################
# MAIN MENU FUNCTIONS
#####################################################

# 1. Identity Management
menu_identity() {
    clear
    print_header "IDENTITY MANAGEMENT"
    
    while true; do
        echo -e "${BOLD}${WHITE}Identity Management Options:${NC}"
        print_submenu_item "1" "List Users"
        print_submenu_item "2" "Create New User"
        print_submenu_item "3" "List Projects"
        print_submenu_item "4" "Create New Project"
        print_submenu_item "5" "List Roles"
        print_submenu_item "6" "Assign Role to User in Project"
        print_submenu_item "0" "Return to Main Menu"
        echo \"\"
        
        read -p \"Select an option: \" choice
        
        case $choice in
            1) # List Users
                echo -e \"\
${CYAN}All Users:${NC}\"
                openstack user list
                ;;
                
            2) # Create User
                echo -e \"\
${CYAN}Create New User:${NC}\"
                read -p \"Enter username: \" username
                read -sp \"Enter password: \" password
                echo \"\"
                read -p \"Enter email (optional): \" email
                
                if [ -z \"$email\" ]; then
                    openstack user create --password \"$password\" \"$username\"
                else
                    openstack user create --password \"$password\" --email \"$email\" \"$username\"
                fi
                print_success \"User $username created successfully\"
                ;;
                
            3) # List Projects
                echo -e \"\
${CYAN}All Projects:${NC}\"
                openstack project list
                ;;
                
            4) # Create Project
                echo -e \"\
${CYAN}Create New Project:${NC}\"
                read -p \"Enter project name: \" project
                read -p \"Enter description (optional): \" description
                
                if [ -z \"$description\" ]; then
                    openstack project create \"$project\"
                else
                    openstack project create --description \"$description\" \"$project\"
                fi
                print_success \"Project $project created successfully\"
                ;;
                
            5) # List Roles
                echo -e \"\
${CYAN}Available Roles:${NC}\"
                openstack role list
                ;;
                
            6) # Assign Role
                echo -e \"\
${CYAN}Assign Role to User:${NC}\"
                echo \"Available users:\"
                openstack user list -f value -c ID -c Name
                read -p \"Enter user name or ID: \" user
                
                echo \"Available projects:\"
                openstack project list -f value -c ID -c Name
                read -p \"Enter project name or ID: \" project
                
                echo \"Available roles:\"
                openstack role list -f value -c ID -c Name
                read -p \"Enter role name or ID: \" role
                
                openstack role add --user \"$user\" --project \"$project\" \"$role\"
                print_success \"Role $role assigned to user $user in project $project\"
                ;;
                
            0) # Return to main menu
                return
                ;;
                
            *) print_error \"Invalid option\"
                ;;
        esac
        
        echo \"\"
        read -p \"Press Enter to continue...\"
    done
}

# 2. Compute Management
menu_compute() {
    clear
    print_header \"COMPUTE MANAGEMENT\"
    
    while true; do
        echo -e \"${BOLD}${WHITE}Compute Management Options:${NC}\"
        print_submenu_item \"1\" \"List Instances\"
        print_submenu_item \"2\" \"Create New Instance\"
        print_submenu_item \"3\" \"List Flavors\"
        print_submenu_item \"4\" \"Create New Flavor\"
        print_submenu_item \"5\" \"List Images\"
        print_submenu_item \"6\" \"Upload New Image\"
        print_submenu_item \"7\" \"List Hypervisors\"
        print_submenu_item \"8\" \"Show Compute Service Status\"
        print_submenu_item \"0\" \"Return to Main Menu\"
        echo \"\"
        
        read -p \"Select an option: \" choice
        
        case $choice in
            1) # List Instances
                echo -e \"\
${CYAN}All Instances:${NC}\"
                openstack server list --all-projects
                ;;
                
            2) # Create Instance
                echo -e \"\
${CYAN}Create New Instance:${NC}\"
                echo \"Available flavors:\"
                openstack flavor list
                read -p \"Enter flavor name or ID: \" flavor
                
                echo \"Available images:\"
                openstack image list
                read -p \"Enter image name or ID: \" image
                
                echo \"Available networks:\"
                openstack network list
                read -p \"Enter network name or ID: \" network
                
                read -p \"Enter instance name: \" name
                
                openstack server create --flavor \"$flavor\" --image \"$image\" --network \"$network\" \"$name\"
                print_success \"Server $name creation initiated\"
                ;;
                
            3) # List Flavors
                echo -e \"\
${CYAN}Available Flavors:${NC}\"
                openstack flavor list
                ;;
                
            4) # Create Flavor
                echo -e \"\
${CYAN}Create New Flavor:${NC}\"
                read -p \"Enter flavor name: \" name
                read -p \"Enter RAM size in MB: \" ram
                read -p \"Enter disk size in GB: \" disk
                read -p \"Enter vCPUs: \" vcpus
                
                openstack flavor create --ram \"$ram\" --disk \"$disk\" --vcpus \"$vcpus\" \"$name\"
                print_success \"Flavor $name created successfully\"
                ;;
                
            5) # List Images
                echo -e \"\
${CYAN}Available Images:${NC}\"
                openstack image list
                ;;
                
            6) # Upload Image
                echo -e \"\
${CYAN}Upload New Image:${NC}\"
                read -p \"Enter image name: \" name
                read -p \"Enter image file path: \" file
                read -p \"Enter disk format (qcow2, raw, etc.): \" format
                
                if [ ! -f \"$file\" ]; then
                    print_error \"File not found: $file\"
                else
                    openstack image create --file \"$file\" --disk-format \"$format\" --container-format bare \"$name\"
                    print_success \"Image $name upload initiated\"
                fi
                ;;
                
            7) # List Hypervisors
                echo -e \"\
${CYAN}Hypervisors:${NC}\"
                openstack hypervisor list
                
                read -p \"View detailed stats for a hypervisor? (y/n): \" view_details
                if [ \"$view_details\" == \"y\" ]; then
                    read -p \"Enter hypervisor ID: \" hypervisor_id
                    openstack hypervisor show \"$hypervisor_id\"
                fi
                ;;
                
            8) # Compute Status
                echo -e \"\
${CYAN}Compute Service Status:${NC}\"
                openstack compute service list
                ;;
                
            0) # Return to main menu
                return
                ;;
                
            *) print_error \"Invalid option\"
                ;;
        esac
        
        echo \"\"
        read -p \"Press Enter to continue...\"
    done
}

# 3. Storage Management
menu_storage() {
    clear
    print_header \"STORAGE MANAGEMENT\"
    
    while true; do
        echo -e \"${BOLD}${WHITE}Storage Management Options:${NC}\"
        print_submenu_item \"1\" \"List Volumes\"
        print_submenu_item \"2\" \"Create New Volume\"
        print_submenu_item \"3\" \"List Volume Types\"
        print_submenu_item \"4\" \"Create New Volume Type\"
        print_submenu_item \"5\" \"List Snapshots\"
        print_submenu_item \"6\" \"Create Volume Snapshot\"
        print_submenu_item \"7\" \"Attach Volume to Instance\"
        print_submenu_item \"8\" \"List Swift Containers\"
        print_submenu_item \"9\" \"Show Storage Service Status\"
        print_submenu_item \"0\" \"Return to Main Menu\"
        echo \"\"
        
        read -p \"Select an option: \" choice
        
        case $choice in
            1) # List Volumes
                echo -e \"\
${CYAN}All Volumes:${NC}\"
                openstack volume list --all-projects
                ;;
                
            2) # Create Volume
                echo -e \"\
${CYAN}Create New Volume:${NC}\"
                read -p \"Enter volume name: \" name
                read -p \"Enter size in GB: \" size
                
                echo \"Available volume types:\"
                openstack volume type list
                read -p \"Enter volume type (or leave empty for default): \" type
                
                if [ -z \"$type\" ]; then
                    openstack volume create --size \"$size\" \"$name\"
                else
                    openstack volume create --size \"$size\" --type \"$type\" \"$name\"
                fi
                print_success \"Volume $name creation initiated\"
                ;;
                
            3) # List Volume Types
                echo -e \"\
${CYAN}Available Volume Types:${NC}\"
                openstack volume type list
                ;;
                
            4) # Create Volume Type
                echo -e \"\
${CYAN}Create New Volume Type:${NC}\"
                read -p \"Enter volume type name: \" name
                
                openstack volume type create \"$name\"
                print_success \"Volume type $name created successfully\"
                
                read -p \"Add extra specs? (y/n): \" add_specs
                if [ \"$add_specs\" == \"y\" ]; then
                    read -p \"Enter key (e.g., volume_backend_name): \" key
                    read -p \"Enter value: \" value
                    
                    openstack volume type set --property \"$key\"=\"$value\" \"$name\"
                    print_success \"Added property $key=$value to volume type $name\"
                fi
                ;;
                
            5) # List Snapshots
                echo -e \"\
${CYAN}All Volume Snapshots:${NC}\"
                openstack volume snapshot list --all-projects
                ;;
                
            6) # Create Snapshot
                echo -e \"\
${CYAN}Create Volume Snapshot:${NC}\"
                echo \"Available volumes:\"
                openstack volume list
                read -p \"Enter volume ID: \" volume_id
                read -p \"Enter snapshot name: \" name
                
                openstack volume snapshot create --volume \"$volume_id\" \"$name\"
                print_success \"Snapshot $name creation initiated\"
                ;;
                
            7) # Attach Volume
                echo -e \"\
${CYAN}Attach Volume to Instance:${NC}\"
                echo \"Available volumes:\"
                openstack volume list -f value -c ID -c Name -c Status | grep available
                read -p \"Enter volume ID: \" volume_id
                
                echo \"Available instances:\"
                openstack server list -f value -c ID -c Name
                read -p \"Enter server ID: \" server_id
                
                openstack server add volume \"$server_id\" \"$volume_id\"
                print_success \"Volume $volume_id attached to server $server_id\"
                ;;
                
            8) # List Swift Containers
                echo -e \"\
${CYAN}Swift Object Storage Containers:${NC}\"
                openstack container list
                
                read -p \"View objects in a container? (y/n): \" view_objects
                if [ \"$view_objects\" == \"y\" ]; then
                    read -p \"Enter container name: \" container
                    openstack object list \"$container\"
                fi
                ;;
                
            9) # Storage Status
                echo -e \"\
${CYAN}Storage Service Status:${NC}\"
                openstack volume service list
                ;;
                
            0) # Return to main menu
                return
                ;;
                
            *) print_error \"Invalid option\"
                ;;
        esac
        
        echo \"\"
        read -p \"Press Enter to continue...\"
    done
}

# 4. Network Management
menu_network() {
    clear
    print_header \"NETWORK MANAGEMENT\"
    
    while true; do
        echo -e \"${BOLD}${WHITE}Network Management Options:${NC}\"
        print_submenu_item \"1\" \"List Networks\"
        print_submenu_item \"2\" \"Create New Network\"
        print_submenu_item \"3\" \"List Subnets\"
        print_submenu_item \"4\" \"Create New Subnet\"
        print_submenu_item \"5\" \"List Routers\"
        print_submenu_item \"6\" \"Create New Router\"
        print_submenu_item \"7\" \"List Security Groups\"
        print_submenu_item \"8\" \"Create Security Group Rule\"
        print_submenu_item \"9\" \"Show Network Service Status\"
        print_submenu_item \"0\" \"Return to Main Menu\"
        echo \"\"
        
        read -p \"Select an option: \" choice
        
        case $choice in
            1) # List Networks
                echo -e \"\
${CYAN}All Networks:${NC}\"
                openstack network list
                ;;
                
            2) # Create Network
                echo -e \"\
${CYAN}Create New Network:${NC}\"
                read -p \"Enter network name: \" name
                
                openstack network create \"$name\"
                print_success \"Network $name created successfully\"
                ;;
                
            3) # List Subnets
                echo -e \"\
${CYAN}All Subnets:${NC}\"
                openstack subnet list
                ;;
                
            4) # Create Subnet
                echo -e \"\
${CYAN}Create New Subnet:${NC}\"
                echo \"Available networks:\"
                openstack network list
                read -p \"Enter network ID: \" network_id
                read -p \"Enter subnet name: \" name
                read -p \"Enter CIDR (e.g., 192.168.1.0/24): \" cidr
                
                openstack subnet create --network \"$network_id\" --subnet-range \"$cidr\" \"$name\"
                print_success \"Subnet $name created successfully\"
                ;;
                
            5) # List Routers
                echo -e \"\
${CYAN}All Routers:${NC}\"
                openstack router list
                ;;
                
            6) # Create Router
                echo -e \"\
${CYAN}Create New Router:${NC}\"
                read -p \"Enter router name: \" name
                
                openstack router create \"$name\"
                print_success \"Router $name created successfully\"
                
                read -p \"Add external gateway? (y/n): \" add_gateway
                if [ \"$add_gateway\" == \"y\" ]; then
                    echo \"External networks:\"
                    openstack network list --external
                    read -p \"Enter external network ID: \" ext_net
                    
                    openstack router set --external-gateway \"$ext_net\" \"$name\"
                    print_success \"External gateway set to $ext_net\"
                fi
                
                read -p \"Add subnet interface? (y/n): \" add_interface
                if [ \"$add_interface\" == \"y\" ]; then
                    echo \"Available subnets:\"
                    openstack subnet list
                    read -p \"Enter subnet ID: \" subnet_id
                    
                    openstack router add subnet \"$name\" \"$subnet_id\"
                    print_success \"Subnet $subnet_id added to router $name\"
                fi
                ;;
                
            7) # List Security Groups
                echo -e \"\
${CYAN}Security Groups:${NC}\"
                openstack security group list
                
                read -p \"View rules for a security group? (y/n): \" view_rules
                if [ \"$view_rules\" == \"y\" ]; then
                    read -p \"Enter security group ID: \" sg_id
                    openstack security group rule list \"$sg_id\"
                fi
                ;;
                
            8) # Create Security Group Rule
                echo -e \"\
${CYAN}Create Security Group Rule:${NC}\"
                echo \"Available security groups:\"
                openstack security group list
                read -p \"Enter security group ID: \" sg_id
                
                echo -e \"\
Select protocol:\"
                print_submenu_item \"1\" \"TCP\"
                print_submenu_item \"2\" \"UDP\"
                print_submenu_item \"3\" \"ICMP\"
                read -p \"Enter choice (1-3): \" proto_choice
                
                case $proto_choice in
                    1) protocol=\"tcp\" ;;
                    2) protocol=\"udp\" ;;
                    3) protocol=\"icmp\" ;;
                    *) print_error \"Invalid choice, defaulting to tcp\"; protocol=\"tcp\" ;;
                esac
                
                if [ \"$protocol\" != \"icmp\" ]; then
                    read -p \"Enter port range (e.g., 22, or 80:443): \" port_range
                    
                    # Check if port range contains a colon
                    if [[ $port_range == *:* ]]; then
                        IFS=':' read -r port_min port_max <<< \"$port_range\"
                    else
                        port_min=$port_range
                        port_max=$port_range
                    fi
                    
                    openstack security group rule create --protocol \"$protocol\" --dst-port \"$port_min:$port_max\" \"$sg_id\"
                else
                    openstack security group rule create --protocol \"$protocol\" \"$sg_id\"
                fi
                
                print_success \"Security group rule created successfully\"
                ;;
                
            9) # Network Status
                echo -e \"\
${CYAN}Network Service Status:${NC}\"
                openstack network agent list
                ;;
                
            0) # Return to main menu
                return
                ;;
                
            *) print_error \"Invalid option\"
                ;;
        esac
        
        echo \"\"
        read -p \"Press Enter to continue...\"
    done
}

# 5. Baremetal Management (Ironic)
menu_baremetal() {
    clear
    print_header \"BAREMETAL MANAGEMENT (IRONIC)\"
    
    # Check if Ironic is available
    if ! openstack baremetal node list &>/dev/null; then
        print_error \"Ironic (baremetal) service is not available or not properly configured\"
        read -p \"Press Enter to return to main menu...\"
        return
    fi
    
    while true; do
        echo -e \"${BOLD}${WHITE}Baremetal Management Options:${NC}\"
        print_submenu_item \"1\" \"List Baremetal Nodes\"
        print_submenu_item \"2\" \"Create New Baremetal Node\"
        print_submenu_item \"3\" \"List Baremetal Ports\"
        print_submenu_item \"4\" \"Create Baremetal Port\"
        print_submenu_item \"5\" \"Manage Node Power State\"
        print_submenu_item \"6\" \"Set Node Maintenance Mode\"
        print_submenu_item \"7\" \"Show Detailed Node Info\"
        print_submenu_item \"8\" \"Show Ironic Service Status\"
        print_submenu_item \"0\" \"Return to Main Menu\"
        echo \"\"
        
        read -p \"Select an option: \" choice
        
        case $choice in
            1) # List Nodes
                echo -e \"\
${CYAN}All Baremetal Nodes:${NC}\"
                openstack baremetal node list
                ;;
                
            2) # Create Node
                echo -e \"\
${CYAN}Create New Baremetal Node:${NC}\"
                read -p \"Enter node name: \" name
                
                echo -e \"\
Select driver type:\"
                print_submenu_item \"1\" \"IPMI\"
                print_submenu_item \"2\" \"Redfish\"
                read -p \"Enter choice (1-2): \" driver_choice
                
                case $driver_choice in
                    1) driver=\"ipmi\" ;;
                    2) driver=\"redfish\" ;;
                    *) print_error \"Invalid choice, defaulting to ipmi\"; driver=\"ipmi\" ;;
                esac
                
                openstack baremetal node create --name \"$name\" --driver \"$driver\"
                print_success \"Baremetal node $name created with $driver driver\"
                
                read -p \"Set driver information now? (y/n): \" set_driver_info
                if [ \"$set_driver_info\" == \"y\" ]; then
                    if [ \"$driver\" == \"ipmi\" ]; then
                        read -p \"Enter IPMI address: \" ipmi_address
                        read -p \"Enter IPMI username: \" ipmi_username
                        read -sp \"Enter IPMI password: \" ipmi_password
                        echo \"\"
                        
                        openstack baremetal node set \"$name\" \\
                            --driver-info ipmi_address=\"$ipmi_address\" \\
                            --driver-info ipmi_username=\"$ipmi_username\" \\
                            --driver-info ipmi_password=\"$ipmi_password\"
                    else
                        # Redfish
                        read -p \"Enter Redfish address: \" redfish_address
                        read -p \"Enter Redfish system ID: \" redfish_system_id
                        read -p \"Enter Redfish username: \" redfish_username
                        read -sp \"Enter Redfish password: \" redfish_password
                        echo \"\"
                        
                        openstack baremetal node set \"$name\" \\
                            --driver-info redfish_address=\"$redfish_address\" \\
                            --driver-info redfish_system_id=\"$redfish_system_id\" \\
                            --driver-info redfish_username=\"$redfish_username\" \\
                            --driver-info redfish_password=\"$redfish_password\"
                    fi
                    print_success \"Driver information set for node $name\"
                fi
                ;;
                
            3) # List Ports
                echo -e \"\
${CYAN}All Baremetal Ports:${NC}\"
                openstack baremetal port list
                ;;
                
            4) # Create Port
                echo -e \"\
${CYAN}Create Baremetal Port:${NC}\"
                echo \"Available nodes:\"
                openstack baremetal node list -f value -c UUID -c Name
                read -p \"Enter node UUID: \" node_uuid
                read -p \"Enter MAC address (format: 11:22:33:44:55:66): \" mac_address
                
                openstack baremetal port create --node \"$node_uuid\" \"$mac_address\"
                print_success \"Port with MAC $mac_address created for node $node_uuid\"
                ;;
                
            5) # Power Management
                echo -e \"\
${CYAN}Manage Node Power State:${NC}\"
                echo \"Available nodes:\"
                openstack baremetal node list -f value -c UUID -c Name -c \"Power State\"
                read -p \"Enter node UUID or name: \" node
                
                echo -e \"\
Select power state:\"
                print_submenu_item \"1\" \"Power On\"
                print_submenu_item \"2\" \"Power Off\"
                print_submenu_item \"3\" \"Reboot\"
                read -p \"Enter choice (1-3): \" power_choice
                
                case $power_choice in
                    1) state=\"on\" ;;
                    2) state=\"off\" ;;
                    3) state=\"reboot\" ;;
                    *) print_error \"Invalid choice\"; continue ;;
                esac
                
                openstack baremetal node power \"$state\" \"$node\"
                print_success \"Power $state command sent to node $node\"
                ;;
                
            6) # Maintenance Mode
                echo -e \"\
${CYAN}Set Node Maintenance Mode:${NC}\"
                echo \"Available nodes:\"
                openstack baremetal node list -f value -c UUID -c Name -c \"Maintenance\"
                read -p \"Enter node UUID or name: \" node
                
                echo -e \"\
Maintenance mode:\"
                print_submenu_item \"1\" \"Enable maintenance\"
                print_submenu_item \"2\" \"Disable maintenance\"
                read -p \"Enter choice (1-2): \" maint_choice
                
                case $maint_choice in
                    1) 
                        read -p \"Enter maintenance reason (optional): \" reason
                        if [ -z \"$reason\" ]; then
                            openstack baremetal node maintenance set \"$node\"
                        else
                            openstack baremetal node maintenance set \"$node\" --reason \"$reason\"
                        fi
                        print_success \"Maintenance mode enabled for node $node\"
                        ;;
                    2) 
                        openstack baremetal node maintenance unset \"$node\"
                        print_success \"Maintenance mode disabled for node $node\"
                        ;;
                    *) print_error \"Invalid choice\" ;;
                esac
                ;;
                
            7) # Node Details
                echo -e \"\
${CYAN}Show Detailed Node Info:${NC}\"
                echo \"Available nodes:\"
                openstack baremetal node list -f value -c UUID -c Name
                read -p \"Enter node UUID or name: \" node
                
                openstack baremetal node show \"$node\"
                ;;
                
            8) # Ironic Status
                echo -e \"\
${CYAN}Ironic Service Status:${NC}\"
                juju status ironic-api
                juju status ironic-conductor
                ;;
                
            0) # Return to main menu
                return
                ;;
                
            *) print_error \"Invalid option\"
                ;;
        esac
        
        echo \"\"
        read -p \"Press Enter to continue...\"
    done
}

# 6. Dashboard Information
menu_dashboard() {
    clear
    print_header \"DASHBOARD INFORMATION\"
    
    # Get dashboard URLs from Juju
    horizon_url=$(juju status horizon --format=json | jq -r '.applications.horizon.units | to_entries[0].value.\"public-address\"' 2>/dev/null)
    skyline_url=$(juju status skyline --format=json | jq -r '.applications.skyline.units | to_entries[0].value.\"public-address\"' 2>/dev/null)
    kitti_url=$(juju status kitti --format=json | jq -r '.applications.kitti.units | to_entries[0].value.\"public-address\"' 2>/dev/null)
    
    echo -e \"${BOLD}${WHITE}OpenStack Dashboard Access Information:${NC}\
\"
    
    if [ -n \"$horizon_url\" ]; then
        echo -e \"${CYAN}Horizon Dashboard:${NC}\"
        echo -e \"URL: ${GREEN}http://$horizon_url/horizon${NC}\"
        echo -e \"Default credentials: admin / openstack\"
        echo -e \"Features: Core OpenStack management interface\
\"
    else
        echo -e \"${YELLOW}Horizon Dashboard: Not found or not deployed${NC}\
\"
    fi
    
    if [ -n \"$skyline_url\" ]; then
        echo -e \"${CYAN}Skyline Dashboard:${NC}\"
        echo -e \"URL: ${GREEN}http://$skyline_url/${NC}\"
        echo -e \"Uses same credentials as Horizon\"
        echo -e \"Features: Modern UI alternative to Horizon\
\"
    else
        echo -e \"${YELLOW}Skyline Dashboard: Not found or not deployed${NC}\
\"
    fi
    
    if [ -n \"$kitti_url\" ]; then
        echo -e \"${CYAN}Kitti Dashboard:${NC}\"
        echo -e \"URL: ${GREEN}http://$kitti_url/${NC}\"
        echo -e \"Uses same credentials as Horizon\"
        echo -e \"Features: Billing and resource tracking\
\"
    else
        echo -e \"${YELLOW}Kitti Dashboard: Not found or not deployed${NC}\
\"
    fi
    
    echo -e \"${BOLD}${CYAN}Note:${NC} If using a private network, you may need to establish\"
    echo -e \"SSH tunnels to access these services remotely:\"
    echo -e \"${WHITE}  ssh -L 8080:$horizon_url:80 user@jumphost${NC}\"
    echo -e \"Then access locally via: http://localhost:8080\"
    
    read -p \"Press Enter to return to main menu...\"
}

# Main Menu Display
main_menu() {
    while true; do
        clear
        # Display ASCII art banner
        echo -e \"${BOLD}${GREEN}\"
        echo \"╔═══════════════════════════════════════════════════════╗\"
        echo \"║                                                       ║\"
        echo \"║       OPENSTACK OPERATIONS HELPER                     ║\"
        echo \"║                                                       ║\"
        echo \"╚═══════════════════════════════════════════════════════╝\"
        echo -e \"${NC}\"
        
        echo -e \"${CYAN}Current OpenStack Status:${NC}\"
        openstack endpoint list --service identity >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo -e \" ${GREEN}✓${NC} Connected to OpenStack (Keystone API responding)\"
        else
            echo -e \" ${RED}✗${NC} Not connected to OpenStack (Keystone API not responding)\"
            echo -e \" ${YELLOW}⚠${NC} Check your credentials in ~/adminrc\"
        fi
        echo \"\"
        
        echo -e \"${BOLD}${WHITE}Select an operation:${NC}\"
        print_menu_item "1" "Identity Management (Users, Projects, Roles)"
        print_menu_item "2" "Compute Management (Instances, Flavors, Images)"
        print_menu_item "3" "Storage Management (Volumes, Snapshots, Swift)"
        print_menu_item "4" "Network Management (Networks, Routers, Security)"
        print_menu_item "5" "Baremetal Management (Ironic)"
        print_menu_item "6" "Dashboard Information"
        print_menu_item "0" "Exit"
        echo ""
        
        read -p "Enter your choice: " choice
        
        case $choice in
            1) menu_identity ;;
            2) menu_compute ;;
            3) menu_storage ;;
            4) menu_network ;;
            5) menu_baremetal ;;
            6) menu_dashboard ;;
            0) 
                echo -e "${GREEN}Thank you for using OpenStack Operations Helper!${NC}"
                exit 0
                ;;
            *) 
                print_error "Invalid option"
                sleep 1
                ;;
        esac
    done
}

# Execute main menu
main_menu
