#!/bin/bash
# Post-deployment firewall configuration

# Wait for services to be deployed
echo "Waiting for OpenStack services to be ready..."
juju wait-for application keystone --query='name=="keystone" && (status=="active")'

# Apply firewall rules
/usr/local/bin/openstack-firewall-manager.sh setup

# Configure Juju-specific rules
/usr/local/bin/juju-firewall-setup.sh

# Check connectivity
/usr/local/bin/openstack-firewall-manager.sh check

echo "Firewall configuration completed."