#!/usr/bin/env bash
set -euo pipefail
: "${AWS_REGION:?Set AWS_REGION}"
: "${ECR_REGISTRY:?Set ECR_REGISTRY}"
# Pipe credentials over stdin, not process arguments or terminal output.
aws ecr get-login-password --region "$AWS_REGION" |
  ECR_REGISTRY="$ECR_REGISTRY" python3 -c '
import base64,json,os,sys
password=sys.stdin.read().strip()
if not password: raise SystemExit("Empty ECR password")
config={"auths":{os.environ["ECR_REGISTRY"]:{"auth":base64.b64encode(("AWS:"+password).encode()).decode()}}}
print(json.dumps({"apiVersion":"v1","kind":"Secret","metadata":{"name":"ecr-pull","namespace":"marketly"},"type":"kubernetes.io/dockerconfigjson","data":{".dockerconfigjson":base64.b64encode(json.dumps(config).encode()).decode()}}))
' | kubectl apply --server-side --field-manager=marketly-ecr -f - >/dev/null
