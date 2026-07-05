# Outputs from Terraform modules
# These values are printed after 'terraform apply' and can be used by other tools

# EKS Cluster Outputs
output "eks_cluster_id" {
  description = "EKS cluster ID"
  value       = try(module.eks.cluster_id, "")
}

output "eks_cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = try(module.eks.cluster_endpoint, "")
}

output "eks_cluster_arn" {
  description = "EKS cluster ARN"
  value       = try(module.eks.cluster_arn, "")
}

output "eks_cluster_name" {
  description = "EKS cluster name"
  value       = var.cluster_name
}

# ECR Repository Outputs
output "ecr_repository_url" {
  description = "ECR repository URL for pushing images"
  value       = try(module.ecr.repository_url, "")
}

output "ecr_repository_name" {
  description = "ECR repository name"
  value       = try(module.ecr.repository_name, "")
}

# VPC Outputs
output "vpc_id" {
  description = "VPC ID"
  value       = try(module.networking.vpc_id, "")
}

output "private_subnet_ids" {
  description = "List of private subnet IDs"
  value       = try(module.networking.private_subnet_ids, [])
}

output "public_subnet_ids" {
  description = "List of public subnet IDs"
  value       = try(module.networking.public_subnet_ids, [])
}

# IAM Outputs
output "eks_node_role_arn" {
  description = "ARN of EKS node IAM role"
  value       = try(module.eks.node_role_arn, "")
}

# Kubeconfig Output
output "configure_kubectl" {
  description = "Command to configure kubectl"
  value       = "aws eks update-kubeconfig --region ${var.aws_region} --name ${var.cluster_name}"
}
