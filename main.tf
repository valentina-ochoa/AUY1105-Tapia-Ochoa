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

# -----------------------------
# VPC
# -----------------------------
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "AUY1105-app-vpc"
  }
}

# -----------------------------
# SUBNET (SIN IP PUBLICA)
# -----------------------------
resource "aws_subnet" "subnet_public" {
  vpc_id     = aws_vpc.main.id
  cidr_block = "10.1.1.0/24"

  map_public_ip_on_launch = false

  tags = {
    Name = "AUY1105-app-subnet"
  }
}

# -----------------------------
# SECURITY GROUP
# -----------------------------
resource "aws_security_group" "sg" {
  name        = "AUY1105-app-sg"
  description = "Security group para SSH restringido"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH desde IP específica"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["201.188.31.24/32"]
  }

  egress {
    description = "Salida HTTPS"
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AUY1105-app-sg"
  }
}

# -----------------------------
# IAM ROLE EC2
# -----------------------------
resource "aws_iam_role" "ec2_role" {
  name = "ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_instance_profile" "ec2_profile" {
  name = "ec2-profile"
  role = aws_iam_role.ec2_role.name
}

# -----------------------------
# EC2
# -----------------------------
resource "aws_instance" "ec2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.subnet_public.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  iam_instance_profile = aws_iam_instance_profile.ec2_profile.name

  monitoring           = true
  ebs_optimized        = true

  metadata_options {
    http_tokens = "required"
  }

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "AUY1105-app-ec2"
  }
}

# -----------------------------
# CLOUDWATCH LOG GROUP (FIX)
# -----------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365

  tags = {
    Name = "vpc-flow-logs"
  }
}

# -----------------------------
# IAM ROLE FLOW LOGS
# -----------------------------
resource "aws_iam_role" "flow_logs_role" {
  name = "flow-logs-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Service = "vpc-flow-logs.amazonaws.com"
      }
      Action = "sts:AssumeRole"
    }]
  })
}

# ✅ FIX IMPORTANTE: sin "*"
resource "aws_iam_role_policy" "flow_logs_policy" {
  name = "flow-logs-policy"
  role = aws_iam_role.flow_logs_role.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ]
      Resource = "${aws_cloudwatch_log_group.vpc_flow_logs.arn}:*"
    }]
  })
}

# -----------------------------
# VPC FLOW LOGS
# -----------------------------
resource "aws_flow_log" "vpc_flow" {
  iam_role_arn         = aws_iam_role.flow_logs_role.arn
  log_destination      = aws_cloudwatch_log_group.vpc_flow_logs.arn
  log_destination_type = "cloud-watch-logs"
  traffic_type         = "ALL"
  vpc_id               = aws_vpc.main.id
}
