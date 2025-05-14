#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data.log) 2>&1
echo "Starting user-data script execution at $(date)"

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
cd /opt/ansible-demo

# Create vault credentials directory
mkdir -p /root/.vault

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

# Create Vault credentials
echo "Setting up Vault authentication..."
# Create approle file
echo "role_id=${role_id}" > /root/.vault/approle
echo "secret_id=${secret_id}" >> /root/.vault/approle
chmod 600 /root/.vault/approle

# Create vault environment file
echo "export VAULT_ADDR=${vault_addr}" > /opt/ansible-demo/vault-env.sh
chmod +x /opt/ansible-demo/vault-env.sh

# Source the environment variables
source /opt/ansible-demo/vault-env.sh

# Create a script to run the demo
echo "Creating demo run script..."
cat > /opt/ansible-demo/run-demo.sh << 'DEMO_SCRIPT'
#!/bin/bash
source /opt/ansible-demo/vault-env.sh
cd /opt/ansible-demo

echo "Step 1: Authenticating to Vault..."
ansible-playbook playbooks/vault-auth.yml

echo "Step 2: Retrieving secrets from Vault..."
ansible-playbook playbooks/get-secrets.yml

echo "Step 3: Deploying application..."
ansible-playbook playbooks/deploy-app.yml

echo "Demo setup complete! Access the application at:"
echo "http://$(curl -s http://169.254.169.254/latest/meta-data/public-ipv4):5000"

echo "To rotate secrets, run:"
echo "ansible-playbook playbooks/rotate-secrets.yml"
DEMO_SCRIPT

# Make demo script executable
chmod +x /opt/ansible-demo/run-demo.sh

# Run the demo
echo "Running the demo..."
/opt/ansible-demo/run-demo.sh

echo "Setup complete at $(date)" > /tmp/setup_complete.txt