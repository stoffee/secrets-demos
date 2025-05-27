#!/bin/bash
set -ex

# Log all output for debugging
exec > >(tee /var/log/user-data-part6.log) 2>&1
echo "Starting AAP Controller setup at $(date)"

# Install AWX using Docker Compose
echo "Installing AWX using containers..."
dnf install -y podman podman-compose git

# Clone AWX
cd /opt
git clone https://github.com/ansible/awx.git
cd awx

# Use AWX development environment
make docker-compose-build
make docker-compose

# Wait for services
sleep 60

# Get admin password
docker logs tools_awx_1 2>&1 | grep -i password

# Configure firewall for AWX port 8043
if command -v firewall-cmd &> /dev/null; then
  firewall-cmd --permanent --add-port=8043/tcp
  firewall-cmd --permanent --add-port=8080/tcp
  firewall-cmd --reload
fi

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

echo "AWX Controller setup completed at $(date)"
echo "Access AWX at: https://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):8043/"
echo "Default credentials: admin / password"