output "controller_role_arn" {
  description = "IAM role ARN for the AWS Load Balancer Controller — pass to the controller's Helm values as serviceAccount.annotations.eks.amazonaws.com/role-arn"
  value       = aws_iam_role.alb_controller.arn
}
