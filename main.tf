#############################################
# TERRAFORM CONFIG
#############################################
terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

#############################################
# PROVIDER
#############################################
provider "aws" {
  region = "us-east-1"
}

#############################################
# DATA (para KMS sin wildcard)
#############################################
data "aws_caller_identity" "current" {}

#############################################
# VPC
#############################################
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "secure-vpc"
  }
}

#############################################
# BLOQUEAR SG DEFAULT (CKV2_AWS_12)
#############################################
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []
}

#############################################
# SUBNET
#############################################
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "secure-subnet"
  }
}

#############################################
# SECURITY GROUP (SIN EGRESO ABIERTO)
#############################################
resource "aws_security_group" "sg" {
  name        = "secure-sg"
  description = "Secure SG"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "Allow HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # SOLO salida HTTPS (no todo abierto)
  egress {
    description = "Allow HTTPS out"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################
# KMS KEY (SIN WILDCARD + ROTATION)
#############################################
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 7
  enable_key_rotation     = true

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action   = "kms:*"
        Resource = "*"
      }
    ]
  })
}

#############################################
# CLOUDWATCH LOG GROUP (CON KMS)
#############################################
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365
  kms_key_id        = aws_kms_key.logs_key.arn

  tags = {
    Name = "vpc-flow-logs"
  }
}

#############################################
# IAM ROLE PARA FLOW LOGS
#############################################
resource "aws_iam_role" "flow_logs_role" {
  name = "flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = {
          Service = "vpc-flow-logs.amazonaws.com"
        }
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents"
        ]
        Resource = "*"
      }
    ]
  })
}

#############################################
# FLOW LOGS (CKV2_AWS_11)
#############################################
resource "aws_flow_log" "vpc_flow_logs" {
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id

  iam_role_arn = aws_iam_role.flow_logs_role.arn
}

#############################################
# IAM ROLE PARA EC2
#############################################
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

#############################################
# EC2 (100% SEGURA)
#############################################
resource "aws_instance" "ec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.subnet_public.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = false

  monitoring    = true
  ebs_optimized = true

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "secure-ec2"
  }
}
