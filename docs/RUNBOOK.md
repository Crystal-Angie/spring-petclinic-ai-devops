# Runbook — Spring PetClinic AI DevOps

Operational procedures for deploying, monitoring, and tearing down the Spring PetClinic environment on AWS EKS.

---

## Prerequisites

Before running any of these procedures, make sure you have:

```bash
# Required tools
terraform --version    # >= 1.5
docker --version       # >= 24
kubectl version        # >= 1.28
helm version           # >= 3.12
aws --version          # >= 2.0
git --version
yq --version           # >= 4.0 (YAML processor)
```

AWS credentials must be configured:
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (us-east-1), output format (json)

# Verify it works
aws sts get-caller-identity
```

---

## Deploy: Full Environment

This procedure brings up everything from scratch — Terraform, EKS, ArgoCD, all services, and monitoring.

```bash
# From the repository root
./scripts/deploy.sh
```

The script runs these steps automatically:
1. Gets your AWS account ID
2. Replaces `YOUR_ACCOUNT_ID` in all Helm values files with your real account ID
3. Runs `terraform apply` to create VPC, EKS cluster, ECR repos, ALB IAM role
4. Configures kubectl to connect to the new cluster
5. Installs ArgoCD in the cluster
6. Applies ArgoCD project + all application manifests
7. Triggers the first CI build (so images get pushed and deployed)

Expected duration: ~20–30 minutes total (Terraform ~15 min, ArgoCD sync ~10 min).

### After deploy.sh completes

Check that ArgoCD is syncing:
```bash
# Get the ArgoCD admin password (deploy.sh also prints this)
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d

# Open the ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Visit https://localhost:8080  (username: admin)
```

Check pods are running:
```bash
kubectl get pods -n petclinic
kubectl get pods -n monitoring
```

Get the application URL:
```bash
kubectl get ingress -n petclinic
# The ADDRESS column shows the ALB DNS name
# Visit http://<alb-dns-name>
```

---

## Teardown: Destroy All AWS Resources

**Always teardown after you're done to avoid costs.**

```bash
# From the repository root
./scripts/teardown.sh
```

You will be prompted to type `destroy` to confirm. The script:
1. Deletes all ArgoCD applications (stops ArgoCD from recreating resources)
2. Waits 30 seconds for ArgoCD to process the deletion
3. Deletes namespaces: `petclinic`, `monitoring`, `argocd`
4. Runs `terraform destroy -auto-approve`

Expected duration: ~10–15 minutes.

After teardown, verify everything is gone:
```bash
aws eks list-clusters --region us-east-1        # Should return empty list
aws ecr describe-repositories --region us-east-1 # Should show no repos
aws ec2 describe-vpcs --region us-east-1         # No petclinic VPC
```

---

## Check Application Health

```bash
# All pods should be Running or Completed
kubectl get pods -n petclinic

# Check logs for a specific service
kubectl logs -n petclinic deployment/api-gateway -f

# Check if services are responding
kubectl exec -n petclinic deployment/api-gateway -- \
  wget -qO- http://localhost:8080/actuator/health

# Check the Kubernetes events (useful for debugging crashes)
kubectl get events -n petclinic --sort-by='.lastTimestamp'
```

---

## Check Monitoring

```bash
# Open Grafana dashboard
kubectl port-forward -n monitoring svc/monitoring-grafana 3000:80
# Visit http://localhost:3000
# Default credentials: admin / petclinic-admin

# Open Prometheus
kubectl port-forward -n monitoring svc/monitoring-kube-prometheus-prometheus 9090:9090
# Visit http://localhost:9090
# Check Status > Targets to see which services are being scraped
```

Useful dashboards in Grafana:
- **Kubernetes / Compute Resources / Namespace (Pods)** → set namespace to `petclinic` to see all services
- **Import dashboard ID `4701`** (JVM Micrometer) → shows HTTP request rates, JVM heap, GC time per service

---

## CI/CD Pipeline

### Trigger a deployment
Push any change to `main`. The pipeline runs automatically:
1. Tests → 2. Build & push 8 images → 3. Update image tags in Git → 4. ArgoCD deploys

Monitor at: `https://github.com/Crystal-Angie/spring-petclinic-ai-devops/actions`

### Check what version is deployed
```bash
# Image tags currently running
kubectl get pods -n petclinic -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.containers[0].image}{"\n"}{end}'

# ArgoCD sync status
kubectl get applications -n argocd
```

