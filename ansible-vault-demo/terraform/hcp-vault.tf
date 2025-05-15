// Create an HVN
resource "hcp_hvn" "my_hvn" {
  hvn_id         = "hcp-hvn-${var.prefix}"
  cloud_provider = "aws"
  region         = var.region
  cidr_block     = "172.25.16.0/20"
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

resource "hcp_vault_cluster_admin_token" "hcpvd" {
  depends_on = [hcp_vault_cluster.hcp_vault]
  cluster_id = "hcp-${var.prefix}-vault-cluster"
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
  depends_on           = [vault_auth_backend.userpass, hcp_vault_cluster_admin_token.hcpvd]
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
  depends_on = [hcp_vault_cluster_admin_token.hcpvd]
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