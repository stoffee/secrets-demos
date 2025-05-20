// Use existing Vault cluster instead of creating a new one
data "hcp_vault_cluster" "existing_vault" {
  cluster_id = "hcp-stoffee-io-vault-cluster"
}

// Get admin token for the existing Vault cluster
resource "hcp_vault_cluster_admin_token" "hcpvd" {
  cluster_id = data.hcp_vault_cluster.existing_vault.cluster_id
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