# Create a script to allow Juju-managed services
cat > /usr/local/bin/juju-firewall-setup.sh << 'EOF'
#!/bin/bash

# Get Juju machine IPs
JUJU_MACHINES=$(juju machines --format=json | jq -r '.machines[].addresses[]' | sort -u)

# Allow communication between Juju machines
for ip in $JUJU_MACHINES; do
    ufw allow from $ip
    echo "Added firewall rule for Juju machine: $ip"
done

# Allow Juju controller access
CONTROLLER_IP=$(juju show-controller --format=json | jq -r '.["$(juju whoami --format=json | jq -r '.controller')"].details."api-endpoints"[]' | cut -d: -f1)
ufw allow from $CONTROLLER_IP
echo "Added firewall rule for Juju controller: $CONTROLLER_IP"
EOF

chmod +x /usr/local/bin/juju-firewall-setup.sh
/usr/local/bin/juju-firewall-setup.sh