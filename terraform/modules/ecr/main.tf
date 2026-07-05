# ECR Module - Elastic Container Registry for Docker Images
# This module creates private container image repositories

# ECR Repository for each microservice
resource "aws_ecr_repository" "main" {
  for_each = var.repositories

  name                 = each.value.name
  image_tag_mutability = each.value.image_tag_mutability
  force_delete         = true # Allow terraform destroy to delete repository with images

  image_scanning_configuration {
    scan_on_push = each.value.scan_on_push
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    var.tags,
    {
      Name = each.value.name
    }
  )
}

# ECR Lifecycle Policy - clean up old images
resource "aws_ecr_lifecycle_policy" "main" {
  for_each = var.repositories

  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last ${each.value.keep_image_count} images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = each.value.keep_image_count
        }
        action = {
          type = "expire"
        }
      },
      {
        rulePriority = 2
        description  = "Delete untagged images after ${each.value.untagged_image_expiry_days} days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = each.value.untagged_image_expiry_days
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# ECR Repository Policy - allow EKS nodes to pull images
resource "aws_ecr_repository_policy" "main" {
  for_each = var.repositories

  repository = aws_ecr_repository.main[each.key].name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowEKSNodesPull"
        Effect = "Allow"
        Principal = {
          AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetAuthorizationToken"
        ]
      },
      {
        Sid    = "AllowPullPush"
        Effect = "Allow"
        Principal = {
          AWS = var.allowed_push_arns
        }
        Action = [
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
      }
    ]
  })
}

# Data source for current AWS account ID
data "aws_caller_identity" "current" {}

# CloudWatch Log Group for ECR image scanning
resource "aws_cloudwatch_log_group" "ecr" {
  name              = "/aws/ecr/${var.cluster_name}"
  retention_in_days = var.log_retention_days

  tags = merge(
    var.tags,
    {
      Name = "${var.cluster_name}-ecr-logs"
    }
  )
}
