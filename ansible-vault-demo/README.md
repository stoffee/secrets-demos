# Vault and Ansible Integration Demo

This repository contains the Ansible playbooks and configurations for demonstrating the integration of HashiCorp Vault with Ansible for secure credential management and application deployment.

## Overview

This demo shows how to:

1. Authenticate to Vault using AppRole
2. Retrieve secrets from Vault
3. Deploy an application with the retrieved secrets
4. Rotate secrets without application downtime

## Running the Demo

The demo is designed to be self-contained and run on a single EC2 instance.

### Prerequisites

- EC2 instance with RHEL 9 or compatible Linux
- Vault server with AppRole authentication enabled
- Proper network connectivity between EC2 and Vault

### Setup Instructions

1. The EC2 instance is configured by Terraform to automatically:
   - Install Ansible
   - Set up Vault authentication credentials
   - Clone this repository

2. To run the demo manually on the EC2 instance:

```bash
# Source the Vault environment
source /opt/ansible-demo/vault-env.sh

# Authenticate to Vault
cd /opt/ansible-demo
ansible-playbook playbooks/vault-auth.yml

# Deploy the application
ansible-playbook playbooks/deploy-app.yml

# Rotate secrets
ansible-playbook playbooks/rotate-secrets.yml