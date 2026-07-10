#!/bin/bash
# Full deployment script for Spring PetClinic on AWS EKS
# Run from the repository root after configuring AWS credentials (aws configure)
# Prerequisites: terraform, kubectl, helm, aws CLI installed

set -euo pipefail

AWS_REGION="us-east-1"
CLUSTER_NAME="petclinic-prod"

echo "==> Checking AWS credentials..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo "    Account ID: ${AWS_ACCOUNT_ID}"
echo "    Region:     ${AWS_REGION}"

# ---------------------------------------------------------------------------
# Step 1: Replace YOUR_ACCOUNT_ID placeholder in Helm values files
# This is a one-time setup step. Once done, CI keeps image tags updated.
# ---------------------------------------------------------------------------
echo ""
echo "==> Setting ECR account ID in Helm values files..."
find kubernetes/helm-charts/petclinic-service/values/ -name "*.yaml" | while read file; do
  sed -i "s/YOUR_ACCOUNT_ID/${AWS_ACCOUNT_ID}/g" "$file"
done
echo "    Done. Committing values files..."
git add kubernetes/helm-charts/petclinic-service/values/
git diff --cached --quiet || git commit -m "chore: set ecr registry account id for deployment [skip ci]"
git push

# ---------------------------------------------------------------------------
# Step 2: Provision AWS infrastructure with Terraform
# Creates VPC, EKS cluster, ECR repos, ALB IAM role
# ---------------------------------------------------------------------------
echo ""
echo "==> Running terraform apply..."
cd terraform
terraform init -input=false
terraform apply -auto-approve
cd ..
echo "    Infrastructure provisioned."

# ---------------------------------------------------------------------------
# Step 3: Configure kubectl to talk to the new EKS cluster
# ---------------------------------------------------------------------------
echo ""
echo "==> Configuring kubectl..."
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME}
echo "    kubectl configured."

# ---------------------------------------------------------------------------
# Step 4: Install ArgoCD on the cluster
# ArgoCD manages all deployments from this point forward
# ---------------------------------------------------------------------------
echo ""
echo "==> Installing ArgoCD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
echo "    Waiting for ArgoCD to be ready..."
kubectl wait --for=condition=available --timeout=300s deployment/argocd-server -n argocd
echo "    ArgoCD ready."

# ---------------------------------------------------------------------------
# Step 5: Apply ArgoCD project and all application manifests
# ArgoCD will now sync all services from Git to the cluster
# ---------------------------------------------------------------------------
echo ""
echo "==> Applying ArgoCD project and applications..."
kubectl apply -f kubernetes/argocd/projects/petclinic.yaml
kubectl apply -f kubernetes/argocd/applications/
echo "    ArgoCD applications created. Sync will begin automatically."

# ---------------------------------------------------------------------------
# Step 6: Trigger the CI pipeline to build and push the first images
# This can also be done manually: push any change to main
# ---------------------------------------------------------------------------
echo ""
echo "==> Triggering first image build..."
git commit --allow-empty -m "chore: trigger initial image build for phase 7 deployment"
git push
echo "    CI pipeline triggered. Monitor at: https://github.com/Crystal-Angie/spring-petclinic-ai-devops/actions"

# ---------------------------------------------------------------------------
# Step 7: Print access details
# ---------------------------------------------------------------------------
echo ""
echo "==> ArgoCD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d
echo ""
echo ""
echo "==> Access ArgoCD UI (run in a separate terminal):"
echo "    kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "    Then open: https://localhost:8080  (username: admin)"
echo ""
echo "==> Wait for all services to be healthy, then get the app URL:"
echo "    kubectl get ingress -n petclinic"
echo ""
echo "==> Deployment complete. Monitor ArgoCD for sync status."
