#!/bin/bash
# Destroys all AWS resources created for Spring PetClinic
# Run from the repository root
# Order matters: delete K8s resources first so ArgoCD doesn't fight Terraform

set -euo pipefail

echo "WARNING: This will destroy ALL AWS infrastructure for Spring PetClinic."
echo "         This action cannot be undone and will delete:"
echo "         - EKS cluster and all running pods"
echo "         - VPC, subnets, security groups"
echo "         - All ECR repositories and images"
echo "         - ALB IAM role"
echo ""
read -p "Type 'destroy' to confirm: " confirm
if [ "$confirm" != "destroy" ]; then
  echo "Aborted."
  exit 0
fi

AWS_REGION="us-east-1"
CLUSTER_NAME="petclinic-prod"

# ---------------------------------------------------------------------------
# Step 1: Configure kubectl (in case it isn't already)
# ---------------------------------------------------------------------------
echo ""
echo "==> Configuring kubectl..."
aws eks update-kubeconfig --region ${AWS_REGION} --name ${CLUSTER_NAME} 2>/dev/null || true

# ---------------------------------------------------------------------------
# Step 2: Delete ArgoCD Applications first
# This tells ArgoCD to stop managing resources before we delete them.
# Without this, ArgoCD may recreate resources that Terraform is trying to delete.
# ---------------------------------------------------------------------------
echo ""
echo "==> Deleting ArgoCD applications..."
kubectl delete -f kubernetes/argocd/applications/ --ignore-not-found=true
echo "    Waiting 30s for ArgoCD to clean up managed resources..."
sleep 30

# ---------------------------------------------------------------------------
# Step 3: Delete application namespaces
# Removes all remaining pods, services, and persistent resources
# ---------------------------------------------------------------------------
echo ""
echo "==> Deleting application namespaces..."
kubectl delete namespace petclinic --ignore-not-found=true
kubectl delete namespace monitoring --ignore-not-found=true
kubectl delete namespace argocd --ignore-not-found=true
echo "    Namespaces deleted."

# ---------------------------------------------------------------------------
# Step 4: Terraform destroy
# Tears down all AWS infrastructure in reverse dependency order
# ---------------------------------------------------------------------------
echo ""
echo "==> Running terraform destroy..."
cd terraform
terraform destroy -auto-approve
cd ..

echo ""
echo "==> Teardown complete. All AWS resources have been destroyed."
echo "    Run 'aws eks list-clusters' to confirm the cluster is gone."
