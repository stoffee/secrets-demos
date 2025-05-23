#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part1.log) 2>&1
echo "Starting system setup at $(date)"

# Update system
echo "Updating system packages..."
#dnf update -y

# Install required packages
echo "Installing required packages..."
dnf install -y python3 python3-pip git jq

# Install Red Hat Ansible Automation Platform
echo "Installing Red Hat Ansible Automation Platform..."
dnf install -y ansible-core

# Install Python dependencies for Vault integration
echo "Installing Python dependencies..."
pip3 install hvac requests ansible

# Install Ansible collections for HashiCorp Vault
echo "Installing Ansible collections..."
ansible-galaxy collection install community.hashi_vault

# Create directory for Ansible project
echo "Creating directories..."
mkdir -p /opt/ansible-demo

echo "Creating symlinks for ansible commands..."
ln -sf /usr/bin/ansible-config /usr/bin/ansible
ln -sf /usr/bin/ansible-galaxy /usr/bin/ansible-playbook

echo "System setup completed at $(date)"