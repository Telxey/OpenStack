#!/bin/bash

echo '1. Juju Configuration with IPv6 Support'

# Configure Neutron in Juju to use your existing bridges with IPv6 support
juju config neutron-api flat-network-providers="physnet1,physnet2"
juju config neutron-gateway bridge-mappings="physnet1:br-ext,physnet2:br-int"

# Enable IPv6 support in Neutron
juju config neutron-api enable-ipv6=true
juju config neutron-api ipv6-address-mode="slaac,dhcpv6-stateful,dhcpv6-stateless"

# Configure overlay networks with IPv6 support
juju config neutron-api enable-ml2-vxlan=true

# Configure the external network for floating IPs with IPv6
juju config neutron-api l3-ha=true
juju config neutron-api neutron-security-groups=true

# Configure Ceph to use the dedicated storage network with IPv6
juju config ceph-mon cluster-network="10.10.100.0/24,2600:1700:5adb:700b::/64" 
juju config ceph-mon public-network="10.10.100.0/24,2600:1700:5adb:700b::/64"

# Configure services to use API network with IPv6
juju config keystone preferred-api-network="10.10.40.0/24,2600:1700:5adb:7008:400::/64"
juju config nova-cloud-controller network-manager=Neutron

# Configure Ironic to use the PXE network with IPv6
juju config ironic-conductor provisioning-network="100.64.16.0/24,2600:1700:5adb:500::/64"
juju config ironic-conductor cleaning-network="100.64.16.0/24,2600:1700:5adb:500::/64"

# Configure neutron-dhcp-agent for DNS64 to VMs Clients
juju config neutron-dhcp-agent dns-servers="2606:4700:4700::64,2606:4700:4700::6400"