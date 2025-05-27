#!/bin/bash
set -ex

# Log all output for debugging
exec > >(tee /var/log/user-data-part6.log) 2>&1
echo "Starting AAP Controller setup at $(date)"

# Install AAP Controller (requires subscription but we'll try)
echo "Installing Ansible Automation Platform Controller..."
dnf install -y automation-controller || {
    echo "Failed to install automation-controller - trying alternative method"
    # Alternative: Use Red Hat's installer script
    curl -O https://releases.ansible.com/ansible-automation-platform/setup/ansible-automation-platform-setup-latest.tar.gz
    tar -xzf ansible-automation-platform-setup-*.tar.gz
    cd ansible-automation-platform-setup-*
    
    # Create basic inventory for single-node install
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
    ./setup.sh -i inventory || echo "Controller install failed - continuing with CLI tools"
}

# Configure SSL certificate (self-signed for demo)
echo "Configuring SSL certificate..."
mkdir -p /etc/tower/ssl
openssl req -new -newkey rsa:4096 -days 365 -nodes -x509 \
  -subj "/C=US/ST=CA/L=San Francisco/O=Demo/CN=$(hostname -f)" \
  -keyout /etc/tower/ssl/tower.key \
  -out /etc/tower/ssl/tower.crt 2>/dev/null || true

# Configure firewall
echo "Configuring firewall..."
if command -v firewall-cmd &> /dev/null; then
  firewall-cmd --permanent --add-port=443/tcp
  firewall-cmd --reload
fi

# Start and enable services
echo "Starting AAP Controller services..."
systemctl enable --now automation-controller 2>/dev/null || {
    echo "Using alternative service startup..."
    systemctl enable --now nginx
    systemctl enable --now awx-web
    systemctl enable --now awx-task
}

# Wait for services to start
echo "Waiting for AAP Controller to be ready..."
sleep 30

# Check service status
systemctl status automation-controller || systemctl status awx-web || echo "Controller may not be fully configured"

echo "AAP Controller setup completed at $(date)"
echo "Access the Controller at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4)/"
echo "Default credentials: admin / RedHat123!"