### Force ArgoCD to sync immediately
```bash
# Instead of waiting for the 3-minute poll cycle
kubectl patch application api-gateway -n argocd \
  --type merge -p '{"operation":{"sync":{}}}'

# Or sync all applications
for app in config-server discovery-server api-gateway customers-service \
           vets-service visits-service admin-server genai-service monitoring; do
  kubectl patch application $app -n argocd --type merge -p '{"operation":{"sync":{}}}'
done
```

---

## Rollback a Service

To roll back a service to a previous version:

```bash
# Find recent image tags in ECR
aws ecr describe-images \
  --repository-name petclinic/api-gateway \
  --region us-east-1 \
  --query 'sort_by(imageDetails, &imagePushedAt)[-5:].imageTags' \
  --output table

# Edit the values file with the old SHA
# kubernetes/helm-charts/petclinic-service/values/api-gateway.yaml
# Change image.tag to the old SHA

git add kubernetes/helm-charts/petclinic-service/values/api-gateway.yaml
git commit -m "fix: rollback api-gateway to <old-sha>"
git push
# ArgoCD detects the change and deploys the old image
```

---

## First-Deploy Issues & Fixes (July 2026)

This section documents every real error hit during the first production deployment and exactly how each was fixed. Useful as a reference and as a demonstration that the project was debugged end-to-end on real AWS.

---

### 1. CloudWatch Log Group Already Exists

**What happened:**
`terraform apply` created the EKS cluster, then tried to create the CloudWatch log group — but AWS had already auto-created it the moment the cluster came up with logging enabled. Terraform threw `ResourceAlreadyExistsException` and exited.

**Why it happens:**
EKS creates `/aws/eks/<cluster>/cluster` automatically when you enable cluster logging. Terraform had no dependency ordering between the two resources, so they raced.

**Fix:**
Added `aws_cloudwatch_log_group` to the `depends_on` of `aws_eks_cluster` in `terraform/modules/eks/main.tf`. Terraform now creates the log group first — EKS finds it already exists and skips creating it.

**If you hit it on a re-deploy before the fix was in place:**
```bash
# Import the existing log group into Terraform state so it stops trying to create it
MSYS_NO_PATHCONV=1 terraform import \
  module.eks.aws_cloudwatch_log_group.eks_cluster \
  /aws/eks/petclinic-prod/cluster
terraform apply -auto-approve
```
> **Note:** `MSYS_NO_PATHCONV=1` is required on Windows Git Bash — without it, Bash converts the leading `/` to `C:/Program Files/Git/...`.

---

### 2. Deploy Script Stopped Waiting for ArgoCD

**What happened:**
The deploy script always failed halfway at the "waiting for ArgoCD" step. The original command was:
```bash
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
```
This exited immediately with an error because:
- Right after `kubectl apply`, the ArgoCD Deployment object doesn't exist yet (takes 5–30 seconds)
- `kubectl wait` on a non-existent resource exits with code 1 instantly — it doesn't wait for the resource to appear
- Even if it did wait, 300 seconds (5 minutes) is not enough — a fresh EKS cluster pulling ~10 ArgoCD images typically takes 8–15 minutes

**Fix:**
Replaced with a two-phase approach in `scripts/deploy.sh`:
1. **Existence poll** — loops every 5 seconds (up to 90s) waiting for the Deployment object to appear in Kubernetes
2. **Readiness wait** — uses `kubectl rollout status` with a 900s (15 min) timeout, which is far more reliable than `kubectl wait`
Also added a wait for `argocd-application-controller` (the StatefulSet that actually deploys apps), which the original script never waited for at all.

---

### 3. Application Source Code Was Not in Git

**What happened:**
The CI pipeline failed immediately with:
```
Error: No file matched to [**/pom.xml]
```
The `app/` directory (all 8 microservices) and `pom.xml` were on the local machine but had never been committed to the repository. The GitHub Actions runner checked out the repo and found nothing to build or test.

**Why:** The files were untracked — present locally but never `git add`'d.

**Fix:** Committed `pom.xml`, `app/`, `.mvn/`, `mvnw`, `mvnw.cmd`, and `docker-compose.yml`. CI now passes.

---

### 4. AWS Load Balancer Controller Was Not Installed

**What happened:**
After deployment, the `api-gateway` Ingress was created but had no `ADDRESS`. The ALB was never provisioned. Running `kubectl get ingressclass` returned nothing.

**Why:** The deploy script never installed the AWS Load Balancer Controller. Terraform created the IAM role for it (Phase 5), but nobody installed the controller itself into the cluster.

