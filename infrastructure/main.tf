# =========================================================================================
# Author: Rob Satnarain
# Created: 2026-05-04
# Description: This file contains the main Terraform configuration for the infrastructure.
#
# Updated By     Date       Version     Description
# Rob Satnarain 2026-05-04  1.0         Initial creation - provider configuration
# =========================================================================================

# =========================================================================================
# Configure the AWS provider
# The AWS region is set using the aws_region variable defined in variables.tf and assigned a value in terraform.tfvars.
# =========================================================================================
provider "aws" {
     region = var.aws_region
}

# =========================================================================================
# Configure the S3 backend for Terraform state management
# The bucket name is set using the s3_backend_bucket_name variable defined in variables.tf and assigned a value in terraform.tfvars.
# =========================================================================================
# 1. S3 Bucket for Terraform state
resource "aws_s3_bucket" "terraform_state" {
  bucket = "rob-sre-server-bucket"

  tags = {
    Name = "Terraform State Bucket"
  }
}

# 2. S3 Bucket Versioning for Terraform state
resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
  
}

# 3. Ownership Controls for Terraform state bucket (Best Practice: Disable ACLs)
resource "aws_s3_bucket_ownership_controls" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id
  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

# 4. S3 Bucket Public Access Block for Terraform state bucket (Best Practice: Block Public Access)
resource "aws_s3_bucket_public_access_block" "terraform_state" {
     bucket = aws_s3_bucket.terraform_state.id
     block_public_acls = true
     block_public_policy = true
     ignore_public_acls = true
     restrict_public_buckets = true     
}

# =========================================================================================
# Fetch the latest Amazon Linux 2023 AMI dynamically
# =========================================================================================
data "aws_ami" "amazon_linux_2023" {
  most_recent = true
  owners = ["amazon"]

  filter {
    name = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }
}

# ==========================================================================
# Create a Security Group for the EC2 instance    
# ==========================================================================

