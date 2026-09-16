#!/usr/bin/env bash
set -euo pipefail
ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"
if [[ ! -f .env ]]; then
  umask 077
  printf 'POSTGRES_PASSWORD=%s\nSHARED_SECRET=%s\n' "$(openssl rand -hex 24)" "$(openssl rand -hex 32)" > .env
  echo 'Generated local credentials in .env.'
fi
docker compose up --build -d --wait --wait-timeout 180
echo "Open http://localhost:${FRONTEND_PORT:-5173}"
