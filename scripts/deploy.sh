#!/bin/bash
set -euo pipefail

echo "Applying Terraform infrastructure..."
cd terraform
terraform init
terraform apply -auto-approve
cd ..

echo "Applying Kubernetes manifests..."
kubectl apply -f k8s/namespace.yaml
kubectl apply -f k8s/

echo "Deployment triggered! Check status with: kubectl get pods"
