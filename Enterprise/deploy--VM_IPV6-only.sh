#!/bin/bash

# Create a test VM with dual-stack networking
openstack server create --flavor m1.small \
  --image ubuntu-22.04 \
  --network vm-external-network \
  --security-group ipv6-default \
  ipv6-test-vm

# Get the IPv6 address of the VM
openstack server show ipv6-test-vm | grep addresses

# Test connectivity from the host
ping6 <VM_IPV6_ADDRESS>

# SSH to the VM using IPv6
ssh ubuntu@<VM_IPV6_ADDRESS>