#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part3.log) 2>&1
echo "Starting Ansible project setup at $(date)"

cd /opt/ansible-demo

# Clone the secrets-demos repository
echo "Cloning repository..."
git clone https://github.com/stoffee/secrets-demos.git /tmp/secrets-demos
if [ $? -ne 0 ]; then
  echo "ERROR: Failed to clone repository"
  exit 1
fi

# Copy the ansible-vault-demo files to the correct location
echo "Copying files..."
cp -r /tmp/secrets-demos/ansible-vault-demo/* /opt/ansible-demo/
cp -r /tmp/secrets-demos/ansible-vault-demo/.* /opt/ansible-demo/ 2>/dev/null || true

# Create directory for ansible config
mkdir -p /etc/ansible

# Copy ansible.cfg to the correct location
echo "Configuring Ansible..."
cp /opt/ansible-demo/ansible.cfg /etc/ansible/ansible.cfg || echo "Failed to copy ansible.cfg"

echo "copying the inventory file..."
if [ -f /opt/ansible-demo/inventory ]; then
  cp /opt/ansible-demo/inventory /etc/ansible/hosts
  chmod 644 /etc/ansible/hosts
fi

echo "Ansible project setup completed at $(date)"