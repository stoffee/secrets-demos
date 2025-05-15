#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part1.log) 2>&1
echo "Starting system setup at $(date)"

# Update system
echo "Updating system packages..."
dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y python3 python3-pip git

# Install Ansible and required packages
echo "Installing Ansible and dependencies..."
pip3 install ansible hvac requests

# Create directory for Ansible project
echo "Creating directories..."
mkdir -p /opt/ansible-demo

# Add ansible-playbook to system-wide PATH in /etc/profile
echo 'export PATH=$PATH:/usr/local/bin' >> /etc/profile
echo 'if [ -d "/usr/local/bin" ] ; then' >> /etc/profile
echo '    export PATH="/usr/local/bin:$PATH"' >> /etc/profile
echo 'fi' >> /etc/profile
source /etc/profile

# Create a more specific PATH entry for the root user
echo 'export PATH=$PATH:/usr/local/bin' >> /root/.bashrc

echo "System setup completed at $(date)"