resource "aws_security_group" "prometheus_sg" {
  name        = "prometheus-server-sg"
  description = "Allow SSH and Prometheus UI access"

  ingress {
    description = "SSH for Admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["65.35.126.205/32"] # Restrict to your home IP in production
  }

  ingress {
    description = "Prometheus Web UI"
    from_port   = 9090
    to_port     = 9090
    protocol    = "tcp"
    cidr_blocks = ["65.35.126.205/32"] # Restrict to your home IP in production
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "victim_sg" {
  name        = "victim-server-sg"
  description = "Allow HTTP for Load Test, restricted Prometheus scraping"

# Allow Local Prometheus to scrape Node Exporter
  ingress {
    description = "Local Mac Prometheus Scraper"
    from_port   = 9100
    to_port     = 9100
    protocol    = "tcp"
    cidr_blocks = ["65.35.126.205/32"] 
  }
  ingress {
    description = "Allow HTTP for Load Test"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "Allow SSH for Admin"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["65.35.126.205/32"]
  }

  # THIS IS LEVEL 1 ISOLATION: Only the Prometheus SG can hit port 9100
  ingress {
    description     = "Prometheus Node Exporter (Isolated)"
    from_port       = 9100
    to_port         = 9100
    protocol        = "tcp"
    security_groups = [aws_security_group.prometheus_sg.id] 
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ==========================================================================
# IAM Role and Policy for Prometheus Discovery of EC2
# ==========================================================================

resource "aws_iam_role" "prometheus_discovery_role" {
     name = "Prometheus-EC2-Discovery-Role"

     assume_role_policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
               {
                    Effect = "Allow"
                    Principal = {
                         Service = "ec2.amazonaws.com"
                    }
                    Action = "sts:AssumeRole"
               }
          ]
     })
  
}

resource "aws_iam_role_policy" "prometheus_discovery_policy" {
     name = "Prometheus-EC2-Discovery-Policy"
     # Description is not supported for role policies.
     role = aws_iam_role.prometheus_discovery_role.id

     policy = jsonencode({
          Version = "2012-10-17"
          Statement = [
               {
                    Effect = "Allow"
                    Action = [
                         "ec2:DescribeInstances",
                         "ec2:DescribeTags",
                    ]
                    Resource = "*"
               }
          ]
     })
}

resource "aws_iam_instance_profile" "prometheus_discovery_profile" {
     name = "Prometheus-EC2-Discovery-Profile"
     role = aws_iam_role.prometheus_discovery_role.name
}

# ==========================================
# 3. EC2 INSTANCES
# ==========================================

# The Prometheus Server
resource "aws_instance" "prometheus_server" {
  ami                  = data.aws_ami.amazon_linux_2023.id
  instance_type        = "t3.micro"
  key_name             = "RobBastion" 
  vpc_security_group_ids = [aws_security_group.prometheus_sg.id]
  iam_instance_profile = aws_iam_instance_profile.prometheus_discovery_profile.name

  tags = {
    Name = "Prometheus-Scraper"
  }

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y wget tar

              # Install Prometheus
              useradd --no-create-home --shell /bin/false prometheus
              mkdir /etc/prometheus
              mkdir /var/lib/prometheus
              chown prometheus:prometheus /etc/prometheus /var/lib/prometheus

              wget https://github.com/prometheus/prometheus/releases/download/v2.50.1/prometheus-2.50.1.linux-amd64.tar.gz
              tar xvfz prometheus-2.50.1.linux-amd64.tar.gz
              cp prometheus-2.50.1.linux-amd64/prometheus /usr/local/bin/
              cp prometheus-2.50.1.linux-amd64/promtool /usr/local/bin/
              chown prometheus:prometheus /usr/local/bin/prometheus /usr/local/bin/promtool

              # Create the dynamic Prometheus config file
              cat <<EOT > /etc/prometheus/prometheus.yml
              global:
                scrape_interval: 5s # Fast scraping to catch the 9 AM spike

              scrape_configs:
                - job_name: 'ec2-node-exporter'
                  ec2_sd_configs:
                    - region: us-east-1
                      port: 9100
                  relabel_configs:
                    # Only scrape instances with the tag Name = 9am-Spike-Victim
                    - source_labels: [__meta_ec2_tag_Name]
                      regex: 9am-Spike-Victim
                      action: keep
                    # Use the private IP address for scraping (more secure)
                    - source_labels: [__meta_ec2_private_ip]
                      target_label: __address__
                      replacement: "\$1:9100"
              EOT

              chown prometheus:prometheus /etc/prometheus/prometheus.yml

              # Create Systemd service
              cat <<EOT > /etc/systemd/system/prometheus.service
              [Unit]
              Description=Prometheus
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=prometheus
              Group=prometheus
              Type=simple
              ExecStart=/usr/local/bin/prometheus \
                --config.file /etc/prometheus/prometheus.yml \
                --storage.tsdb.path /var/lib/prometheus/ \
                --web.console.templates=/etc/prometheus/consoles \
                --web.console.libraries=/etc/prometheus/console_libraries

              [Install]
              WantedBy=multi-user.target
              EOT

              systemctl daemon-reload
              systemctl start prometheus
              systemctl enable prometheus
              EOF
}

# The Victim Server (Target)
resource "aws_instance" "victim_server" {
  ami           = data.aws_ami.amazon_linux_2023.id
  instance_type = "t3.micro" 
  key_name      = "RobBastion" 
  vpc_security_group_ids = [aws_security_group.victim_sg.id]

  tags = {
    Name = "9am-Spike-Victim"
  }

  user_data = <<-EOF
              #!/bin/bash
              dnf update -y
              dnf install -y httpd wget tar
              systemctl start httpd
              systemctl enable httpd
              echo "<h1>Welcome to the 9 AM Load Test!</h1><p>Ready to crash.</p>" > /var/www/html/index.html

              useradd --no-create-home --shell /bin/false node_exporter
              wget https://github.com/prometheus/node_exporter/releases/download/v1.7.0/node_exporter-1.7.0.linux-amd64.tar.gz
              tar xvfz node_exporter-1.7.0.linux-amd64.tar.gz
              cp node_exporter-1.7.0.linux-amd64/node_exporter /usr/local/bin/
              chown node_exporter:node_exporter /usr/local/bin/node_exporter

              cat <<EOT > /etc/systemd/system/node_exporter.service
              [Unit]
              Description=Node Exporter
              Wants=network-online.target
              After=network-online.target

              [Service]
              User=node_exporter
              Group=node_exporter
              Type=simple
              ExecStart=/usr/local/bin/node_exporter

              [Install]
              WantedBy=multi-user.target
              EOT

              systemctl daemon-reload
              systemctl start node_exporter
              systemctl enable node_exporter
              EOF
}
