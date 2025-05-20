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
    cloudinit = {
      source  = "hashicorp/cloudinit"
      version = "~>2.3.3"
    }
  }
}


// Configure the providers
provider "hcp" {}

provider "vault" {
  address = data.hcp_vault_cluster.existing_vault.vault_public_endpoint_url
  token   = hcp_vault_cluster_admin_token.hcpvd.token
  namespace = "admin"
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