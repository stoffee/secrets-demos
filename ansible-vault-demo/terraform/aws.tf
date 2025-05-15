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


# Add this data source to your main.tf
data "aws_ami" "rhel9" {
  most_recent = true
  owners      = ["309956199498"] # Red Hat's owner ID

  filter {
    name   = "name"
    values = ["RHEL-9*"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Then modify your EC2 instance resource
resource "aws_instance" "app_server" {
  ami                    = data.aws_ami.rhel9.id
  instance_type          = "t2.micro"
  subnet_id              = aws_subnet.app_subnet.id
  vpc_security_group_ids = [aws_security_group.app_sg.id]
  key_name               = var.ssh_key_name
  
  # Use the cloud-init config with user_data_base64
  user_data_base64       = data.template_cloudinit_config.ansible_config.rendered
  
  tags = {
    Name = "app-server-${var.prefix}"
  }
}

# Create the cloud-init config
data "template_cloudinit_config" "ansible_config" {
  gzip          = true
  base64_encode = true

  part {
    content_type = "text/x-shellscript"
    content      = templatefile("${path.module}/templates/ansible-user-data.sh.tpl", {
      vault_addr = hcp_vault_cluster.hcp_vault.vault_public_endpoint_url,
      role_id    = vault_approle_auth_backend_role.ansible.role_id,
      secret_id  = vault_approle_auth_backend_role_secret_id.ansible.secret_id
    })
  }
}
