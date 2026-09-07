#!/bin/bash
set -euo pipefail

echo "=== Kubernetes Pod Status ==="
kubectl get pods

echo -e "\n=== Testing /health endpoints via Port-Forward ==="
services=("auth-service" "catalog-service" "orders-service")

for svc in "${services[@]}"; do
    echo "Testing $svc..."
    kubectl port-forward svc/$svc 8080:80 &>/dev/null &
    PF_PID=$!
    
    sleep 3 
    
    if curl -s http://localhost:8080/health | grep -q "status"; then
        echo "✅ $svc is healthy!"
    else
        echo "❌ $svc health check failed or returned unexpected response."
    fi
    
    kill $PF_PID
done
