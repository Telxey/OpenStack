#!/bin/bash

echo 'Part 3: Install Juju and LXD'

# Install Juju and LXD
sudo snap install juju --classic
sudo snap install lxd

# Initialize LXD
sudo lxd init --auto

# Bootstrap Juju controller with LXD
juju bootstrap localhost lxd-controller

# Create a model for OpenStack
juju add-model openstack





