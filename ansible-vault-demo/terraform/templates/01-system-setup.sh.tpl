#!/bin/bash
set -ex  # Exit on error, print commands



# Log all output for debugging
exec > >(tee /var/log/user-data-part1.log) 2>&1
echo "Starting system setup at $(date)"

# Install required packages
echo "Installing required packages..."
echo "Installing Red Hat Ansible Automation Platform..."
dnf install -y python3 python3-pip git jq podman ansible-core make docker

# Install Python dependencies for Vault integration
echo "Installing Python dependencies..."
pip3 install hvac requests ansible docker-compose

# Install Ansible collections for HashiCorp Vault
echo "Installing Ansible collections..."
ansible-galaxy collection install community.hashi_vault

# Create directory for Ansible project
echo "Creating directories..."
mkdir -p /opt/ansible-demo

echo "Creating symlinks for ansible commands..."
ln -sf /usr/bin/ansible-config /usr/bin/ansible
ln -sf /usr/bin/ansible-galaxy /usr/bin/ansible-playbook

echo "Configuring Podman for execution environments..."
systemctl enable --now podman.socket

# Set docker socket environment
export DOCKER_HOST=unix:///run/podman/podman.sock

echo "Verifying Red Hat Ansible installation..."
ansible --version
ansible-navigator --version || echo "ansible-navigator available for enterprise execution"


echo "System setup completed at $(date)"