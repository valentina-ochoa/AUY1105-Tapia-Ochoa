#############################################
# TERRAFORM CONFIG
#############################################
terraform {
  required_version = ">= 1.5.0"

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
# DATA
#############################################
data "aws_caller_identity" "current" {}

#############################################
# VPC
#############################################
resource "aws_vpc" "main" {
  cidr_block = "10.1.0.0/16"

  tags = {
    Name = "AUY1105-buymax-vpc"
  }
}

#############################################
# SUBNET PRIVADA (MEJOR PRÁCTICA)
#############################################
resource "aws_subnet" "subnet_private" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = false

  tags = {
    Name = "AUY1105-buymax-subnet"
  }
}

#############################################
# SECURITY GROUP (SOLO SSH SEGURO)
#############################################
resource "aws_security_group" "sg" {
  name        = "AUY1105-buymax-sg"
  description = "Allow SSH only from trusted IP"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH from trusted IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["201.188.31.24/32"] # 
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

#############################################
# EC2 SEGURA (FIX t3.micro + Ubuntu 24.04)
#############################################
resource "aws_instance" "ec2" {
  ami           = "ami-0a0e5d9c7acc336f1" # Ubuntu 24.04 LTS (us-east-1)
  instance_type = "t3.micro"

  subnet_id              = aws_subnet.subnet_private.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  associate_public_ip_address = false

  monitoring    = true
  ebs_optimized = true

  root_block_device {
    encrypted = true
  }

  metadata_options {
    http_tokens = "required"
  }

  tags = {
    Name = "AUY1105-buymax-ec2"
  }
}
