#!/bin/bash
set -ex

# Log all output for debugging
exec > >(tee /var/log/user-data-part6.log) 2>&1
echo "Starting AAP Controller setup at $(date)"

# Download Red Hat AAP bundle using offline token
echo "Downloading Red Hat Ansible Automation Platform..."
cd /opt

# Red Hat Developer offline token (you need to provide this)
# Get from: https://access.redhat.com/management/api
OFFLINE_TOKEN="${REDHAT_OFFLINE_TOKEN:-}"

if [ -n "$OFFLINE_TOKEN" ]; then
  echo "Using Red Hat offline token for authenticated download..."
  
  # Get access token
  ACCESS_TOKEN=$(curl -s https://sso.redhat.com/auth/realms/redhat-external/protocol/openid-connect/token \
    -d grant_type=refresh_token \
    -d client_id=rhsm-api \
    -d refresh_token="$OFFLINE_TOKEN" | jq -r .access_token)
  
  # Download AAP bundle with authentication
  curl -H "Authorization: Bearer $ACCESS_TOKEN" \
    -o ansible-automation-platform-setup-bundle-2.5-1-x86_64.tar.gz \
    "https://api.access.redhat.com/management/v1/images/cpe:/a:redhat:ansible_automation_platform:2.5::el8/download"
else
  echo "No offline token provided - attempting direct download..."
  curl -L -o ansible-automation-platform-setup-bundle-2.5-1-x86_64.tar.gz \
    "https://developers.redhat.com/content-gateway/file/ansible/Ansible_Automation_Platform_2.5/ansible-automation-platform-setup-bundle-2.5-1-x86_64.tar.gz"
fi

# If download succeeded, extract and install
if [ -f "ansible-automation-platform-setup-bundle-2.5-1-x86_64.tar.gz" ]; then
  echo "Extracting AAP bundle..."
  tar -xzf ansible-automation-platform-setup-bundle-2.5-1-x86_64.tar.gz
  cd ansible-automation-platform-setup-bundle-2.5-1
  
  # Create inventory for single-node install
  cat > inventory << EOF
[automationcontroller]
localhost ansible_connection=local

[all:vars]
admin_password='RedHat123!'
pg_host=''
pg_port=''
pg_database='awx'
pg_username='awx'
pg_password='RedHat123!'
pg_sslmode='prefer'
EOF

  # Run installer
  ./setup.sh -i inventory
else
  echo "AAP bundle download failed - continuing without web UI"
fi

# Configure firewall
if command -v firewall-cmd &> /dev/null; then
  firewall-cmd --permanent --add-port=443/tcp
  firewall-cmd --permanent --add-port=80/tcp
  firewall-cmd --reload
fi

echo "AAP Controller setup completed at $(date)"
echo "Access at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"