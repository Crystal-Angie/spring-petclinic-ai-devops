# Architecture — Spring PetClinic AI DevOps

This document explains the architecture of the project: what each layer does, why it was designed that way, and how the pieces connect.

---

## High-Level Overview

```
Developer pushes code
        │
        ▼
GitHub Actions (CI)
  ├── Run tests
  ├── Build Docker images (8 services, in parallel)
  ├── Push images to AWS ECR
  └── Update image tags in Git (Helm values)
        │
        ▼  ArgoCD detects the git change
AWS EKS Cluster
  ├── config-server        (wave 1 — starts first)
  ├── discovery-server     (wave 2 — registers services)
  ├── api-gateway          (wave 3 — public entry point)
  ├── customers-service    (wave 3)
  ├── vets-service         (wave 3)
  ├── visits-service       (wave 3)
  ├── admin-server         (wave 3)
  ├── genai-service        (wave 3)
  └── monitoring stack     (wave 0 — always running)
        │
        ▼
AWS ALB (Application Load Balancer)
  └── Routes traffic into the cluster
        │
        ▼
Prometheus scrapes /actuator/prometheus from every service
Grafana displays metrics dashboards
```

---

## Layer 1: Networking (Terraform)

### What it is
A Virtual Private Cloud (VPC) — a private, isolated network in AWS where all resources live.

### What we built
- **VPC**: `10.0.0.0/16` — 65,536 possible IP addresses
- **Public subnets** (2): Where the load balancer lives. Internet can reach these.
- **Private subnets** (2): Where the Kubernetes nodes (EC2 instances) live. Internet cannot reach these directly.
- **Internet Gateway**: The door between the public subnets and the internet.
- **NAT Gateway**: Lets private-subnet nodes reach the internet (to pull Docker images, etc.) without being reachable from outside.
- **Security Groups**: Firewalls that control which traffic is allowed in/out.

### Why this layout?
Nodes in private subnets is a security best practice — attackers can't SSH directly into them. The load balancer in public subnets is the only public entry point. This is what AWS calls a "public/private subnet architecture."

---

## Layer 2: EKS Cluster (Terraform)

### What it is
Amazon EKS (Elastic Kubernetes Service) — a managed Kubernetes cluster. AWS runs the Kubernetes control plane (the "brain" of the cluster). We pay only for the worker nodes (EC2 instances that run our pods).

### What we built
- **EKS Cluster**: Kubernetes 1.31, control plane managed by AWS
- **Managed Node Group**: `t3.medium` instances (2 vCPU, 4 GB), scales from 1–3 nodes
- **OIDC Provider**: Enables IRSA — pods can assume IAM roles without stored credentials
- **CloudWatch Log Group**: Cluster logs (API server, scheduler, etc.)

### Why t3.medium?
It's the smallest instance that comfortably runs 8 Spring Boot microservices. Each service uses ~200–500 MB RAM. 2 nodes × 4 GB = 8 GB total, which is enough for the demo.

### What is IRSA?
IAM Roles for Service Accounts. Instead of putting AWS access keys inside the cluster (dangerous), we give specific Kubernetes service accounts permission to assume specific IAM roles. AWS validates identity via OIDC tokens. The AWS Load Balancer Controller uses this to create ALBs without needing stored credentials.

---

## Layer 3: Container Registry (ECR)

### What it is
Amazon ECR (Elastic Container Registry) — a private Docker image registry hosted in AWS. Like Docker Hub, but private and integrated with IAM.

### What we built
- 8 ECR repositories, one per service
- Naming convention: `petclinic/<service-name>`
- **Scan on push**: Every image is automatically scanned for known CVEs (vulnerabilities)
- **Lifecycle policies**: Keep the 10 most recent tagged images; delete untagged images after 7 days
- **Repository policies**: Allow the EKS nodes to pull images

### Why not Docker Hub?
ECR is in the same AWS account — image pulls are faster (no internet egress) and free within the same region. IAM controls access instead of passwords.

---

## Layer 4: Docker Images

### What it is
Each microservice is packaged as a Docker image — a self-contained bundle with the Java runtime, the compiled application, and all dependencies.

### How the Dockerfile works

