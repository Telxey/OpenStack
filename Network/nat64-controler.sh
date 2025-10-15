# Install Jool (NAT64 implementation)
sudo apt-get update
sudo apt-get install -y jool-dkms jool-tools

# Load the required kernel modules
sudo modprobe jool
sudo echo "jool" >> /etc/modules

# Create NAT64 configuration script
sudo cat > /usr/local/bin/configure-nat64.sh << 'EOF'
#!/bin/bash

# Define the IPv6 prefix for NAT64 (Using a well-known prefix)
NAT64_PREFIX="64:ff9b::/96"

# Configure instance pool
jool instance add --iptables --pool6 $NAT64_PREFIX

# Configure IPv4 address pool
jool -i "--pool4=<YOUR_IPV4_ADDRESS>/32"

# Enable IPv4/IPv6 forwarding
sysctl -w net.ipv4.ip_forward=1
sysctl -w net.ipv6.conf.all.forwarding=1


# Save settings
sudo cat > /etc/sysctl.d/99-nat64.conf << EOL
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOL

# Add iptables rules for NAT64
iptables -t nat -A POSTROUTING -s <YOUR_IPV4_NETWORK> -j MASQUERADE
EOF

# Replace placeholders with your actual values
sudo sed -i 's/<YOUR_IPV4_ADDRESS>/192.168.0.55/g' /usr/local/bin/configure-nat64.sh
sudo sed -i 's/<YOUR_IPV4_NETWORK>/10.10.0.0\/16/g' /usr/local/bin/configure-nat64.sh

# Make the script executable
sudo chmod +x /usr/local/bin/configure-nat64.sh

# Run the configuration script

sudo /usr/local/bin/configure-nat64.sh

# Make it run at boot
sudo cat > /etc/systemd/system/nat64.service << EOF
[Unit]
Description=NAT64 Configuration Service
After=network.target

[Service]
Type=oneshot
ExecStart=/usr/local/bin/configure-nat64.sh
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

# Enable the service
sudo systemctl enable nat64.service
sudo systemctl start nat64.service
sudo systemctl status nat64.service