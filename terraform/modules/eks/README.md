# EKS Module

This module creates an Amazon EKS (Elastic Kubernetes Service) cluster with managed node groups.

## What This Module Creates

- **EKS Cluster** — Kubernetes control plane managed by AWS
- **Node Groups** — Auto-scaling EC2 instances that run containers
- **IAM Roles** — Permissions for cluster and nodes
- **OIDC Provider** — For IAM Roles for Service Accounts (IRSA)
- **CloudWatch Logs** — Cluster audit, API, and scheduler logs
- **Security** — VPC integration, security groups, network policies ready

## Architecture

```
┌─────────────────────────────────────────────────────┐
│           EKS Cluster (Kubernetes Control Plane)    │
│  - API Server, etcd, Scheduler, Controller Manager  │
│  - AWS Managed (no operational overhead)            │
└──────────────────┬──────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
   ┌────▼────┐          ┌────▼────┐
   │ Node     │          │ Node     │
   │ Group 1  │          │ Group N  │
   │ (2-5     │          │ (custom  │
   │ t3.med)  │          │ config)  │
   └──────────┘          └──────────┘
        │                     │
   ┌────▼─────────────────────▼────┐
   │  Private Subnets (from VPC)    │
   │  NAT → Internet (if enabled)   │
   └────────────────────────────────┘
```

## Usage

```hcl
module "eks" {
  source = "./modules/eks"

  cluster_name        = "petclinic-prod"
  kubernetes_version  = "1.31"
  vpc_id              = module.networking.vpc_id
  private_subnet_ids  = module.networking.private_subnet_ids
  public_subnet_ids   = module.networking.public_subnet_ids
  security_group_id   = module.networking.eks_security_group_id

  node_groups = {
    general = {
      desired_size   = 2
      min_size       = 1
      max_size       = 5
      instance_types = ["t3.medium"]
      disk_size      = 50
      labels = {
        workload = "general"
      }
    }
  }

  tags = var.common_tags
}
```

## Inputs

| Variable | Description | Type | Required |
|----------|-------------|------|----------|
| `cluster_name` | EKS cluster name | string | Yes |
| `vpc_id` | VPC ID for the cluster | string | Yes |
| `private_subnet_ids` | Private subnets for nodes | list(string) | Yes |
| `public_subnet_ids` | Public subnets (for ALB) | list(string) | Yes |
| `security_group_id` | Security group for cluster | string | Yes |
| `kubernetes_version` | K8s version | string | "1.31" |
| `node_groups` | Node group config | map(object) | See defaults |
| `log_retention_days` | CloudWatch log retention | number | 7 |
| `tags` | Resource tags | map(string) | {} |

## Outputs

| Output | Description |
|--------|-------------|
| `cluster_id` | EKS cluster ID |
| `cluster_endpoint` | Kubernetes API endpoint |
| `cluster_version` | Kubernetes version |
| `cluster_oidc_issuer_url` | OIDC provider URL (for IRSA) |
| `oidc_provider_arn` | OIDC provider ARN |
| `node_role_arn` | ARN of node IAM role |
| `node_group_ids` | List of node group IDs |
| `configure_kubectl` | Command to configure kubectl |

## Cost Breakdown

- **EKS Cluster Management**: $73/month
- **Node Groups (t3.medium, 2 nodes)**: ~$30-50/month
- **Total (minimum)**: ~$103-123/month

**Cost Optimization**:
- Use Spot instances (70% savings)
- Scale down when not in use
- Use smaller instance types for dev (t3.micro)

## Node Groups

The module supports multiple node groups with different configurations:

```hcl
node_groups = {
  general = {
    desired_size   = 2
    min_size       = 1
    max_size       = 5
    instance_types = ["t3.medium"]
    disk_size      = 50
    labels = { workload = "general" }
  }
  compute = {
    desired_size   = 1
    min_size       = 0
    max_size       = 10
    instance_types = ["c5.large"]
    disk_size      = 100
    labels = { workload = "compute" }
  }
}
```

This allows running different workload types on different instance sizes.

## Security Features

- **IRSA (IAM Roles for Service Accounts)** — Pods can assume IAM roles
- **VPC Integration** — Cluster in private subnets (not internet-exposed)
- **Security Groups** — Network ACLs restrict traffic
- **RBAC** — Kubernetes role-based access control (managed separately)
- **Audit Logs** — CloudWatch logs of all API calls

## Kubeconfig Configuration

After applying, configure kubectl:

```bash
aws eks update-kubeconfig --region us-east-1 --name petclinic-prod
kubectl get nodes  # Verify connection
```

## Updating Cluster Version

To update Kubernetes version:

```hcl
kubernetes_version = "1.32"
```

Then:
```bash
terraform plan   # Review changes
terraform apply  # Update cluster (takes 30-60 min)
```

## Troubleshooting

**Nodes not joining cluster**:
- Check security group allows communication
- Verify IAM role has correct policies
- Check EC2 instance logs: `aws ec2 describe-instances`

**kubectl can't connect**:
```bash
aws eks update-kubeconfig --region us-east-1 --name YOUR_CLUSTER
aws sts get-caller-identity  # Verify credentials
```

**Pods can't pull images from ECR**:
- Ensure `ecr_pull_policy` is attached to node role
- Check node role has ECR permissions

## Dependencies

- VPC and subnets from networking module
- Security groups from networking module
- AWS account with EKS permissions

## Next Steps

1. Deploy EKS cluster: `terraform apply`
2. Install metrics server: `kubectl apply -f ...`
3. Install Ingress controller: Helm chart
4. Deploy applications via Helm/ArgoCD
