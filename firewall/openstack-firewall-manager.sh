#!/bin/bash
cat > /usr/local/bin/openstack-firewall-manager.sh << 'EOF'
#!/bin/bash

# OpenStack Firewall Management Script

function show_status() {
    echo "=== UFW Status ==="
    ufw status verbose
    
    echo -e "\n=== IPv6 Tables ==="
    ip6tables -L -n
    echo -e "\n=== OpenStack Security Groups ==="
    openstack security group list
}

function reset_firewall() {
    echo "Resetting firewall to safe defaults..."
    ufw --force reset
    ufw default deny incoming
    ufw default allow outgoing
    ufw allow 22/tcp
    ufw --force enable
}

function setup_openstack_rules() {
    echo "Setting up OpenStack-specific firewall rules..."
    
    # Core OpenStack services
    ufw allow 5000/tcp   # Keystone
    ufw allow 9292/tcp   # Glance
    ufw allow 8774/tcp   # Nova
    ufw allow 8776/tcp   # Cinder
    ufw allow 9696/tcp   # Neutron
    ufw allow 80/tcp     # Horizon
    ufw allow 443/tcp    # Horizon HTTPS
    
    # Internal network access
    ufw allow from 10.10.0.0/16
    ufw allow from 192.168.0.0/24
    ufw allow from 172.16.0.0/24
    ufw allow from 2600:1700:5adb::/48
    
    echo "OpenStack firewall rules applied."
}

function check_connectivity() {
    echo "Checking OpenStack service connectivity..."
    
    services=("keystone:5000" "glance:9292" "nova:8774" "neutron:9696")
    
    for service in "${services[@]}"; do
        name=$(echo $service | cut -d: -f1)
        port=$(echo $service | cut -d: -f2)
        
        if netstat -tuln | grep -q ":$port "; then
            echo "✓ $name service is listening on port $port"
        else
            echo "✗ $name service is NOT listening on port $port"
        fi
    done
}

case "$1" in
    status)
        show_status
        ;;
    reset)
        reset_firewall
        ;;
    setup)
        setup_openstack_rules
        ;;
    check)
        check_connectivity
        ;;
    *)
        echo "Usage: $0 {status|reset|setup|check}"
        echo "  status - Show current firewall status"
        echo "  reset  - Reset firewall to safe defaults"
        echo "  setup  - Apply OpenStack firewall rules"
        echo "  check  - Check OpenStack service connectivity"
        exit 1
        ;;
esac

chmod +x /usr/local/bin/openstack-firewall-manager.sh