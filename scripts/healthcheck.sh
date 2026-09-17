#!/usr/bin/env bash
set -euo pipefail
kubectl -n marketly get pods
PF_PID=''
cleanup() { if [[ -n "$PF_PID" ]]; then kill "$PF_PID" 2>/dev/null || true; wait "$PF_PID" 2>/dev/null || true; fi; }
trap cleanup EXIT
for item in auth-service:5001 catalog-service:5002 orders-service:5003 frontend:80; do
  service=${item%:*}
  port=${item#*:}
  kubectl -n marketly rollout status "deployment/$service" --timeout=120s
  kubectl -n marketly port-forward "service/$service" "18080:$port" >/dev/null 2>&1 &
  PF_PID=$!
  healthy=false
  for attempt in {1..20}; do
    if curl --fail --silent --max-time 2 http://127.0.0.1:18080/health >/dev/null; then healthy=true; break; fi
    kill -0 "$PF_PID" 2>/dev/null || break
    sleep 1
  done
  cleanup
  PF_PID=''
  [[ "$healthy" == true ]] || { echo "$service health check failed" >&2; exit 1; }
  echo "$service healthy"
done
