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
# PHASE 2: Infrastructure Modules
# ============================================================================

# Networking Module - Creates VPC, subnets, security groups
module "networking" {
  source = "./modules/networking"

  cluster_name       = local.cluster_name
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway

  tags = var.common_tags
}

# EKS Module - Creates Kubernetes cluster and node groups
module "eks" {
  source = "./modules/eks"

  cluster_name       = local.cluster_name
  kubernetes_version = var.kubernetes_version
  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.private_subnet_ids
  public_subnet_ids  = module.networking.public_subnet_ids
  security_group_id  = module.networking.eks_security_group_id
  node_groups        = var.node_groups

  depends_on = [module.networking]
  tags       = var.common_tags
}

# ECR Module - Creates private container image repositories
module "ecr" {
  source = "./modules/ecr"

  cluster_name = local.cluster_name
  repositories = {
    gateway = {
      name                       = "petclinic/api-gateway"
      image_tag_mutability       = "MUTABLE"
      scan_on_push               = false
      keep_image_count           = 10
      untagged_image_expiry_days = 7
    }
    customers = {
      name                       = "petclinic/customers-service"
      image_tag_mutability       = "MUTABLE"
      scan_on_push               = false
      keep_image_count           = 10
      untagged_image_expiry_days = 7
    }
    visits = {
      name                       = "petclinic/visits-service"
      image_tag_mutability       = "MUTABLE"
      scan_on_push               = false
      keep_image_count           = 10
      untagged_image_expiry_days = 7
    }
    vets = {
      name                       = "petclinic/vets-service"
      image_tag_mutability       = "MUTABLE"
      scan_on_push               = false
      keep_image_count           = 10
      untagged_image_expiry_days = 7
    }
  }

  tags = var.common_tags
}

# Monitoring Module (Phase 6 - to be implemented)
# module "monitoring" {
#   source = "./modules/monitoring"
#
#   cluster_name = local.cluster_name
#
#   tags = var.common_tags
# }
