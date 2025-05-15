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

echo "System setup completed at $(date)"