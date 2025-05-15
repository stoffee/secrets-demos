#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part2.log) 2>&1
echo "Starting Vault auth setup at $(date)"

# Create vault credentials directory
mkdir -p /root/.vault

# Set up Vault environment
VAULT_ADDR="${vault_addr}"
echo "export VAULT_ADDR=$VAULT_ADDR" > /opt/ansible-demo/vault-env.sh
chmod +x /opt/ansible-demo/vault-env.sh
source /opt/ansible-demo/vault-env.sh

# Use the root token from Terraform - this needs to be passed in
VAULT_TOKEN="${vault_token}"
echo "$VAULT_TOKEN" > /root/.vault/root_token
chmod 600 /root/.vault/root_token

# Create a new AppRole secret ID
echo "Creating new AppRole secret ID..."
ROLE_ID=$(curl --silent --header "X-Vault-Token: $VAULT_TOKEN" \
$VAULT_ADDR/v1/auth/approle/role/ansible-role/role-id | jq -r .data.role_id)

SECRET_ID=$(curl --silent --header "X-Vault-Token: $VAULT_TOKEN" \
--request POST \
$VAULT_ADDR/v1/auth/approle/role/ansible-role/secret-id | jq -r .data.secret_id)

# Save to approle file
echo "role_id=$ROLE_ID" > /root/.vault/approle 
echo "secret_id=$SECRET_ID" >> /root/.vault/approle
chmod 600 /root/.vault/approle

echo "Vault authentication setup completed at $(date)"