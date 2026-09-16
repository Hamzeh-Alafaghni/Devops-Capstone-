#!/usr/bin/env bash
set -euo pipefail
missing=0
for tool in aws kubectl terraform docker git python3 curl openssl; do
  if command -v "$tool" >/dev/null 2>&1; then
    echo "$tool: available"
  else
    echo "$tool: missing" >&2
    missing=1
  fi
done
[[ "$missing" == 0 ]] || exit 1
docker compose version
docker info --format 'Docker server: {{.ServerVersion}}'
terraform version
