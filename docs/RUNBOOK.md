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
kubectl port-forward -n monitoring svc/kube-prometheus-stack-grafana 3000:80
# Visit http://localhost:3000
# Default credentials: admin / petclinic-admin

# Open Prometheus
kubectl port-forward -n monitoring svc/kube-prometheus-stack-prometheus 9090:9090
# Visit http://localhost:9090
# Check Status > Targets to see which services are being scraped
```

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

## Troubleshooting

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
