#!/bin/bash

# Create the external network on br-ext
openstack network create --share --external \
  --provider-network-type flat \
  --provider-physical-network physnet1 \
  external-network

# Create external IPv4 subnet
openstack subnet create --network external-network \
  --subnet-range 10.10.30.0/24 \
  --gateway 10.10.30.1 \
  --allocation-pool start=10.10.30.100,end=10.10.30.200 \
  --dns-nameserver 1.1.1.1 \
  --dns-nameserver 8.8.8.8 \
  external-subnet-v4

# Create external IPv6 subnet
openstack subnet create --network external-network \
  --ip-version 6 \
  --ipv6-address-mode slaac \
  --ipv6-ra-mode slaac \
  --subnet-range 2600:1700:5adb:7000:300::/64 \
  --gateway 2600:1700:5adb:7000:300::1 \
  --allocation-pool start=2600:1700:5adb:7000:300::100,end=2600:1700:5adb:7000:300::200 \
  --dns-nameserver 2606:4700:4700::1111 \
  --dns-nameserver 2001:4860:4860::8888 \
  external-subnet-v6

# Create the internal network on br-int
openstack network create --share \
  --provider-network-type flat \
  --provider-physical-network physnet2 \
  internal-network

# Create internal IPv4 subnet
openstack subnet create --network internal-network \
  --subnet-range 10.10.200.0/24 \
  --gateway 10.10.200.1 \
  --allocation-pool start=192.168.100.10,end=192.168.100.200 \
  --dns-nameserver 1.1.1.1 \
  --dns-nameserver 8.8.8.8 \
  internal-subnet-v4

# Create internal IPv6 subnet
openstack subnet create --network internal-network \
  --ip-version 6 \
  --ipv6-address-mode slaac \
  --ipv6-ra-mode slaac \
  --subnet-range 2600:1700:5adb:7009:200::/64 \
  --gateway 2600:1700:5adb:7009:200::1 \
  --allocation-pool start=2600:1700:5adb:7009:200::1000,end=2600:1700:5adb:7009:200::22ff \
  --dns-nameserver 2606:4700:4700::1111 \
  --dns-nameserver 2001:4860:4860::8888 \
  internal-subnet-v6

# Create dedicated VM external network using delegated prefix
openstack network create --share --external \
  --provider-network-type vlan \
  --provider-segment 600 \
  --provider-physical-network physnet1 \
  vm-external-network

# Create VM external IPv6 subnet
openstack subnet create --network vm-external-network \
  --ip-version 6 \
  --ipv6-address-mode slaac \
  --ipv6-ra-mode slaac \
  --subnet-range 2600:1700:5adb:7009::/64 \
  --gateway 2600:1700:5adb:7009::600:1 \
  --allocation-pool start=2600:1700:5adb:7009::1000,end=2600:1700:5adb:7009::2fff \
  --dns-nameserver 2606:4700:4700::1111 \
  --dns-nameserver 2001:4860:4860::8888 \
  vm-external-subnet-v6


### --- testing --- ###

# Create a network for IPv6-only VMs
openstack network create ipv6-only-net
openstack subnet create --network ipv6-only-net \
  --ip-version 6 \
  --ipv6-address-mode slaac \
  --ipv6-ra-mode slaac \
  --subnet-range 2600:1700:5adb:7009:700::/64 \
  --allocation-pool start=2600:1700:5adb:7009:700::11,end=2600:1700:5adb:7009:700::ff \
  --gateway 2600:1700:5adb:7009:700::1 \
  --dns-nameserver 2606:4700:4700::1111 \
  --dns-nameserver 2001:4860:4860::8888 \
  --dns-nameserver 2606:4700:4700::64 \
  --dns-nameserver 2606:4700:4700::6400 \
  ipv6-only-subnet

# Create a router to connect to external network
openstack router create vm-router
openstack router add subnet vm-router vm-internal-subnet-v4
openstack router add subnet vm-router vm-internal-subnet-v6
openstack router set --external-gateway external-network vm-router

openstack router create ipv6-router
openstack router add subnet ipv6-router ipv6-only-subnet
openstack router set --external-gateway external-network ipv6-router

