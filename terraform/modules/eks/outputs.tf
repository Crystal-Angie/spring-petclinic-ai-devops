# Outputs from EKS Module

output "cluster_id" {
  description = "EKS cluster ID"
  value       = aws_eks_cluster.main.id
}

output "cluster_name" {
  description = "EKS cluster name"
  value       = aws_eks_cluster.main.name
}

output "cluster_arn" {
  description = "EKS cluster ARN"
  value       = aws_eks_cluster.main.arn
}

output "cluster_endpoint" {
  description = "EKS cluster API endpoint"
  value       = aws_eks_cluster.main.endpoint
}

output "cluster_version" {
  description = "Kubernetes version running on the cluster"
  value       = aws_eks_cluster.main.version
}

output "cluster_platform_version" {
  description = "Platform version of the EKS cluster"
  value       = aws_eks_cluster.main.platform_version
}

output "cluster_certificate_authority_data" {
  description = "Base64 encoded certificate data required to communicate with the cluster"
  value       = aws_eks_cluster.main.certificate_authority[0].data
  sensitive   = true
}

output "cluster_oidc_issuer_url" {
  description = "The URL on the EKS cluster OIDC Issuer"
  value       = try(aws_eks_cluster.main.identity[0].oidc[0].issuer, null)
}

output "oidc_provider_arn" {
  description = "ARN of the OIDC Provider for IRSA"
  value       = aws_iam_openid_connect_provider.cluster.arn
}

output "node_role_arn" {
  description = "ARN of the node IAM role"
  value       = aws_iam_role.eks_node_role.arn
}

output "node_role_name" {
  description = "Name of the node IAM role"
  value       = aws_iam_role.eks_node_role.name
}

output "node_group_ids" {
  description = "IDs of the EKS node groups"
  value       = [for ng in aws_eks_node_group.main : ng.id]
}

output "node_group_arns" {
  description = "ARNs of the EKS node groups"
  value       = [for ng in aws_eks_node_group.main : ng.arn]
}

output "cluster_log_group_name" {
  description = "Name of the CloudWatch log group for cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.name
}

output "cluster_log_group_arn" {
  description = "ARN of the CloudWatch log group for cluster logs"
  value       = aws_cloudwatch_log_group.eks_cluster.arn
}

output "configure_kubectl" {
  description = "Command to configure kubectl to use this cluster"
  value       = "aws eks update-kubeconfig --region us-east-1 --name ${aws_eks_cluster.main.name}"
}
