#!/bin/bash
# Basic firewall setup for OpenStack controller

# Enable UFW
sudo ufw --force enable

# Default policies
sudo ufw default deny incoming
sudo ufw default allow outgoing

# SSH access (adjust port if you're not using 22)
sudo ufw allow 22/tcp

# Juju controller communication
sudo ufw allow 17070/tcp  # Juju API server
sudo ufw allow 37017/tcp  # MongoDB (if using local Juju controller)

# OpenStack API endpoints
sudo ufw allow 5000/tcp   # Keystone
sudo ufw allow 9292/tcp   # Glance
sudo ufw allow 8774/tcp   # Nova API
sudo ufw allow 8776/tcp   # Cinder
sudo ufw allow 9696/tcp   # Neutron
sudo ufw allow 80/tcp     # Horizon HTTP
sudo ufw allow 443/tcp    # Horizon HTTPS

# Database access (if external clients need it)
sudo ufw allow from 10.10.0.0/16 to any port 3306  # MySQL (internal networks only)

# RabbitMQ
sudo ufw allow from 10.10.0.0/16 to any port 5672  # AMQP
sudo ufw allow from 10.10.0.0/16 to any port 15672 # Management interface

# Allow your internal networks
sudo ufw allow from 10.10.0.0/16
sudo ufw allow from 192.168.0.0/24
sudo ufw allow from 172.16.0.0/24

# Allow IPv6 networks
sudo ufw allow from 2600:1700:5adb::/48

# Check status
sudo ufw status verbose
