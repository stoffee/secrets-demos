variable "prefix" {
  type        = string
  description = "Prefix used in resource names"
  default     = "ansible-vault-demo"
}

variable "region" {
  type        = string
  description = "The AWS region to deploy resources to"
  default     = "us-west-2"
}

variable "existing-hcp-vault-cluster-name" {
  type        = string
  description = "The name of the existing HCP Vault cluster"
  default     = "ansible-vault-demo" 
}
variable "namespace" {
  description = "root/admin namespace"
  default     = "admin"
}

variable "vault_admin_policy_name" {
  description = "Desired name of the admin policy"
  default     = "supah-user"
}

variable "userpass_user1" {
  description = "Desired name of a user to add to Vault UserPass Auth"
  default     = "vaultuser"
}

variable "userpass_user1_password" {
  description = "Desired password of a user to add to Vault UserPass Auth"
  default     = "ChangeMe"
  sensitive   = true
}

variable "userpass_admin" {
  description = "Desired name of namespace admin user to add to Vault UserPass Auth"
  default     = "vaultnamespaceadmin"
}

variable "userpass_admin_password" {
  description = "Desired password of namespace admin user to add to Vault UserPass Auth"
  default     = null
  sensitive   = true
}

variable "tfc_hostname" {
  type        = string
  default     = "app.terraform.io"
  description = "The hostname of the TFC or TFE instance you'd like to use with Vault"
}

variable "amazon_linux_ami" {
  description = "AMI ID for RHEL 9"
  type        = string
  default     = "ami-080c01c53e80e8a3d" # RHEL 9 latest in us-west-2
}

variable "ssh_key_name" {
    description = "Name of the SSH key pair to use for EC2 instances"
    type        = string
}

variable "redhat_offline_token" {
  description = "Red Hat Developer offline token"
  type        = string
  sensitive   = true
}