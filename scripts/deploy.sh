#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
terraform -chdir="$ROOT/terraform" init -backend-config=backend.hcl
terraform -chdir="$ROOT/terraform" apply
export ECR_REGISTRY DATABASE_HOST DATABASE_SECRET_ARN
ECR_REGISTRY=$(terraform -chdir="$ROOT/terraform" output -raw ecr_registry)
DATABASE_HOST=$(terraform -chdir="$ROOT/terraform" output -raw database_host)
DATABASE_SECRET_ARN=$(terraform -chdir="$ROOT/terraform" output -raw database_secret_arn)
# Requires kubeconfig access through an SSM tunnel, or run on the control plane.
bash "$ROOT/scripts/deploy-k8s.sh"
