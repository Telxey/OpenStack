#!/bin/bsch

# Create a default IPv6 security group
openstack security group create ipv6-default

# Allow ICMPv6 for proper IPv6 operation (including Neighbor Discovery)
openstack security group rule create --protocol ipv6-icmp ipv6-default

# Allow SSH
openstack security group rule create --protocol tcp --dst-port 22 ipv6-default

# Optional: Allow HTTP/HTTPS
openstack security group rule create --protocol tcp --dst-port 80 ipv6-default
openstack security group rule create --protocol tcp --dst-port 443 ipv6-default
