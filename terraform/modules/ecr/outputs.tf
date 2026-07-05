# Outputs from ECR Module

output "repository_urls" {
  description = "Map of repository names to their URLs"
  value = {
    for k, v in aws_ecr_repository.main : k => v.repository_url
  }
}

output "registry_id" {
  description = "The AWS account ID associated with the ECR registries"
  value       = data.aws_caller_identity.current.account_id
}

output "repository_arns" {
  description = "Map of repository names to their ARNs"
  value = {
    for k, v in aws_ecr_repository.main : k => v.arn
  }
}

output "repository_names" {
  description = "List of all ECR repository names"
  value       = [for repo in aws_ecr_repository.main : repo.name]
}

output "log_group_name" {
  description = "CloudWatch log group name for ECR"
  value       = aws_cloudwatch_log_group.ecr.name
}

output "log_group_arn" {
  description = "CloudWatch log group ARN for ECR"
  value       = aws_cloudwatch_log_group.ecr.arn
}

output "docker_login_command" {
  description = "Command to login to ECR"
  value       = "aws ecr get-login-password --region ${data.aws_caller_identity.current.account_id} | docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${data.aws_caller_identity.current.account_id}.amazonaws.com"
  sensitive   = true
}
