#!/bin/bash
set -ex  # Exit on error, print commands

# Log all output for debugging
exec > >(tee /var/log/user-data-part4.log) 2>&1
echo "Starting demo setup and run at $(date)"

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