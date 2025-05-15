// Outputs
output "vault_root_token" {
  value     = nonsensitive(hcp_vault_cluster_admin_token.stoffee_io.token)
}

output "vault_public_url" {
  value = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url
}

output "app_server_public_ip" {
  value = aws_instance.app_server.public_ip
}

output "ansible_role_id" {
  value     = nonsensitive(vault_approle_auth_backend_role.ansible.role_id)
}

output "ansible_secret_id" {
  value     = nonsensitive(vault_approle_auth_backend_role_secret_id.ansible.secret_id)
}

# Output the Ansible controller's public IP
output "ansible_controller_public_ip" {
  value = aws_instance.app_server.public_ip
}