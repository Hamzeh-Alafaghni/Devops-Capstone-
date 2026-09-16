#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
: "${ECR_REGISTRY:?Set ECR_REGISTRY}"
: "${IMAGE_TAG:?Set IMAGE_TAG to the tested commit SHA}"
export PROJECT=${PROJECT:-marketly}
[[ "$IMAGE_TAG" =~ ^[a-f0-9]{40}$ ]] || { echo 'IMAGE_TAG must be a full commit SHA' >&2; exit 1; }
kubectl apply -f "$ROOT/k8s/namespace.yaml"
python3 "$ROOT/scripts/sync-secrets.py"
bash "$ROOT/scripts/refresh-ecr.sh"
kubectl apply -f "$ROOT/k8s/traefik.yaml"
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT
cp -R "$ROOT/k8s" "$TEMP_DIR/k8s"
python3 - "$TEMP_DIR/k8s" <<'PY'
import os,sys
from pathlib import Path
for path in Path(sys.argv[1]).glob('*/deployment.yaml'):
    service=path.parent.name
    path.write_text(path.read_text().replace(f'marketly/{service}:replace-me',
        f'{os.environ["ECR_REGISTRY"]}/{os.environ["PROJECT"]}/{service}:{os.environ["IMAGE_TAG"]}'))
PY
kubectl apply -k "$TEMP_DIR/k8s"
# A managed RDS password rotation may require restarting unchanged images too.
kubectl -n marketly rollout restart deployment/auth-service deployment/catalog-service deployment/orders-service
for service in auth-service catalog-service orders-service frontend; do
  kubectl -n marketly rollout status "deployment/$service" --timeout=300s
done
bash "$ROOT/scripts/healthcheck.sh"