**Fix:** Added an ALB controller install step to `scripts/deploy.sh` using Helm:
```bash
helm upgrade --install aws-load-balancer-controller eks/aws-load-balancer-controller \
  -n kube-system \
  --set clusterName=${CLUSTER_NAME} \
  --set vpcId=${VPC_ID} \
  --set region=${AWS_REGION} \
  --set serviceAccount.annotations."eks\.amazonaws\.com/role-arn"=...
```
The VPC ID must be passed explicitly — the controller cannot auto-discover it from EC2 metadata in all environments.

---

### 5. ALB IAM Policy Was Incomplete

**What happened:**
Even after the controller was installed, the ALB kept failing to provision:
```
AccessDenied: not authorized to perform elasticloadbalancing:AddTags on listener/...
AccessDenied: not authorized to perform elasticloadbalancing:DescribeListenerAttributes
```
The controller created the ALB and target group successfully, then hit a wall trying to configure the listener.

**Why:** The hand-rolled IAM policy in `terraform/modules/alb/main.tf` covered load balancers and target groups in the `AddTags` resource list, but not listeners or listener rules. `DescribeListenerAttributes` was missing entirely.

**Fix:** Replaced the hand-rolled policy with the [official AWS LBC IAM policy JSON](https://raw.githubusercontent.com/kubernetes-sigs/aws-load-balancer-controller/v2.11.0/docs/install/iam_policy.json) stored at `terraform/modules/alb/iam_policy.json`. The Terraform resource now uses `policy = file("${path.module}/iam_policy.json")`. Applied immediately with `terraform apply -target=module.alb.aws_iam_policy.alb_controller`.

**Lesson:** Never hand-roll IAM policies for AWS managed controllers — use the official policy the project publishes.

---

### 6. ArgoCD Project Whitelist Blocked Ingress and Monitoring

**What happened:**
`api-gateway` stayed `OutOfSync` with:
```
resource networking.k8s.io:Ingress is not permitted in project petclinic
```
The `monitoring` application had dozens of failures:
```
resource rbac.authorization.k8s.io:ClusterRole is not permitted
resource apiextensions.k8s.io:CustomResourceDefinition is not permitted
namespace kube-system is not permitted
```

**Why:** The ArgoCD project (`kubernetes/argocd/projects/petclinic.yaml`) had a narrow explicit whitelist that didn't include Ingress, ClusterRoles, CRDs, DaemonSets, Secrets, Webhooks, Jobs, or the `kube-system` namespace — all of which the kube-prometheus-stack needs.

**Fix:** Opened the whitelist to `*` for both `namespaceResourceWhitelist` and `clusterResourceWhitelist`, and added `kube-system` as an allowed destination. The security boundary for this project is the `sourceRepos` and `destinations` fields — restricting resource types was unnecessary overhead.

---

### 7. Services Starting on a Random Port

**What happened:**
Four services (`customers-service`, `vets-service`, `visits-service`, `genai-service`) were stuck in `CrashLoopBackOff`. The logs showed:
```
Tomcat initialized with port 0 (http)
Tomcat started on port 41875 (http)
```
The pod started fine, but Kubernetes probes were checking port 8081 — the app was on a random port, so every probe failed and Kubernetes killed the pod repeatedly.

**Why:** The upstream Spring PetClinic config server (at `https://github.com/spring-petclinic/spring-petclinic-microservices-config`) serves `server.port=0` for these services, meaning "let the OS pick any free port." That's fine for local Docker Compose but breaks Kubernetes probes which expect a fixed port.

**Fix:** Added `SERVER_PORT=<port>` to each service's Helm values file. Environment variables override config server values in Spring Boot.

---

### 8. Services Connecting to Eureka on localhost

**What happened:**
Even after fixing the port, services started but couldn't register with the Eureka service registry:
```
Connect to http://localhost:8761 failed: Connection refused
```
In Kubernetes there is no `localhost:8761` — the Eureka server runs as a separate pod accessible via `http://discovery-server:8761`.

**First fix attempt (wrong):**
Added env var `EUREKA_CLIENT_SERVICEURL_DEFAULTZONE=http://discovery-server:8761/eureka/`. This had no effect — Spring Boot's relaxed binding rules for nested map properties did not map this env var name to the actual property `eureka.client.serviceUrl.defaultZone`.

**Final fix:**
Used `SPRING_APPLICATION_JSON` instead, which Spring Boot parses directly as a JSON property source with the highest priority, bypassing the config server entirely:
```yaml
- name: SPRING_APPLICATION_JSON
  value: '{"eureka":{"client":{"serviceUrl":{"defaultZone":"http://discovery-server:8761/eureka/"}}}}'
```
Applied to all 5 services that act as Eureka clients: `customers-service`, `vets-service`, `visits-service`, `genai-service`, and `api-gateway`.

**Why api-gateway mattered:** The frontend works without Eureka (it just serves HTML/JS), but form submissions route through Spring Cloud Gateway which uses `lb://customers-service` — a load-balanced URL that resolves via Eureka. Without Eureka, every form submit silently failed.

---

### 9. Prometheus Not Scraping Microservices

**What happened:**
Prometheus was running and scraping Kubernetes system components, but none of the petclinic services appeared in `Status → Targets`. The actuator endpoints (`/actuator/prometheus`) were confirmed working.

**Why:** Prometheus Operator discovers scrape targets via `ServiceMonitor` custom resources — one per service. None had been created for the petclinic services.

**Fix:** Added `templates/servicemonitor.yaml` to the shared Helm chart (`kubernetes/helm-charts/petclinic-service/`). It is enabled by default in `values.yaml`, so all 8 services automatically get a ServiceMonitor when deployed. The selector matches the existing Service labels so no changes were needed elsewhere. Verified with `helm template` before committing.

---

### Pod is stuck in CrashLoopBackOff

```bash
# Check the logs
kubectl logs -n petclinic <pod-name> --previous

# Common causes:
# 1. Can't reach config-server (check config-server is healthy first)
# 2. Can't reach discovery-server
# 3. Out of memory (check resource limits in values file)
```

### Pod is stuck in Pending

```bash
kubectl describe pod -n petclinic <pod-name>
# Look at the Events section at the bottom

# Common causes:
# - Insufficient node resources → scale up the node group
# - Image pull failed → check ECR repo name and IAM permissions
```

### ArgoCD shows OutOfSync

```bash
# Check what ArgoCD wants to change
kubectl describe application <app-name> -n argocd

# Common causes:
# - CI pushed a new image tag — this is expected, just wait for sync
# - Manual kubectl change that ArgoCD is reverting (self-heal)
# - Terraform changed something that ArgoCD manages (check for conflicts)
```

### Prometheus shows a target as DOWN

```bash
# Check if the service has the actuator endpoint exposed
kubectl exec -n petclinic deployment/<service> -- \
  wget -qO- http://localhost:<port>/actuator/prometheus | head -20

# Check if the ServiceMonitor is correct
kubectl get servicemonitor -n petclinic -o yaml

# Check Prometheus logs
kubectl logs -n monitoring -l app.kubernetes.io/name=prometheus -f
```

### ECR image pull fails

```bash
# Verify the node group IAM role has ECR read permissions
aws iam list-attached-role-policies \
  --role-name petclinic-node-group-role

# Should include: AmazonEC2ContainerRegistryReadOnly
# If missing, it means the Terraform apply was incomplete — re-run terraform apply
```

### `terraform apply` fails mid-way

```bash
# Terraform state tracks what was already created
# Re-running apply is safe — Terraform skips already-created resources
cd terraform/
terraform plan    # See what's left to create
terraform apply   # Resume from where it stopped
```

---

## Cost Control

### Check current AWS costs
```bash
aws ce get-cost-and-usage \
  --time-period Start=$(date -d "7 days ago" +%Y-%m-%d),End=$(date +%Y-%m-%d) \
  --granularity DAILY \
  --metrics BlendedCost \
  --query 'ResultsByTime[*].[TimePeriod.Start,Total.BlendedCost.Amount]' \
  --output table
```

### Most expensive components (in order)
1. **NAT Gateway**: ~$1.08/day + $0.045/GB data processed
2. **EKS cluster fee**: $0.10/hour = ~$2.40/day
3. **EC2 nodes** (2× t3.medium): ~$0.0416/hr each = ~$2.00/day
4. **ALB**: ~$0.008/hr + data processed

**Total for 2-day demo: ~$15–30 depending on traffic.**

Always run `teardown.sh` when done. ECR storage is negligible (<$0.10/month for a few images).

---

## GitHub Secrets Required

Set these in GitHub → Settings → Secrets and variables → Actions:

| Secret | Value |
|--------|-------|
| `AWS_ACCESS_KEY_ID` | IAM user access key with ECR push + EKS read permissions |
| `AWS_SECRET_ACCESS_KEY` | Corresponding secret key |

The `GITHUB_TOKEN` secret is automatically provided by GitHub Actions — no setup needed.
