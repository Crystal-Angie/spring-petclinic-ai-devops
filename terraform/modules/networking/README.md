# Networking Module

This module creates the foundational networking infrastructure for the Kubernetes cluster.

## What This Module Creates

- **VPC (Virtual Private Cloud)** — Virtual network for all resources
- **Public Subnets** (2 AZs) — For NAT Gateway, Application Load Balancer, bastion hosts
- **Private Subnets** (2 AZs) — For EKS nodes, RDS, internal services
- **Internet Gateway** — Enables internet connectivity for public subnets
- **NAT Gateway** (optional) — Enables private subnets to access internet for outbound traffic
- **Route Tables** — Traffic routing rules for public and private subnets
- **Security Groups** — Firewall rules for EKS cluster and ALB

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                         VPC (10.0.0.0/16)                   │
├──────────────────────────┬──────────────────────────────────┤
│ Public Subnets (AZ-1, 2) │ Private Subnets (AZ-1, 2)        │
│                          │                                   │
│  ┌──────────────────┐   │ ┌──────────────────┐              │
│  │ NAT Gateway      │   │ │ EKS Nodes        │              │
│  │ ALB              │   │ │ RDS (if used)    │              │
│  │ Bastion Host     │   │ │ Internal Apps    │              │
│  └──────────────────┘   │ └──────────────────┘              │
│         ↓               │         ↓                          │
│  Internet Gateway       └→ NAT Gateway (optional)           │
│         ↓                           ↓                        │
│      Internet ←──────────────────────────────              │
└─────────────────────────────────────────────────────────────┘
```

## Usage

```hcl
module "networking" {
  source = "./modules/networking"

  cluster_name       = "petclinic-prod"
  vpc_cidr           = "10.0.0.0/16"
  enable_nat_gateway = false  # Set to true for production

  tags = {
    Environment = "dev"
    Project     = "petclinic"
  }
}
```

## Inputs

| Variable | Description | Type | Default | Required |
|----------|-------------|------|---------|----------|
| `cluster_name` | Name of the EKS cluster (used for resource naming) | string | — | Yes |
| `vpc_cidr` | CIDR block for the VPC | string | "10.0.0.0/16" | No |
| `enable_nat_gateway` | Enable NAT Gateway (costs ~$32/month) | bool | false | No |
| `tags` | Tags to apply to all resources | map(string) | {} | No |

## Outputs

| Output | Description |
|--------|-------------|
| `vpc_id` | VPC ID |
| `vpc_cidr` | VPC CIDR block |
| `public_subnet_ids` | List of public subnet IDs |
| `private_subnet_ids` | List of private subnet IDs (for EKS nodes) |
| `internet_gateway_id` | Internet Gateway ID |
| `nat_gateway_id` | NAT Gateway ID (null if disabled) |
| `eks_security_group_id` | Security group ID for EKS cluster |
| `alb_security_group_id` | Security group ID for ALB |
| `availability_zones` | List of availability zones used |

## Cost Breakdown

- **Internet Gateway**: Free
- **VPC & Subnets**: Free
- **NAT Gateway** (if enabled): $32/month + $0.045 per GB data transfer
- **Elastic IP** (if NAT enabled): Free (only charges if not attached)

**Recommendation**: Keep `enable_nat_gateway = false` during development/testing to save costs.

## Security Considerations

- **Public Subnets**: Should only contain load balancers and NAT gateways
- **Private Subnets**: Contain EKS nodes and databases (not exposed to internet)
- **Security Groups**: Restrict ingress to minimum required ports
- **Network ACLs**: Consider adding for additional security (future enhancement)

## Subnet Sizing

The module uses `cidrsubnet()` to automatically create subnets:
- VPC: `/16` (65,536 IPs)
- Public subnets: `/20` (4,096 IPs each)
- Private subnets: `/20` (4,096 IPs each)

Total: 2 public + 2 private subnets = 4 subnets from a /16 CIDR

## Dependencies

None — This module is the foundation for other modules (EKS, RDS, etc.)

## Example

```hcl
# main.tf
module "networking" {
  source = "./modules/networking"

  cluster_name       = var.cluster_name
  vpc_cidr           = var.vpc_cidr
  enable_nat_gateway = var.enable_nat_gateway

  tags = var.common_tags
}

# Use outputs in other modules
module "eks" {
  source = "./modules/eks"

  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  security_group_id   = module.networking.eks_security_group_id
  # ... other variables
}
```

## Notes

- The module creates subnets across 2 availability zones automatically for high availability
- Subnet CIDR allocation is deterministic (same inputs = same subnets)
- All resources are tagged with the cluster name for easy identification
- Security groups are created with lifecycle rules to avoid conflicts during updates
