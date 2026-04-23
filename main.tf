terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

# ------------------------
# VPC
# ------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "AUY1105-app-vpc"
  }
}

# ------------------------
# SUBNET
# ------------------------
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "public-subnet"
  }
}

# ------------------------
# SECURITY GROUP
# ------------------------
resource "aws_security_group" "sg" {
  name        = "secure-sg"
  description = "Security group seguro"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTP internally"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    description = "Allow outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# ------------------------
# KMS KEY (FIX)
# ------------------------
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true  # ✅ FIX

  policy = jsonencode({         # ✅ FIX
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "*"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

# ------------------------
# CLOUDWATCH LOG GROUP (FIX)
# ------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn  # ✅ FIX

  tags = {
    Name = "vpc-flow-logs"
  }
}

# ------------------------
# IAM ROLE (FIX EC2)
# ------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

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

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# ------------------------
# EC2 (FIX GRANDE)
# ------------------------
resource "aws_instance" "ec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.subnet_public.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = false

  monitoring = true

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name  # ✅ FIX

  ebs_optimized = true  # ✅ FIX

  root_block_device {   # ✅ FIX ENCRYPTION
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "secure-ec2"
  }
}
