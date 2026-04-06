terraform {
  required_version = ">= 1.5.0"

  backend "s3" {
    bucket = "starttech-terraform-state-954692413962"
    key    = "production/terraform.tfstate"
    region = "us-east-1"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "./modules/networking"

  project_name = var.project_name
  environment  = var.environment
  vpc_cidr     = var.vpc_cidr
}

module "compute" {
  source = "./modules/compute"

  project_name          = var.project_name
  environment           = var.environment
  vpc_id                = module.networking.vpc_id
  public_subnets        = module.networking.public_subnet_ids
  private_subnets       = module.networking.private_subnet_ids
  ec2_security_group_id = module.networking.ec2_security_group_id
  alb_security_group_id = module.networking.alb_security_group_id
}

module "storage" {
  source = "./modules/storage"

  project_name            = var.project_name
  environment             = var.environment
  private_subnets         = module.networking.private_subnet_ids
  redis_security_group_id = module.networking.redis_security_group_id
}

module "monitoring" {
  source = "./modules/monitoring"

  project_name = var.project_name
  environment  = var.environment
  asg_name     = module.compute.asg_name
  alb_arn      = module.compute.alb_arn
}
