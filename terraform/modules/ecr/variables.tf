# Input Variables for ECR Module

variable "cluster_name" {
  description = "Cluster name (used for resource naming)"
  type        = string
}

variable "repositories" {
  description = "Map of ECR repositories to create"
  type = map(object({
    name                       = string
    image_tag_mutability       = string
    scan_on_push               = bool
    keep_image_count           = number
    untagged_image_expiry_days = number
  }))

  default = {
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
}

variable "allowed_push_arns" {
  description = "List of ARNs allowed to push images to ECR (e.g., CI/CD role ARNs)"
  type        = list(string)
  default     = []
}

variable "log_retention_days" {
  description = "CloudWatch log retention in days"
  type        = number
  default     = 7
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default = {
    Terraform   = "true"
    Environment = "dev"
  }
}
