// Pin the version
terraform {
  required_providers {
    hcp = {
      source  = "hashicorp/hcp"
      version = "~> 0.106.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~>4.8.0"
    }
    tfe = {
      source  = "hashicorp/tfe"
      version = "~>0.65.2"
    }
    aws = {
      source  = "hashicorp/aws"
      version = "~>5.97.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~>3.7.2"
    }
  }
}

// Configure the providers
provider "hcp" {}

provider "vault" {
  address = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url
  token   = hcp_vault_cluster_admin_token.stoffee_io.token
}

provider "tfe" {
  hostname = var.tfc_hostname
}

// Use the cloud provider AWS to provision resources
provider "aws" {
  region     = var.region
#  access_key = var.aws_access_key
#  secret_key = var.aws_secret_key
}

provider "random" {}

// Create an HVN
resource "hcp_hvn" "my_hvn" {
  hvn_id         = "hcp-hvn-${var.prefix}"
  cloud_provider = "aws"
  region         = var.region
  cidr_block     = "172.25.16.0/20"
}

// Create a VPC for the HVN to peer into
resource "aws_vpc" "main" {
  cidr_block = "172.25.0.0/20"
  
  tags = {
    Name = "vault-ansible-demo-vpc-${var.prefix}"
  }
}

data "aws_arn" "main" {
  arn = aws_vpc.main.arn
}

resource "aws_vpc_peering_connection_accepter" "main" {
  vpc_peering_connection_id = hcp_aws_network_peering.hvn_peering.provider_peering_id
  auto_accept               = true
}

// Create a network peering between the HVN and the AWS VPC
resource "hcp_aws_network_peering" "hvn_peering" {
  hvn_id          = hcp_hvn.my_hvn.hvn_id
  peering_id      = "hcp-${var.prefix}-peering"
  peer_vpc_id     = aws_vpc.main.id
  peer_account_id = aws_vpc.main.owner_id
  peer_vpc_region = data.aws_arn.main.region
}

// Create an HVN route that targets your HCP network peering and matches your AWS VPC's CIDR block
resource "hcp_hvn_route" "hvn_route" {
  hvn_link         = hcp_hvn.my_hvn.self_link
  hvn_route_id     = "hcp-${var.prefix}-hvn-route"
  destination_cidr = aws_vpc.main.cidr_block
  target_link      = hcp_aws_network_peering.hvn_peering.self_link
}

// Create a Vault cluster in the same region and cloud provider as the HVN
resource "hcp_vault_cluster" "hcp_vault" {
  cluster_id      = "hcp-${var.prefix}-vault-cluster"
  hvn_id          = hcp_hvn.my_hvn.hvn_id
  tier            = "plus_small"
  public_endpoint = "true"
}

resource "hcp_vault_cluster_admin_token" "stoffee_io" {
  depends_on = [hcp_vault_cluster.hcp_vault]
  cluster_id = "hcp-${var.prefix}-vault-cluster"
}

// Setup internet gateway for the VPC
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "igw-${var.prefix}"
  }
}

// Create subnets in the VPC for application servers
resource "aws_subnet" "app_subnet" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "172.25.1.0/24"
  availability_zone       = "${var.region}a"
  map_public_ip_on_launch = true
  
  tags = {
    Name = "app-subnet-${var.prefix}"
  }
}

// Create route table for the VPC
resource "aws_route_table" "rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  route {
    cidr_block                = hcp_hvn.my_hvn.cidr_block
    vpc_peering_connection_id = aws_vpc_peering_connection_accepter.main.id
  }

  tags = {
    Name = "route-table-${var.prefix}"
  }
}

// Associate the route table with the subnet
resource "aws_route_table_association" "a" {
  subnet_id      = aws_subnet.app_subnet.id
  route_table_id = aws_route_table.rt.id
}

// Create security group for application servers
resource "aws_security_group" "app_sg" {
  name        = "app-sg-${var.prefix}"
  description = "Security group for application servers"
  vpc_id      = aws_vpc.main.id

  // SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  // Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "app-sg-${var.prefix}"
  }
}

