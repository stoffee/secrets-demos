#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part2.log) 2>&1
echo "Starting Vault auth setup at $(date)"

# Create vault credentials directory
mkdir -p /root/.vault

# Create approle file
echo "Setting up Vault authentication..."
echo "role_id=${role_id}" > /root/.vault/approle
echo "secret_id=${secret_id}" >> /root/.vault/approle
chmod 600 /root/.vault/approle

# Create vault environment file
echo "export VAULT_ADDR=${vault_addr}" > /opt/ansible-demo/vault-env.sh
chmod +x /opt/ansible-demo/vault-env.sh

# Source the environment variables
source /opt/ansible-demo/vault-env.sh

echo "Vault authentication setup completed at $(date)"