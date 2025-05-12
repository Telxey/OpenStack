# OpenStack Deployment Solution

![OpenStack Logo](https://object-storage-ca-ymq-1.vexxhost.net/swift/v1/6e4619c416ff4bd19e1c087f27a43eea/www-images-prod/openstack-logo/OpenStack-Logo-Horizontal.png)

## Overview

This repository contains a comprehensive solution for deploying, operating, and monitoring OpenStack cloud environments. It provides a set of scripts that automate the entire lifecycle of an OpenStack deployment, from initial setup to ongoing management and monitoring.

The solution is designed to simplify the complex process of deploying and maintaining OpenStack, making it accessible to administrators with varying levels of expertise.

### Key Features

- **Automated Full-Stack Deployment**: Complete OpenStack setup with all core and additional services
- **Tiered Storage Configuration**: Optimized storage layout for different performance requirements
- **Interactive Operations Helper**: Day-to-day management tasks through an intuitive menu system
- **Comprehensive Monitoring**: Real-time status checks and health monitoring
- **Integrated Backup Solution**: Automated database backups and recovery options
- **Multi-Service Support**: Deploys and configures all major OpenStack components

## Components

The solution consists of three main scripts:

| Script | Purpose | Description |
|--------|---------|-------------|
| `openstack-installer.sh` | Installation | Deploys a complete OpenStack environment with all core and additional services |
| `operation_helper.sh` | Operations | Interactive menu-driven interface for day-to-day OpenStack management tasks |
| `openstack-monitor.sh` | Monitoring | Checks the health and status of all OpenStack services and resources |

### Component Scripts

#### 1. OpenStack Installer (`openstack-installer.sh`)

This script handles the complete deployment of an OpenStack environment. It performs:

- Storage configuration and optimization
- Service directory setup
- Juju and LXD installation and configuration
- Core OpenStack services deployment
- Additional services deployment
- Database configuration
- Service relationship establishment
- Backup setup
- Deployment verification

The installer follows a structured approach with 11 distinct steps to ensure a complete and properly configured OpenStack environment.

#### 2. Operations Helper (`operation_helper.sh`)

This interactive script provides a menu-driven interface for common OpenStack management tasks:

- Identity Management (users, projects, roles)
- Compute Management (instances, flavors, images)
- Storage Management (volumes, snapshots, Swift objects)
- Network Management (networks, routers, security groups)
- Baremetal Management (Ironic nodes)
- Dashboard Information and Access

Each section contains sub-menus with specific operations, making day-to-day OpenStack management accessible even to operators with limited OpenStack command-line experience.

#### 3. OpenStack Monitor (`openstack-monitor.sh`)

This script performs comprehensive health checks and status monitoring:

- Juju deployment status verification
- OpenStack service status checks
- API verification
- Resource availability checks
- System resources monitoring (storage, CPU, memory)
- Log analysis and error reporting

## Requirements

### System Requirements

- **Processor**: 8+ CPU cores recommended
- **Memory**: 16+ GB RAM recommended
- **Storage**: Minimum 2 TB across multiple disks (for tiered storage)
- **Operating System**: Ubuntu 22.04 LTS or newer
- **Network**: Multiple network interfaces recommended for segregated traffic

### Software Prerequisites

- **Ubuntu Server**: 22.04 LTS or newer
- **LVM Tools**: For storage configuration
- **Snap**: For Juju and LXD installation
- **Python 3.8+**: Required for OpenStack clients
- **SSH Access**: For remote management

## Installation and Setup

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/openstack-deployment.git
cd openstack-deployment
```

### Step 2: Prepare the Environment

Ensure all storage devices are properly connected and identified:

```bash
lsblk
```

Verify network connectivity:

```bash
ip a
ping -c 4 google.com
```

### Step 3: Run the Installer

Make the installer script executable:

```bash
chmod +x openstack-installer.sh
```

Run the installer with sudo:

```bash
sudo ./openstack-installer.sh
```

The installation process will:
1. Verify prerequisites
2. Set up storage volumes
3. Configure service directories
4. Install and configure Juju and LXD
5. Deploy all OpenStack services
6. Configure relationships between services
7. Set up backup systems
8. Verify the installation

The complete installation process takes approximately 2-3 hours depending on hardware and network speed.

## Usage Examples

### Using the Installer

The installer requires minimal interaction - simply run it and provide confirmation when prompted:

```bash
sudo ./openstack-installer.sh
```

You'll be asked to confirm storage configuration before any disks are modified.

### Using the Operations Helper

The operations helper is an interactive tool for managing your OpenStack environment:

```bash
./operation_helper.sh
```

This will display a menu with options for various management tasks:

1. **Identity Management**: Manage users, projects, and roles
   - Create new users and projects
   - Assign roles to users in projects
   - List existing users, projects, and roles

2. **Compute Management**: Manage instances, flavors, and images
   - Create, list, and manage virtual machines
   - Define custom flavors
   - Upload and manage VM images

3. **Storage Management**: Manage volumes and object storage
   - Create and attach volumes to instances
   - Create and manage snapshots
   - Work with Swift object storage containers

4. **Network Management**: Manage networking components
   - Create networks and subnets
   - Configure routers and security groups
   - Manage floating IPs and VPNs

5. **Baremetal Management**: Manage Ironic nodes
   - Register and manage physical servers
   - Control power state
   - Configure boot options

### Using the Monitor

The monitoring script can be run at any time to check the health of your OpenStack environment:

```bash
./openstack-monitor.sh
```

You can also set it up as a cron job for regular automated monitoring:

```bash
# Add to crontab to run every hour
echo "0 * * * * /path/to/openstack-monitor.sh > /var/log/openstack-monitor.log 2>&1" | sudo tee -a /etc/crontab
```

## Deployment Flow

The OpenStack deployment process follows this general flow:

```
1. Prerequisites Check
   ↓
2. Storage Configuration
   ↓
3. Service Directory Setup
   ↓
4. Juju & LXD Installation
   ↓
5. Core Services Deployment
   ↓
6. Additional Services Deployment
   ↓
7. MySQL Configuration
   ↓
8. Service Relations
   ↓
9. Backup Configuration
   ↓
10. Monitoring Setup
    ↓
11. Verification & Validation
```

## Troubleshooting

### Common Issues

#### Failed Services in Juju

If services show an error state in Juju:

```bash
juju status --format=yaml | grep -A 5 "status: error"
```

To investigate further:

```bash
juju debug-log -i <service-name>
```

#### Network Connectivity Issues

If instances cannot connect to external networks:

1. Check neutron-gateway status:
   ```bash
   juju status neutron-gateway
   ```

2. Verify network configuration:
   ```bash
   ./operation_helper.sh
   # Select Option 4 for Network Management
   ```

#### Storage Issues

If volumes cannot be created:

1. Check Cinder service status:
   ```bash
   openstack volume service list
   ```

2. Verify LVM configuration:
   ```bash
   sudo vgs
   sudo lvs
   ```

### Log Files

Important log files to check:

- **Juju Logs**: `juju debug-log`
- **OpenStack Logs**: `/var/log/*/`
- **Installer Log**: Located at path shown during installation
- **Monitor Logs**: If set up with cron, typically in `/var/log/openstack-monitor.log`

## Maintenance and Updates

### Backing Up Your OpenStack Environment

The installer sets up automated MySQL backups in `/var/lib/backup/mysql/`.

For manual backups:

```bash
sudo /usr/local/bin/backup-mysql.sh
```

### Updating OpenStack Services

To update OpenStack services to newer releases:

```bash
juju config <service-name> openstack-origin=cloud:noble-bobcat
```

Replace `noble-bobcat` with the appropriate OpenStack release.

## References

### Official Documentation

- [OpenStack Documentation](https://docs.openstack.org/)
- [Juju Documentation](https://juju.is/docs)
- [LXD Documentation](https://linuxcontainers.org/lxd/documentation/)

### Additional Resources

- [OpenStack Security Guide](https://docs.openstack.org/security-guide/)
- [OpenStack Troubleshooting Guide](https://docs.openstack.org/operations-guide/ops-troubleshooting.html)
- [Juju Charms for OpenStack](https://ubuntu.com/openstack/docs/juju-openstack-charms)

## License

This solution is provided under the Apache License 2.0.

## Contributors

- [Your Name] - Initial work and ongoing maintenance

## Acknowledgements

- The OpenStack Foundation
- Canonical Ltd. for Juju and LXD
- All contributors to the OpenStack project