// Create application server
resource "aws_instance" "app_server" {
  ami                    = "ami-080c01c53e80e8a3d" // RHEL 9 latest in us-west-2
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.ssh_key_name
  
  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y python3 python3-pip
              pip3 install flask
              EOF
  
  tags = {
    Name = "app-server-${var.prefix}"
  }
}

// Vault auth methods and policies setup
resource "vault_auth_backend" "userpass" {
  type = "userpass"
  tune {
    max_lease_ttl     = "1h45m"
    default_lease_ttl = "2h45m"
  }
}

resource "vault_generic_endpoint" "userpass_admin" {
  depends_on           = [vault_auth_backend.userpass, hcp_vault_cluster_admin_token.stoffee_io]
  path                 = "auth/userpass/users/${var.userpass_admin}"
  ignore_absent_fields = true
  data_json = <<EOT
{
  "policies": ["${var.vault_admin_policy_name}"],
  "password": "${var.userpass_admin_password}"
}
EOT
}

resource "vault_policy" "super-user-policy" {
  depends_on = [hcp_vault_cluster_admin_token.stoffee_io]
  name       = var.vault_admin_policy_name
  policy     = <<EOT
path "+/auth/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
path "+/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo", "patch"]
}
# Grant access to manage namespaces themselves
path "sys/namespaces/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# Allow all system operations
path "sys/*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
# Root level access
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo", "patch"]
}
EOT
}

// New additions for Ansible integration
// Enable AppRole auth method for Ansible
resource "vault_auth_backend" "approle" {
  type = "approle"
}

// Create a policy for Ansible
resource "vault_policy" "ansible_policy" {
  name = "ansible-policy"

  policy = <<EOT
# Allow Ansible to read KV secrets
path "secret/data/*" {
  capabilities = ["read"]
}

# Allow Ansible to list KV secrets
path "secret/metadata/*" {
  capabilities = ["list"]
}

# Allow Ansible to update certain secrets (for rotation demo)
path "secret/data/app/*" {
  capabilities = ["create", "update", "read"]
}
EOT
}

// Create an AppRole for Ansible
resource "vault_approle_auth_backend_role" "ansible" {
  backend        = vault_auth_backend.approle.path
  role_name      = "ansible-role"
  token_policies = [vault_policy.ansible_policy.name]
}

// Generate a secret ID for the AppRole
resource "vault_approle_auth_backend_role_secret_id" "ansible" {
  backend   = vault_auth_backend.approle.path
  role_name = vault_approle_auth_backend_role.ansible.role_name
}

// Enable KV secrets engine version 2
resource "vault_mount" "kv" {
  path        = "secret"
  type        = "kv"
  options     = { version = "2" }
  description = "KV Version 2 secret engine mount"
}

// Create sample secrets for the demo application
resource "vault_kv_secret_v2" "app_db_creds" {
  mount               = vault_mount.kv.path
  name                = "app/database"
  delete_all_versions = true
  data_json = jsonencode({
    username = "db_user",
    password = random_password.db_password.result
  })
}

resource "vault_kv_secret_v2" "app_api_key" {
  mount               = vault_mount.kv.path
  name                = "app/api"
  delete_all_versions = true
  data_json = jsonencode({
    api_key = random_password.api_key.result
  })
}

// Generate random secrets
resource "random_password" "db_password" {
  length           = 16
  special          = true
  override_special = "!#$%&*()-_=+[]{}<>:?"
}

resource "random_password" "api_key" {
  length  = 24
  special = false
}

// Outputs
output "vault_root_token" {
  value     = hcp_vault_cluster_admin_token.stoffee_io.token
  sensitive = true
}

output "vault_public_url" {
  value = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url
}

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ansible_role_id" {
  value     = vault_approle_auth_backend_role.ansible.role_id
  sensitive = true
}

output "ansible_secret_id" {
  value     = vault_approle_auth_backend_role_secret_id.ansible.secret_id
  sensitive = true
}