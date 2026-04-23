terraform {
  required_version = ">= 1.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# ------------------------
# PROVIDER
# ------------------------
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

# 🔒 BLOQUEAR default security group
resource "aws_default_security_group" "default" {
  vpc_id = aws_vpc.main.id

  ingress = []
  egress  = []
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
    description = "HTTP interno"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["10.1.0.0/16"]
  }

  egress {
    description = "Salida controlada"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["10.1.0.0/16"]
  }
}

# ------------------------
# KMS KEY
# ------------------------
resource "aws_kms_key" "logs_key" {
  description             = "KMS key for CloudWatch Logs"
  deletion_window_in_days = 7
}

# ------------------------
# CLOUDWATCH LOG GROUP
# ------------------------
resource "aws_cloudwatch_log_group" "vpc_flow_logs" {
  name              = "/aws/vpc/flow-logs"
  retention_in_days = 365

  kms_key_id = aws_kms_key.logs_key.arn

  tags = {
    Name = "vpc-flow-logs"
  }
}

# ------------------------
# IAM ROLE
# ------------------------
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

# ------------------------
# IAM POLICY (RESTRINGIDA)
# ------------------------
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
      Resource = aws_cloudwatch_log_group.vpc_flow_logs.arn
    }]
  })
}

# ------------------------
# VPC FLOW LOGS
# ------------------------
resource "aws_flow_log" "vpc_flow_logs" {
  iam_role_arn    = aws_iam_role.flow_logs_role.arn
  log_destination = aws_cloudwatch_log_group.vpc_flow_logs.arn
  traffic_type    = "ALL"
  vpc_id          = aws_vpc.main.id
}

# ------------------------
# EC2
# ------------------------
resource "aws_instance" "ec2" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  subnet_id                   = aws_subnet.subnet_public.id
  vpc_security_group_ids      = [aws_security_group.sg.id]
  associate_public_ip_address = false

  monitoring = true

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "secure-ec2"
  }
}