```
Stage 1: Builder
  ├── Start from maven:3.9 + Java 17
  ├── Copy pom.xml and all module source code
  ├── Run mvn package (compile + package the JAR)
  └── Extract JAR layers (Spring Boot feature for faster re-builds)

Stage 2: Runtime
  ├── Start from eclipse-temurin:17-jre-alpine (small image, ~180 MB)
  ├── Create a non-root user (security best practice)
  ├── Copy the extracted JAR layers (not the fat JAR)
  └── Run the app as the non-root user
```

### Why two stages?
The build stage needs Maven, source code, and all build tools — easily 1–2 GB. The runtime stage needs only the compiled bytecode and the JRE — about 200–300 MB. Multi-stage builds produce small, clean production images.

### Why layered JAR extraction?
Spring Boot layered JARs split the application into: dependencies (rarely change), Spring Boot loader (rarely changes), and application code (changes every build). Docker caches layers. When you only change application code, Docker reuses the dependency and loader layers — rebuilds are much faster.

### Why non-root user?
Running as root inside a container is dangerous. If the container is compromised, an attacker has root-level access. Running as a non-root user limits the blast radius.

---

## Layer 5: CI/CD Pipeline (GitHub Actions)

### What it is
A set of automated workflows that run every time code is pushed to the repository.

### Three-job pipeline

**Job 1: Test**
- Runs on every push and every pull request
- Compiles all modules and runs unit tests
- If tests fail, the pipeline stops here — nothing gets deployed

**Job 2: Build & Push (matrix strategy)**
- Runs only when code lands on `main` (not PRs)
- Builds 8 Docker images in parallel (one per service)
- Tags each image with: the git SHA (immutable) and `latest`
- Pushes both tags to ECR

**Job 3: Update image tags**
- Runs after all 8 builds succeed
- Uses `yq` to update `image.tag` in each service's Helm values file
- Commits the change with `[skip ci]` to prevent an infinite loop
- ArgoCD detects the git change and deploys the new images

### Why git SHA tags?
Git SHAs are immutable — a specific SHA always refers to the exact same code. If a deployment goes wrong, you can roll back to a previous SHA. `latest` is convenient but dangerous in production because it always points to the newest image.

### Why [skip ci]?
Job 3 commits to the same branch that triggers CI. Without `[skip ci]`, that commit would trigger another CI run, which would build images, update tags, commit again — infinite loop.

---

## Layer 6: Kubernetes Deployment

### Structure

All 8 services use a single reusable Helm chart (`petclinic-service`). Each service has its own values file that overrides defaults:

```
kubernetes/helm-charts/petclinic-service/
  ├── Chart.yaml          (chart metadata)
  ├── values.yaml         (defaults — all services inherit these)
  ├── templates/
  │   ├── deployment.yaml (Kubernetes Deployment)
  │   ├── service.yaml    (Kubernetes Service for in-cluster DNS)
  │   ├── ingress.yaml    (ALB Ingress — only for api-gateway)
  │   └── _helpers.tpl    (naming logic)
  └── values/
      ├── api-gateway.yaml
      ├── config-server.yaml
      └── ... (one per service)
```

