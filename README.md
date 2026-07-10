# Spring PetClinic AI DevOps — Production Infrastructure Portfolio

A **production-grade DevOps portfolio project** demonstrating end-to-end infrastructure automation, containerization, Kubernetes deployment, CI/CD, and observability for the Spring PetClinic microservices application.

## Project Goal

Build, containerize, deploy, and monitor a multi-service Spring Boot application on **AWS EKS** using:
- **Infrastructure as Code** (Terraform — modular, reusable)
- **Containerization** (Docker multi-stage builds + ECR)
- **Orchestration** (Kubernetes / EKS)
- **GitOps Deployment** (ArgoCD with sync waves)
- **CI/CD Pipeline** (GitHub Actions with matrix builds)
- **Observability** (Prometheus + Grafana via kube-prometheus-stack)

---

## Architecture Overview

```
Developer pushes code to main
          │
          ▼
  GitHub Actions CI
  ├── Run tests (all pushes/PRs)
  ├── Build 8 Docker images in parallel (main only)
  ├── Push images to AWS ECR
  └── Commit updated image tags to Git
          │
          ▼  ArgoCD detects the git change
  AWS EKS Cluster
  ├── Wave 0: Prometheus + Grafana (monitoring)
  ├── Wave 1: config-server
  ├── Wave 2: discovery-server
  └── Wave 3: api-gateway, customers, vets, visits, admin, genai
          │
          ▼
  AWS ALB → api-gateway → backend services
          │
          ▼
  Prometheus scrapes /actuator/prometheus every 30s
  Grafana displays dashboards
```

---

## Folder Structure

| Folder | Purpose |
|--------|---------|
| `terraform/` | IaC — VPC, EKS, ECR, ALB IAM (modular) |
| `kubernetes/helm-charts/` | Single reusable Helm chart, per-service values |
| `kubernetes/argocd/` | ArgoCD project + application manifests |
| `kubernetes/monitoring/` | kube-prometheus-stack values, ServiceMonitor |
| `docker/` | Multi-stage Dockerfile (shared by all 8 services) |
| `scripts/` | `deploy.sh` and `teardown.sh` |
| `.github/workflows/` | GitHub Actions CI/CD pipeline |
| `docs/` | Architecture guide and operational runbook |
| `app/` | Spring PetClinic microservices source code |

---

## Quick Start

### Prerequisites

```bash
# Required tools
terraform, docker, kubectl, helm, aws cli, git, yq

# AWS credentials
aws configure
aws sts get-caller-identity  # verify
```

### Local Testing (Free)

```bash
# Validate Terraform (no AWS account needed)
docker run -d -p 4566:4566 localstack/localstack:latest
cd terraform/
terraform init && terraform plan

# Validate Helm charts (no cluster needed)
helm lint kubernetes/helm-charts/petclinic-service/ \
  -f kubernetes/helm-charts/petclinic-service/values/api-gateway.yaml

# Test on a local cluster
kind create cluster --name petclinic-dev
helm install api-gateway kubernetes/helm-charts/petclinic-service/ \
  -f kubernetes/helm-charts/petclinic-service/values/api-gateway.yaml \
  -n petclinic --create-namespace
```

### Full AWS Deployment

```bash
# Deploy everything (~20-30 minutes, ~$15-30 total for 2 days)
./scripts/deploy.sh

# Access the application
kubectl get ingress -n petclinic  # Get ALB DNS name

# Access ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080  (admin / password printed by deploy.sh)

# Access Grafana dashboards
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# http://localhost:3000  (admin / petclinic-admin)

# Destroy everything when done (always do this to avoid costs)
./scripts/teardown.sh
```

---

## Project Phases

| Phase | Focus | Status |
|-------|-------|--------|
| 1 | Foundation — folder structure, git, CLAUDE.md | Done |
| 2 | Terraform — VPC, EKS, ECR, ALB modules | Done |
| 3 | Docker — multi-stage Dockerfile, GitHub Actions CI | Done |
| 4 | Helm & ArgoCD — GitOps deployment, sync waves | Done |
| 5 | Networking — ALB Ingress, IRSA for ALB controller | Done |
| 6 | Observability — Prometheus, Grafana, ServiceMonitor | Done |
| 7 | End-to-End CI/CD — image tag automation, deploy/teardown scripts | Done |
| 8 | Documentation & Cleanup — ARCHITECTURE.md, RUNBOOK.md, README | Done |

---

## Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| Cloud | AWS (EKS, VPC, ECR, IAM) | Managed Kubernetes, networking, registry |
| IaC | Terraform (modular) | Infrastructure automation |
| Containers | Docker (multi-stage) | Build and package microservices |
| Orchestration | Kubernetes / EKS | Container scheduling and scaling |
| Packaging | Helm | K8s templating — one chart for all services |
| GitOps | ArgoCD | Declarative deployments with sync waves |
| CI/CD | GitHub Actions | Build, test, push, update tags |
| Observability | Prometheus + Grafana | Metrics, dashboards, alerting |
| Ingress | AWS ALB + IRSA | External traffic routing, no stored credentials |

---

## Key Engineering Decisions

**One Helm chart for all 8 services** — Spring Boot apps share the same structure. A single parameterized chart avoids duplication across 8 near-identical YAML trees.

**IRSA instead of access keys** — The AWS Load Balancer Controller assumes an IAM role via OIDC, with no credentials stored in the cluster.

**Sync waves for startup ordering** — ArgoCD deploys config-server before the apps that depend on it. Wave 0 → 1 → 2 → 3 with health checks between waves.

**Git SHA image tags** — Immutable tags enable exact rollbacks. `latest` is also pushed for convenience but never used for rollback.

**`[skip ci]` pattern** — Job 3 (tag update) commits to the same branch that triggers CI. `[skip ci]` in the commit message breaks the infinite loop.

**Multi-stage Docker builds** — Build tools stay in the builder stage. Runtime images are ~200–300 MB instead of 1–2 GB.

**ECR lifecycle policies** — Keep 10 tagged images, purge untagged after 7 days. Prevents storage cost accumulation.

---

## Cost Estimate

- **Local testing (Phases 1–5)**: $0 — LocalStack, Docker, Kind
- **Real AWS demo (Phases 6–7)**: ~$15–30 for 2 days (EKS + 2× t3.medium + NAT GW + ALB)
- **After teardown**: $0

Always run `./scripts/teardown.sh` after the demo.

---

## Documentation

- [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) — Layer-by-layer architecture with beginner explanations
- [docs/RUNBOOK.md](./docs/RUNBOOK.md) — Deploy, teardown, rollback, and troubleshooting procedures
- [CLAUDE.md](./CLAUDE.md) — Engineering standards, design decisions, project phases

---

## What This Demonstrates

- Modern DevOps practices — Terraform, GitOps, CI/CD, observability
- Cloud architecture — EKS, VPC networking, IRSA security model
- Infrastructure as Code — modular, parameterized, no hardcoded values
- Kubernetes expertise — Helm, ArgoCD, sync waves, health probes
- Cost awareness — local testing first, destroy strategy, lifecycle policies
- Production standards — non-root containers, image scanning, rolling updates

---

**Author**: Angela  
**Last Updated**: July 2026  
**Status**: All 8 phases complete
