# Terraform Infrastructure as Code

This directory contains all Infrastructure as Code (IaC) for deploying the PetClinic application on AWS.

## Overview

**Terraform** is a tool for building, changing, and versioning infrastructure safely and efficiently. This Terraform configuration defines:
- **Networking** (VPC, subnets, security groups)
- **Compute** (EKS cluster, EC2 node groups)
- **Container Registry** (ECR repositories)
- **Monitoring** (CloudWatch, Prometheus, Grafana)
- **IAM Roles** (permissions for all services)

## Folder Structure

```
terraform/
├── main.tf                  # Entry point, provider config, module declarations
├── variables.tf             # Input variables (parameterized config)
├── outputs.tf               # Output values (cluster endpoint, ECR URL, etc.)
├── terraform.tfvars.example # Example values (copy and customize)
├── .gitignore               # Ignore state files, secrets, etc.
├── modules/                 # Reusable Terraform modules
│   ├── networking/
│   ├── eks/
│   ├── ecr/
│   ├── rds/ (optional)
│   └── monitoring/
└── environments/            # Environment-specific configurations
    ├── dev.tfvars
    ├── staging.tfvars
    └── prod.tfvars
```

## How Terraform Works

### 1. Initialize
```bash
cd terraform/
terraform init
```
Downloads provider plugins and sets up working directory.

### 2. Plan (dry-run)
```bash
terraform plan -var-file=terraform.tfvars
```
Shows what Terraform WILL create/change (review before applying).

### 3. Apply (deploy)
```bash
terraform apply -var-file=terraform.tfvars
```
Actually creates the infrastructure on AWS.

### 4. Destroy (teardown)
```bash
terraform destroy -var-file=terraform.tfvars
```
Deletes all infrastructure (useful for cost control).

## Setup Instructions

### Prerequisites
- AWS account with credentials configured: `aws configure`
- Terraform installed: `terraform --version`
- AWS CLI installed: `aws --version`

### Step 1: Configure Variables
```bash
# Copy example to actual config
cp terraform.tfvars.example terraform.tfvars

# Edit with your values
nano terraform.tfvars
```

Key variables to customize:
- `aws_region` — Which AWS region (default: us-east-1)
- `cluster_name` — EKS cluster name (default: petclinic-prod)
- `node_groups` — EC2 instance size and count

### Step 2: Test Locally with LocalStack (Free!)
Before deploying to real AWS, test with LocalStack:

```bash
# Start LocalStack (mocked AWS in Docker)
docker run -d -p 4566:4566 localstack/localstack:latest

# Point Terraform to LocalStack
export AWS_ENDPOINT_URL_S3=http://localhost:4566
export AWS_ACCESS_KEY_ID=test
export AWS_SECRET_ACCESS_KEY=test

# Validate Terraform against mock AWS
terraform init
terraform plan

# After testing, stop LocalStack
docker stop $(docker ps -q --filter ancestor=localstack/localstack)
```

### Step 3: Deploy to Real AWS (Phase 6+)
```bash
# Initialize (if not already done)
terraform init

# Review the plan
terraform plan -var-file=terraform.tfvars

# Apply (create infrastructure)
terraform apply -var-file=terraform.tfvars

# Get outputs (cluster endpoint, ECR URL, etc.)
terraform output
```

### Step 4: Configure kubectl
```bash
# Add cluster to kubeconfig
aws eks update-kubeconfig --region us-east-1 --name petclinic-prod

# Verify connection
kubectl get nodes
```

## Module Documentation

Each module is self-contained and reusable. See module README files:

- **networking** — VPC, subnets, security groups, NAT gateway
- **eks** — Kubernetes cluster, node groups, IAM roles
- **ecr** — Container image registry
- **monitoring** — CloudWatch, Prometheus integration
- **rds** (optional) — Database (RDS PostgreSQL)

## Important Notes

### Never Commit These Files!
- `terraform.tfstate` — Contains infrastructure state (sensitive)
- `terraform.tfstate.backup` — Backup of state
- `.terraform/` — Downloaded provider plugins
- `terraform.tfvars` — Your actual AWS configuration (secrets)

All are in `.gitignore` for security.

### Cost Management
- **Free tier eligible**: t3.micro instances, single AZ
- **Cost optimizations**:
  - Use Spot instances (70% cheaper)
  - Disable NAT Gateway for dev (save $32/month)
  - Schedule teardown when not using: `terraform destroy`
  - Monitor with `aws ce` (cost explorer)

### State File Management
Terraform state file (`terraform.tfstate`) tracks the infrastructure. Never:
- Delete it manually
- Commit to git
- Share with others without encryption

For team/production use, use S3 backend (see `main.tf`).

## Common Commands

```bash
# Validate syntax
terraform validate

# Format code (required before commit)
terraform fmt -recursive

# Plan with specific vars
terraform plan -var-file=environments/prod.tfvars

# Apply with auto-approval (for CI/CD)
terraform apply -auto-approve -var-file=terraform.tfvars

# Destroy specific resource
terraform destroy -target=module.eks.aws_eks_cluster.this

# View current state
terraform state show module.networking.aws_vpc.this

# Get output value
terraform output eks_cluster_endpoint
```

## Troubleshooting

### "Error: error configuring Terraform AWS Provider"
- Verify AWS credentials: `aws sts get-caller-identity`
- Check region is valid: `aws ec2 describe-regions`

### "Error: resource already exists"
- Terraform state is out of sync
- Run: `terraform refresh`

### "Error: You must apply before destroy"
- Terraform resources haven't been created yet
- Run: `terraform apply` first

## Next Steps

1. **Phase 2** — Implement networking module
2. **Phase 3** — Implement EKS module
3. **Phase 4** — Add ECR and monitoring modules
4. **Phase 5** — Deploy to real AWS and validate
5. **Phase 6** — Monitor and optimize

See `CLAUDE.md` for full project roadmap.
