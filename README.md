# Spring PetClinic AI DevOps — Production Infrastructure Portfolio

A **production-grade DevOps portfolio project** demonstrating end-to-end infrastructure automation, cloud deployment, and CI/CD workflows for the Spring PetClinic microservices application.

## 🎯 Project Goal

Build, containerize, deploy, and monitor a multi-service Spring Boot application on **AWS EKS** using:
- **Infrastructure as Code** (Terraform)
- **Containerization** (Docker + ECR)
- **Orchestration** (Kubernetes/EKS)
- **Deployment Automation** (GitHub Actions + ArgoCD)
- **Observability** (Prometheus + Grafana)
- **AI-Assisted Workflows** (Claude Code)

## 🏗️ Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                     Git Repository (Source of Truth)             │
│  (Terraform code, K8s manifests, Docker configs, CI/CD)         │
└──────────────────────────┬──────────────────────────────────────┘
                           │
                    ┌──────▼──────┐
                    │ GitHub      │
                    │ Actions CI  │ (Build, test, push images)
                    └──────┬──────┘
                           │
                    ┌──────▼──────────────┐
                    │ AWS ECR             │
                    │ (Container images)  │
                    └──────┬──────────────┘
                           │
       ┌───────────────────┼───────────────────┐
       │                   │                   │
   ┌───▼────┐      ┌───────▼────────┐    ┌───▼─────┐
   │Terraform│      │ ArgoCD         │    │ EKS     │
   │(IaC)    │ ───► │ (GitOps)       │───►│Cluster  │
   └────────┘      │(watches git)   │    └─────────┘
                   └────────────────┘        │
                                             │
                    ┌────────────────────────┼─────────────────┐
                    │                        │                 │
              ┌─────▼──────┐      ┌──────────▼───┐    ┌────────▼───┐
              │Microservices   │ Prometheus │ Grafana │
              │(Pods in K8s)   │(Metrics)   │(Dashboards)│
              └────────────────┘ └────────────┘    └────────────┘
```

## 📂 Folder Structure

| Folder | Purpose |
|--------|---------|
| **terraform/** | Infrastructure as Code (VPC, EKS, ECR, IAM) |
| **kubernetes/** | K8s manifests, Helm charts, ArgoCD configuration |
| **docker/** | Dockerfiles for microservices |
| **scripts/** | Utility scripts (deploy, teardown, validation) |
| **.github/workflows/** | GitHub Actions CI/CD pipelines |
| **docs/** | Architecture & operational documentation |
| **app/** | Spring PetClinic microservices source code |

## 🚀 Quick Start

### Prerequisites
- AWS account with credentials configured
- Terraform, Docker, kubectl, Helm installed
- Git and GitHub CLI

### Phase 1: Local Setup (FREE)
```bash
# 1. Clone this repo
git clone https://github.com/Crystal-Angie/spring-petclinic-ai-devops.git
cd spring-petclinic-ai-devops

# 2. Test Terraform locally with LocalStack
docker run -d -p 4566:4566 localstack/localstack:latest
cd terraform/
terraform init
terraform plan

# 3. Test Kubernetes locally with Kind
kind create cluster --name petclinic-dev
cd ../kubernetes/
helm lint helm-charts/petclinic-gateway/
```

### Phase 2: Real AWS Deployment (MINIMAL COST)
```bash
# 1. Configure Terraform
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
# Edit terraform.tfvars with your values

# 2. Deploy infrastructure
cd terraform/
terraform apply -var-file=terraform.tfvars

# 3. Configure kubectl
aws eks update-kubeconfig --region us-east-1 --name petclinic-prod

# 4. Deploy application via ArgoCD
kubectl apply -f kubernetes/argocd/application.yaml

# 5. Verify deployment
kubectl get pods -n petclinic
kubectl port-forward -n petclinic svc/petclinic-gateway 8080:8080
# Visit http://localhost:8080

