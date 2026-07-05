# ECR Module

This module creates private Docker image repositories in AWS Elastic Container Registry (ECR).

## What This Module Creates

- **ECR Repositories** — Private registries for each microservice
- **Lifecycle Policies** — Automatic cleanup of old/untagged images
- **Repository Policies** — Access control for pushing and pulling images
- **CloudWatch Logs** — Logging for image scanning and events

## Architecture

```
┌─────────────────────────────────────────────────┐
│  AWS Elastic Container Registry (ECR)           │
├─────────────────────────────────────────────────┤
│                                                  │
│  ┌─────────────────┐  ┌─────────────────┐     │
│  │ api-gateway     │  │ customers-svc   │ ... │
│  │ - image tags    │  │ - image tags    │     │
│  │ - lifecycle     │  │ - lifecycle     │     │
│  │ - scanning      │  │ - scanning      │     │
│  └─────────────────┘  └─────────────────┘     │
│                                                  │
│  Access:                                         │
│  - EKS nodes pull images (read)                 │
│  - CI/CD pushes images (write)                  │
│  - Developers query images (read)               │
│                                                  │
└─────────────────────────────────────────────────┘
```

## Usage

```hcl
module "ecr" {
  source = "./modules/ecr"

  cluster_name = "petclinic-prod"

  repositories = {
    gateway = {
      name                      = "petclinic/api-gateway"
      image_tag_mutability      = "MUTABLE"
      scan_on_push              = false
      keep_image_count          = 10
      untagged_image_expiry_days = 7
    }
    customers = {
      name                      = "petclinic/customers-service"
      image_tag_mutability      = "MUTABLE"
      scan_on_push              = false
      keep_image_count          = 10
      untagged_image_expiry_days = 7
    }
  }

  allowed_push_arns = [
    "arn:aws:iam::123456789012:role/github-actions-role"
  ]

  tags = var.common_tags
}
```

## Inputs

| Variable | Description | Type | Required |
|----------|-------------|------|----------|
| `cluster_name` | Cluster name for resource naming | string | Yes |
| `repositories` | Map of repository configurations | map(object) | Yes |
| `allowed_push_arns` | ARNs allowed to push images (CI/CD) | list(string) | No |
| `log_retention_days` | CloudWatch log retention | number | 7 |
| `tags` | Resource tags | map(string) | {} |

## Repository Configuration

Each repository needs:
- `name` — Repository path (e.g., "petclinic/api-gateway")
- `image_tag_mutability` — Allow retag same image? (MUTABLE/IMMUTABLE)
- `scan_on_push` — Scan images for vulnerabilities?
- `keep_image_count` — How many recent images to keep
- `untagged_image_expiry_days` — Delete untagged images after X days

## Outputs

| Output | Description |
|--------|-------------|
| `repository_urls` | Map of repository URLs for pushing images |
| `registry_id` | AWS account ID for ECR registry |
| `repository_arns` | ARNs of all repositories |
| `repository_names` | List of repository names |
| `docker_login_command` | Command to authenticate Docker with ECR |

## Cost Breakdown

- **Storage**: $0.10 per GB/month
- **Data Transfer** (out): $0.02 per GB
- **Scanning** (if enabled): $0.20 per image scanned
- **Minimal for dev**: < $1/month

## Pushing Images to ECR

```bash
# Login to ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  123456789012.dkr.ecr.us-east-1.amazonaws.com

# Tag and push image
docker tag myapp:latest 123456789012.dkr.ecr.us-east-1.amazonaws.com/petclinic/api-gateway:latest
docker push 123456789012.dkr.ecr.us-east-1.amazonaws.com/petclinic/api-gateway:latest

# Or use terraform output
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  $(terraform output -raw registry_id).dkr.ecr.us-east-1.amazonaws.com
```

## Lifecycle Policy

The module automatically creates lifecycle policies that:

1. **Keep last N images**: Retains the most recent images
2. **Delete untagged images**: Cleans up builds without tags after X days

This prevents repository growth and reduces storage costs.

## Image Scanning

Optional vulnerability scanning:

```hcl
scan_on_push = true  # Enable image scanning
```

Scanning catches security vulnerabilities in dependencies (requires cost).

## Access Control

### Push Access (CI/CD)
```hcl
allowed_push_arns = [
  "arn:aws:iam::123456789012:role/github-actions-role"
]
```

### Pull Access (EKS Nodes)
Automatically allowed via EKS node IAM role (set in eks module).

### Manual Pull
```bash
aws ecr describe-repositories
aws ecr describe-images --repository-name petclinic/api-gateway
```

## Tag Strategy

Recommended image tagging:
- `latest` — Latest build (mutable)
- `v1.0.0` — Semantic version (immutable)
- `main-abc123` — Git branch and commit
- `staging` — Staging environment

## Cleanup

To prevent costs from accumulating:

1. **Lifecycle policies** automatically remove old images
2. **Monitor repository size**: `aws ecr describe-repositories`
3. **Delete entire repo** (if needed): `terraform destroy`

## Troubleshooting

**Can't push to ECR**:
```bash
aws sts get-caller-identity  # Verify IAM permissions
aws ecr get-authorization-token  # Get auth token
```

**Image not found when pulling**:
- Verify image exists: `aws ecr describe-images --repository-name X`
- Check EKS node can access ECR (IAM role)
- Verify correct image URI in K8s manifests

**Repository policy errors**:
- Check ARNs are correctly formatted
- Verify IAM role exists before referencing

## Integration with EKS

EKS nodes automatically pull from ECR using the node IAM role.
In Kubernetes manifests, reference images as:

```yaml
image: 123456789012.dkr.ecr.us-east-1.amazonaws.com/petclinic/api-gateway:v1.0.0
```

Or with imagePullSecrets if needed:

```yaml
imagePullSecrets:
  - name: ecr-credentials
```

## Next Steps

1. Create repositories with this module
2. Configure CI/CD to push images (Phase 3)
3. Deploy Kubernetes pods referencing images
4. Monitor image sizes and cleanup