### Why one chart for all services?
All 8 services are Spring Boot apps. They have the same structure: a Deployment, a Service, probes on `/actuator/health`, metrics on `/actuator/prometheus`. A single parameterized chart avoids duplicating 8 near-identical YAML templates. DRY (Don't Repeat Yourself).

### Service naming
The Helm `fullname` helper returns only `.Release.Name` (the Helm release name), not `release-chart-name`. This is intentional — in-cluster DNS works by service name. The config-server service must be discoverable as `config-server:8888`. If the chart name were appended, it would be `config-server-petclinic-service:8888`, which doesn't match what the Spring app configuration expects.

### Startup ordering (ArgoCD sync waves)
```
Wave 0: monitoring (Prometheus + Grafana) — infrastructure
Wave 1: config-server — all services need config before starting
Wave 2: discovery-server — services register here at startup
Wave 3: all application services — start after config + discovery are ready
```

ArgoCD respects wave annotations: it fully syncs wave N before starting wave N+1.

### Health probes
Every service has:
- **Readiness probe**: `/actuator/health/readiness` — Kubernetes only sends traffic when this returns 200. Protects against traffic hitting a pod before it's fully initialized.
- **Liveness probe**: `/actuator/health/liveness` — if this returns non-200, Kubernetes restarts the pod. Catches hung processes.

---

## Layer 7: GitOps with ArgoCD

### What it is
ArgoCD watches the Git repository. When it detects a change (like updated image tags from CI), it automatically applies that change to the cluster. Git is the single source of truth — the cluster should always match what's in Git.

### Flow
```
CI updates image tag in Git
        │
        ▼
ArgoCD detects the change (polls every 3 minutes, or webhook)
        │
        ▼
ArgoCD applies the change to the cluster
  ├── Creates new pods with the new image
  ├── Waits for them to pass readiness probes
  └── Terminates old pods (rolling update, zero downtime)
        │
        ▼
New version is live
```

### Self-heal
ArgoCD is configured with `selfHeal: true`. If someone manually changes something in the cluster (e.g., `kubectl scale deployment api-gateway --replicas=5`), ArgoCD will revert it to match Git. Git wins.

### Why GitOps instead of kubectl apply?
- Full audit trail: every deployment is a Git commit — who, what, when, why
- Easy rollback: `git revert` rolls back the deployment
- No manual cluster access needed in production
- Self-healing prevents configuration drift

---

## Layer 8: Ingress and Load Balancing

### What it is
The AWS Application Load Balancer (ALB) is the entry point for external traffic. The AWS Load Balancer Controller (running in the cluster) watches for Kubernetes Ingress resources and creates/configures ALBs automatically.

### How it works
```
Internet → ALB (public IP) → api-gateway pod (port 8080)
```

Only the `api-gateway` service has an Ingress resource. All other services are `ClusterIP` — only reachable from inside the cluster. The api-gateway routes requests to the correct backend service.

### IRSA for the ALB Controller
The ALB Controller needs AWS permissions to create/update load balancers. Instead of using access keys, it uses IRSA: the controller's Kubernetes ServiceAccount is annotated with an IAM role ARN. AWS validates the pod's identity via the OIDC provider and grants temporary credentials.

---

## Layer 9: Observability

### Prometheus
Prometheus scrapes metrics from every service every 30 seconds by calling `/actuator/prometheus` (Spring Boot Actuator exposes this endpoint). Metrics are stored in Prometheus's time-series database for 15 days.

A `ServiceMonitor` CRD (Custom Resource Definition) tells Prometheus which services to scrape:
- Target: all services in the `petclinic` namespace
- Port: `http` (named port on the Kubernetes Service)
- Interval: 30 seconds

### Grafana
Grafana reads from Prometheus and visualizes metrics as dashboards. Default dashboards are pre-loaded via the kube-prometheus-stack Helm chart:
- Kubernetes cluster overview (CPU, memory, pod counts)
- JVM metrics (heap usage, GC pauses, thread counts)
- HTTP request rates and latencies per service

### kube-prometheus-stack
We use the community Helm chart that bundles Prometheus + Grafana + AlertManager into a single deployment. ArgoCD deploys it from the official Helm repository using multi-source (the chart comes from the Helm repo; our custom values come from Git).

---

## Key Design Decisions

| Decision | Why |
|----------|-----|
| Modular Terraform | Each module (networking, EKS, ECR, ALB) is independently testable and reusable |
| Single Helm chart | 8 services share the same structure — one chart avoids duplication |
| IRSA over access keys | No stored credentials in the cluster — much safer |
| Sync waves | Config and discovery must be healthy before app services start |
| `[skip ci]` pattern | Prevents CI from looping when it commits tag updates |
| Multi-stage Docker | Small runtime images (no build tools in production) |
| Layered JAR | Faster CI rebuilds — only app code layer changes each build |
| ECR lifecycle policies | Prevent storage cost accumulation from old images |

---

## Cost Summary

| Phase | Resources | Approximate Cost |
|-------|-----------|-----------------|
| Local testing (Phases 1–5) | LocalStack, Kind, Docker | $0 |
| AWS demo (Phases 6–7) | EKS + 2× t3.medium + NAT GW + ALB | ~$15–30 for 2 days |
| After teardown | Nothing running | $0 |

The most expensive component is the NAT Gateway (~$1/day) and the EKS cluster fee ($0.10/hr). Always run `terraform destroy` after the demo.
