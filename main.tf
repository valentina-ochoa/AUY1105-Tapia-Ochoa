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
# SUBNET
# -----------------------------
resource "aws_subnet" "subnet_public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.1.1.0/24"
  map_public_ip_on_launch = true

  tags = {
    Name = "AUY1105-app-subnet"
  }
}

# -----------------------------
# SECURITY GROUP
# -----------------------------
resource "aws_security_group" "sg" {
  name        = "AUY1105-app-sg"
  description = "Security group SSH restringido"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH solo desde mi IP"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["201.188.31.24/32"]
  }

  egress {
    description = "Salida HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "AUY1105-app-sg"
  }
}

# -----------------------------
# EC2
# -----------------------------
resource "aws_instance" "ec2" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"

  subnet_id              = aws_subnet.subnet_public.id
  vpc_security_group_ids = [aws_security_group.sg.id]

  monitoring = true

  metadata_options {
    http_tokens = "required"
  }

  ebs_optimized = true

  root_block_device {
    encrypted = true
  }

  tags = {
    Name = "AUY1105-app-ec2"
  }
}
