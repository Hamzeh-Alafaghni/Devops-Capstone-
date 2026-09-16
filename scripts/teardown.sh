#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
echo 'This destroys the cluster, application database and ECR images. Export required data first.'
read -r -p 'Type destroy to continue: ' confirmation
[[ "$confirmation" == destroy ]] || { echo 'Teardown cancelled.'; exit 1; }
terraform -chdir="$ROOT/terraform" init -backend-config=backend.hcl
terraform -chdir="$ROOT/terraform" destroy
