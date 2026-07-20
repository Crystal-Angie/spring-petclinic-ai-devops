# ALB Module — IAM role for the AWS Load Balancer Controller
#
# The AWS Load Balancer Controller is a Kubernetes controller that watches
# Ingress resources and creates/manages ALBs in AWS on their behalf.
# It runs as a pod in kube-system and needs AWS permissions via IRSA
# (IAM Roles for Service Accounts) — no static credentials stored in the cluster.

locals {
  # Strip https:// — the OIDC condition key uses the bare URL
  oidc_issuer = replace(var.cluster_oidc_issuer_url, "https://", "")
}

# IAM role assumed by the controller pod via the OIDC provider
resource "aws_iam_role" "alb_controller" {
  name = "${var.cluster_name}-alb-controller"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Principal = {
        Federated = var.oidc_provider_arn
      }
      Action = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = {
          "${local.oidc_issuer}:sub" = "system:serviceaccount:kube-system:aws-load-balancer-controller"
          "${local.oidc_issuer}:aud" = "sts.amazonaws.com"
        }
      }
    }]
  })

  tags = merge(var.tags, { Name = "${var.cluster_name}-alb-controller" })
}

# IAM policy with permissions the controller needs to manage ALBs
resource "aws_iam_policy" "alb_controller" {
  name        = "${var.cluster_name}-alb-controller-policy"
  description = "IAM policy for the AWS Load Balancer Controller"

  policy = file("${path.module}/iam_policy.json")

  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "alb_controller" {
  policy_arn = aws_iam_policy.alb_controller.arn
  role       = aws_iam_role.alb_controller.name
}
