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

#resource "aws_vpc_peering_connection_accepter" "main" {
#  vpc_peering_connection_id = hcp_aws_network_peering.hvn_peering.provider_peering_id
#  auto_accept               = true
#}

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

  // flask access
  ingress {
    from_port   = 5000
    to_port     = 5000
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


# HC-approved base AMI with EDR (HC-COMPUTE-011)
module "base_ami" {
  source  = "app.terraform.io/cdunlap/hc-base-ami/aws"
  version = "1.0.0"

  os_flavor    = "rhel-9"
  architecture = "x86_64"
}

resource "aws_instance" "app_server" {
  ami                    = module.base_ami.ami_id
  instance_type          = "m5.large"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.ssh_key_name
  
  # Use the cloud-init config with user_data
  user_data              = data.cloudinit_config.ansible_config.rendered
  
  tags = {
    Name = "app-server-${var.prefix}"
  }
  depends_on = [ hcp_vault_cluster_admin_token.hcpvd ]
}

# Create the cloud-init config using multiple parts for a cleaner setup
data "cloudinit_config" "ansible_config" {
  gzip          = true
  base64_encode = true

  # Part 1: System setup and package installation
  part {
    filename     = "01-system-setup.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/01-system-setup.sh.tpl", {})
  }

  # Part 2: Vault authentication setup
  part {
    filename     = "02-vault-auth-setup.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/02-vault-auth-setup.sh.tpl", {
      vault_addr = data.hcp_vault_cluster.existing_vault.vault_public_endpoint_url,
      vault_token = hcp_vault_cluster_admin_token.hcpvd.token,
      role_id    = vault_approle_auth_backend_role.ansible.role_id,
      secret_id  = vault_approle_auth_backend_role_secret_id.ansible.secret_id
      namespace  = "admin/secrets-demo"
      redhat_token = var.redhat_offline_token
    })
  }

  # Part 3: Ansible project setup
  part {
    filename     = "03-ansible-project-setup.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/03-ansible-project-setup.sh.tpl", {})
  }

  # Part 4: Run demo setup
  part {
    filename     = "04-run-demo.sh"
    content_type = "text/x-shellscript"
    content = templatefile("${path.module}/templates/04-run-demo.sh.tpl", {})
  }

  # Part 5: Configure firewall for Flask application
  part {
    filename     = "05-configure-firewall.sh"
    content_type = "text/x-shellscript"
    content = <<-EOF
    #!/bin/bash
    set -ex
    
    # Log all output for debugging
    exec > >(tee /var/log/user-data-part5.log) 2>&1
    echo "Configuring firewall for Flask application at $(date)"
    
    # Check if firewalld is installed and running
    if command -v firewall-cmd &> /dev/null && systemctl is-active --quiet firewalld; then
      echo "Enabling port 5000/tcp in firewalld..."
      firewall-cmd --permanent --add-port=5000/tcp
      firewall-cmd --reload
    else
      echo "Firewalld not installed or not running, skipping firewall configuration"
    fi
    
    echo "Firewall configuration completed at $(date)"
    EOF
  }

  part {
  filename     = "06-aap-controller-setup.sh"
  content_type = "text/x-shellscript"
  content = templatefile("${path.module}/templates/06-aap-controller-setup.sh.tpl", {
    vault_addr = data.hcp_vault_cluster.existing_vault.vault_public_endpoint_url
    redhat_token = var.redhat_offline_token
  })
}
}