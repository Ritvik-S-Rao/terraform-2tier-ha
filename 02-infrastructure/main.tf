data "aws_ssm_parameter" "rds_password" {
  name            = "/devops-2tier/database/master-password"
  with_decryption = true
}

terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "us-east-1"
}

module "network" {
  source = "./modules/network"

  vpc_cidr                  = "10.0.0.0/16"
  public_subnet_cidrs       = ["10.0.1.0/24", "10.0.2.0/24"]
  private_app_subnet_cidrs  = ["10.0.3.0/24", "10.0.4.0/24"]
  private_data_subnet_cidrs = ["10.0.5.0/24", "10.0.6.0/24"]
  availability_zones        = ["us-east-1a", "us-east-1b"]
}

module "security" {
  source = "./modules/security"
  vpc_id = module.network.vpc_id
}

module "compute" {
  source = "./modules/compute"

  vpc_id                 = module.network.vpc_id
  public_subnet_ids      = module.network.public_subnet_ids
  private_app_subnet_ids = module.network.private_app_subnet_ids

  alb_security_group_id = module.security.alb_security_group_id
  app_security_group_id = module.security.app_security_group_id
}

module "database" {
  source = "./modules/database"

  private_data_subnet_ids = module.network.private_data_subnet_ids
  db_security_group_id    = module.security.db_security_group_id
  db_password             = data.aws_ssm_parameter.rds_password.value
}
