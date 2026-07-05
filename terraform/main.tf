terraform {
  required_version = ">= 1.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Backend configuration for storing Terraform state
  # For testing: use local backend (default)
  # For production: use S3 backend with DynamoDB locking
  backend "local" {
    path = "terraform.tfstate"
  }

  # Uncomment for S3 backend in production:
  # backend "s3" {
  #   bucket         = "petclinic-terraform-state"
  #   key            = "prod/terraform.tfstate"
  #   region         = "us-east-1"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
}

# AWS Provider Configuration
provider "aws" {
  region = var.aws_region

  default_tags {
    tags = var.common_tags
  }
}

# Data source to get current AWS account ID
data "aws_caller_identity" "current" {}

# Data source to get availability zones in the region
data "aws_availability_zones" "available" {
  state = "available"
}

# Local variables for common values
locals {
  cluster_name = var.cluster_name
  environment  = var.environment
  region       = var.aws_region
}

# ============================================================================
# PHASE 2: Infrastructure Modules (to be implemented)
# ============================================================================

# module "networking" {
#   source = "./modules/networking"
#
#   vpc_cidr              = var.vpc_cidr
#   cluster_name          = local.cluster_name
#   enable_nat_gateway    = var.enable_nat_gateway
#
#   tags = var.common_tags
# }

# module "eks" {
#   source = "./modules/eks"
#
#   cluster_name           = local.cluster_name
#   kubernetes_version     = var.kubernetes_version
#   vpc_id                 = module.networking.vpc_id
#   subnet_ids             = module.networking.private_subnet_ids
#   node_groups            = var.node_groups
#
#   depends_on = [module.networking]
#   tags       = var.common_tags
# }

# module "ecr" {
#   source = "./modules/ecr"
#
#   repository_name = local.cluster_name
#
#   tags = var.common_tags
# }

# module "monitoring" {
#   source = "./modules/monitoring"
#
#   cluster_name = local.cluster_name
#
#   tags = var.common_tags
# }
