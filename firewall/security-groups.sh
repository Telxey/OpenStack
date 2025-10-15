#!/bin/bash
# Create security groups for different VM types

# Default security group for general VMs
openstack security group create default-vm
openstack security group rule create --protocol icmp default-vm
openstack security group rule create --protocol tcp --dst-port 22 default-vm

# IPv6-specific security group
openstack security group create ipv6-vm
openstack security group rule create --ethertype IPv6 --protocol ipv6-icmp ipv6-vm
openstack security group rule create --ethertype IPv6 --protocol tcp --dst-port 22 ipv6-vm
openstack security group rule create --ethertype IPv6 --protocol tcp --dst-port 80 ipv6-vm
openstack security group rule create --ethertype IPv6 --protocol tcp --dst-port 443 ipv6-vm

# Web server security group
openstack security group create web-server
openstack security group rule create --protocol tcp --dst-port 80 web-server
openstack security group rule create --protocol tcp --dst-port 443 web-server
openstack security group rule create --ethertype IPv6 --protocol tcp --dst-port 80 web-server
openstack security group rule create --ethertype IPv6 --protocol tcp --dst-port 443 web-server 