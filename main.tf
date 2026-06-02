terraform {
  required_version = ">= 1.0.0"

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

module "vpc" {
  source = "git::https://github.com/valentina-ochoa/terraform-aws-vpc-AUY1105.OT.git?ref=v0.1.0"

  vpc_cidr    = "10.1.0.0/16"
  subnet_cidr = "10.1.1.0/24"

  vpc_name    = "secure-vpc"
  subnet_name = "secure-subnet"
  sg_name     = "secure-sg"
}

module "ec2" {
  source = "git::https://github.com/valentina-ochoa/terraform-aws-ec2-AUY1105-OT.git?ref=v0.2.0"

  ami_id            = "ami-0c55b159cbfafe1f0"
  instance_type     = "t2.micro"
  subnet_id         = module.vpc.subnet_ids
  security_group_id = module.vpc.security_group_id

  instance_name = "secure-ec2"
}
