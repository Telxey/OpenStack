#!/bin/bash

# Script to install essential network tools on Ubuntu-like systems

# Update package lists
echo "Updating package lists..."
sudo apt update

# List of packages to install
packages=(
  net-tools
  iproute2
  nmap
  dnsutils
  bind9-host
  iputils-arping
  traceroute
  iputils-tracepath
)

# Install the packages
echo "Installing network tools..."
for package in "${packages[@]}"; do
  echo "Installing $package..."
  sudo apt install -y "$package"
  if [ $? -ne 0 ]; then
    echo "Error installing $package. Exiting."
    exit 1
  fi
done

echo "All network tools installed successfully!"

# Optional: Verify installation (you can add more specific checks)
echo ""
echo "Verifying installation of some key tools:"
which nmap
which dig
which ip

echo 'Additional IPv6 Router Advertisement Configuration'

echo 'For proper IPv6 functionality with SLAAC, add this to a startup script or network configuration:'

# Enable IPv6 forwarding on appropriate interfaces
cat > /etc/sysctl.d/99-ipv6-forwarding.conf << EOF
net.ipv6.conf.all.forwarding=1
net.ipv6.conf.br-ext.accept_ra=2
net.ipv6.conf.br-int.accept_ra=2
net.ipv6.conf.br-extvm.accept_ra=2
EOF

# Apply settings
sysctl -p /etc/sysctl.d/99-ipv6-forwarding.conf

# Install and configure radvd for stateless IPv6 autoconfiguration
apt-get install -y radvd 

# Create radvd configuration
cat > /etc/radvd.conf << EOF
interface br-ext {
    AdvSendAdvert on;
    MinRtrAdvInterval 30;
    MaxRtrAdvInterval 100;
    AdvDefaultLifetime 9000;
    prefix 2600:1700:5adb:7000:300::/64 {
        AdvOnLink on;
        AdvAutonomous on;
        AdvRouterAddr on;
    };
};

interface br-int {
    AdvSendAdvert on;
    MinRtrAdvInterval 30;
    MaxRtrAdvInterval 100;
    AdvDefaultLifetime 9000;
    prefix 2600:1700:5adb:7009:200::/64 {
        AdvOnLink on;
        AdvAutonomous on;
        AdvRouterAddr on;
    };
};

interface br-extvm {
    AdvSendAdvert on;
    MinRtrAdvInterval 30;
    MaxRtrAdvInterval 100;
    AdvDefaultLifetime 9000;
    prefix 2600:1700:5adb:7009::/64 {
        AdvOnLink on;
        AdvAutonomous on;
        AdvRouterAddr on;
    };
};
EOF

# Enable and start radvd
systemctl enable radvd
systemctl restart radvd

