#!/bin/bash
# This script will be executed by the user_data script in the EC2 instance

# Variables will be populated by Terraform
VAULT_ADDR="${vault_public_url}"
ROLE_ID="${ansible_role_id}"
SECRET_ID="${ansible_secret_id}"

# Create vault directory if it doesn't exist
mkdir -p /root/.vault

# Create approle file
echo "role_id=$ROLE_ID" > /root/.vault/approle
echo "secret_id=$SECRET_ID" >> /root/.vault/approle
chmod 600 /root/.vault/approle

# Create vault environment file
echo "export VAULT_ADDR=$VAULT_ADDR" > /opt/ansible-demo/vault-env.sh
chmod +x /opt/ansible-demo/vault-env.sh

# Source the environment variables
source /opt/ansible-demo/vault-env.sh

echo "Vault authentication setup completed."