# 6. Teardown when done
terraform destroy -var-file=terraform.tfvars
```

## 📊 Project Phases

| Phase | Focus | Status |
|-------|-------|--------|
| **1** | Foundation & Setup | ✅ In Progress |
| **2** | Terraform Infrastructure | 🔄 Next |
| **3** | Docker & CI Pipeline | ⏳ Planned |
| **4** | Helm & ArgoCD | ⏳ Planned |
| **5** | Networking & Ingress | ⏳ Planned |
| **6** | Observability (Prometheus/Grafana) | ⏳ Planned |
| **7** | End-to-End CI/CD | ⏳ Planned |
| **8** | Documentation & Optimization | ⏳ Planned |

## 💰 Cost Estimate

- **Local testing (Phases 1-5)**: $0 (LocalStack, Docker, Kind)
- **Real AWS demo (Phases 6-7)**: $15-30 for ~2 days
- **Ongoing (after teardown)**: $0

See `docs/COST_ANALYSIS.md` for detailed breakdown.

## 📚 Documentation

- **[CLAUDE.md](./CLAUDE.md)** — Project overview, engineering standards, tools
- **[terraform/README.md](./terraform/README.md)** — Terraform usage, modules, setup
- **[docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md)** — Detailed architecture decisions
- **[docs/KUBERNETES.md](./docs/KUBERNETES.md)** — K8s deployment guide
- **[docs/GITOPS.md](./docs/GITOPS.md)** — GitOps with ArgoCD workflow
- **[docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md)** — Common issues & solutions

## 🔧 Technology Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Cloud** | AWS (EKS, VPC, ECR, IAM) | Managed Kubernetes, networking, registry |
| **IaC** | Terraform | Infrastructure automation, modularity |
| **Container** | Docker | Containerization, images |
| **Orchestration** | Kubernetes (EKS) | Container orchestration, scaling |
| **Package Manager** | Helm | K8s templating, deployments |
| **GitOps** | ArgoCD | Declarative deployment, sync |
| **CI/CD** | GitHub Actions | Automated build, test, push |
| **Observability** | Prometheus + Grafana | Metrics, dashboards, alerting |
| **AI Workflow** | Claude Code | Infrastructure automation, code review |

## 🏆 Why This Project?

This portfolio demonstrates:

✅ **Modern DevOps practices** — Terraform, GitOps, CI/CD  
✅ **Cloud architecture** — EKS, VPC, security, networking  
✅ **Infrastructure as Code** — Modular, reusable, parameterized  
✅ **Kubernetes expertise** — Helm, manifests, deployments  
✅ **Observability thinking** — Monitoring, alerting, dashboards  
✅ **Cost consciousness** — Minimal spend, teardown strategies  
✅ **AI integration** — Claude Code for automating workflows  
✅ **Portfolio quality** — Production standards, clean code, documentation  

## 🤝 Contributing

This is a learning project. Contributions, questions, and feedback are welcome.

See [CONTRIBUTING.md](./CONTRIBUTING.md) for guidelines.

## 📖 Learning Path

If you're new to DevOps, follow this order:

1. **Read** `CLAUDE.md` for context
2. **Understand** the architecture in `docs/ARCHITECTURE.md`
3. **Explore** the Terraform code in `terraform/`
4. **Review** K8s manifests in `kubernetes/`
5. **Study** the GitHub Actions workflows in `.github/workflows/`
6. **Deploy** locally with LocalStack (Phase 1-5)
7. **Deploy** to real AWS (Phase 6-7)

## 📝 License

This project is open source. See LICENSE file for details.

## 🎓 Author

Built as a portfolio project to demonstrate DevOps engineering expertise.

**Last Updated**: July 5, 2026  
**Status**: Phase 1 — Foundation setup  
**Next**: Phase 2 — Terraform core infrastructure

---

**Questions?** Review [CLAUDE.md](./CLAUDE.md) or [docs/TROUBLESHOOTING.md](./docs/TROUBLESHOOTING.md).