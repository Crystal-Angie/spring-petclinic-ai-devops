# Spring PetClinic AI DevOps — Architecture & Engineering Guide

## Project Overview

This is a **production-grade DevOps portfolio project** demonstrating end-to-end infrastructure automation, Kubernetes deployment, and CI/CD workflows for the Spring PetClinic microservices application.

**Goal**: Build, deploy, and monitor a multi-service application on AWS EKS using Infrastructure as Code (Terraform), GitOps (ArgoCD), and observability (Prometheus + Grafana).

## Key Information

### Repositories
- **This repo** (DevOps infrastructure): https://github.com/Crystal-Angie/spring-petclinic-ai-devops
- **Application** (upstream): https://github.com/Crystal-Angie/spring-petclinic-microservices (main/master branch)

### Technology Stack
- **Cloud**: AWS (us-east-1)
- **Infrastructure**: Terraform (modular)
- **Kubernetes**: EKS (managed)
- **Container Registry**: ECR
- **Deployment**: Helm + ArgoCD (GitOps)
- **CI/CD**: GitHub Actions
- **Observability**: Prometheus + Grafana
- **Networking**: ALB Ingress, Route53 (Phase 5+)

### Project Phases
1. **Foundation** — Folder structure, git setup, CLAUDE.md
2. **Terraform** — VPC, EKS, ECR, IAM (tested against LocalStack)
3. **Docker** — Dockerfiles, GitHub Actions CI pipeline
4. **Helm & ArgoCD** — Kubernetes manifests, GitOps deployment
5. **Networking** — Ingress, LoadBalancer, custom domain (future)
6. **Observability** — Prometheus, Grafana dashboards
7. **End-to-End CI/CD** — Full pipeline validation on real AWS
8. **Documentation & Cleanup** — Runbooks, teardown, optimization

### Testing Strategy
- **Phases 1-5**: Test locally (LocalStack, Docker Compose, Minikube/Kind)
- **Phases 6-7**: Deploy to real AWS (~1-2 days)
- **Cost**: $0 during testing, $15-30 for real AWS validation, then destroy

### Folder Structure
```
.
├── terraform/              # Infrastructure as Code (modular)
│   ├── modules/
│   ├── environments/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
├── kubernetes/            # K8s manifests & Helm charts
│   ├── helm-charts/
│   ├── argocd/
│   └── monitoring/
├── docker/                # Dockerfiles for services
├── scripts/               # Utility scripts (deploy, teardown, etc.)
├── .github/workflows/     # GitHub Actions CI/CD pipelines
├── .claude/               # Claude Code configuration
│   └── hooks/             # Pre-commit automation
├── docs/                  # Architecture & operational documentation
├── app/                   # Spring PetClinic microservices (subdir)
└── .gitignore             # Ignore patterns
```

## Engineering Standards

### Commit Strategy
- **Atomic commits**: One logical unit per commit
- **Format**: `type(scope): brief description`
- **Types**: feat, fix, docs, refactor, chore, test
- **Example**: `feat(terraform): add VPC module with configurable CIDR`

### Git Flow
- `main` is production-ready (protected, requires PR review)
- Feature branches: `feature/phase-X-description`
- Squash and merge to keep history clean

### Terraform Modules
- Every module is **reusable** and **parameterized**
- No hardcoded values (use variables.tf)
- Each module has: main.tf, variables.tf, outputs.tf, README.md

### Kubernetes Manifests
- Use **Helm charts** for templating (no raw YAML with hardcoded values)
- Production best practices: resource requests/limits, health checks, security contexts
- Organized by service/component

### Code Quality
- Pre-commit hooks: terraform fmt, yamllint, secrets detection
- Code review via `/code-review` skill for best practices
- Portfolio-ready: clean, documented, production-quality code

## Key Architecture Decisions & Rationale

| Decision | Why | Alternative | Trade-off |
|----------|-----|-------------|-----------|
| **Terraform** | Cloud-agnostic, modular, industry standard | CloudFormation, CDK | More files, but very flexible |
| **EKS** | Managed control plane, AWS integration | Self-managed K8s | Less control, but less ops burden |
| **ArgoCD** | GitOps, full audit trail, easy rollback | kubectl apply | Extra tool, but production-grade |
| **Helm** | Standard K8s templating, reusable | Raw YAML | Learning curve, but industry standard |
| **LocalStack testing** | Validate Terraform locally for free | Deploy to AWS, iterate | Catches bugs before real costs |
| **Kind for testing** | Lightweight, fast, Docker-based | Minikube | Less mature, but perfect for testing |

## Workflow Best Practices

1. **Always test locally first** (LocalStack, Docker Compose, Kind)
2. **Every change is a commit** — meaningful history for portfolio review
3. **Explain the why** — not just what code does, but why we chose this approach
4. **Modular design** — terraform modules, helm charts, scripts are reusable
5. **No hardcoded values** — everything parameterized via variables/values
6. **Production standards** — not shortcuts; this is portfolio work

## Local Development Setup

### Required Tools
- Terraform
- Docker + Docker Compose
- kubectl, Helm
- Kind (lightweight Kubernetes)
- LocalStack (mock AWS)
- AWS CLI
- GitHub CLI
- Git

### Quick Start
```bash
# Install LocalStack (mock AWS in Docker)
docker run -d -p 4566:4566 localstack/localstack:latest

# Start Kind cluster
kind create cluster --name petclinic-dev

# Validate Terraform against LocalStack
cd terraform/
terraform init
terraform plan

# Deploy to local Kind cluster
cd ../kubernetes/
helm lint helm-charts/petclinic-gateway/
helm install petclinic helm-charts/petclinic-gateway/ -f helm-charts/petclinic-gateway/values-dev.yaml
```

## AWS Account Setup (for Phase 6+)

When ready to deploy to real AWS:
1. AWS credentials configured locally (`aws configure`)
2. Set Terraform to point to real AWS (not LocalStack)
3. Deploy infrastructure: `terraform apply`
4. Validate on real AWS
5. Destroy after testing: `terraform destroy`

## Resources & Documentation

- **Architecture details**: See `docs/ARCHITECTURE.md`
- **Terraform usage**: See `terraform/modules/*/README.md`
- **Kubernetes deployment**: See `docs/KUBERNETES.md`
- **GitOps workflow**: See `docs/GITOPS.md`
- **Troubleshooting**: See `docs/TROUBLESHOOTING.md`
- **Cost analysis**: See `docs/COST_ANALYSIS.md`

## Contact & Questions

This is a learning project. Every design decision has a rationale. If something seems unclear, ask — it's a chance to explain the thinking.

---

**Last updated**: July 5, 2026
**Status**: Phase 1 — Foundation setup
**Next**: Phase 2 — Terraform core infrastructure
