#!/bin/bash
set -euo pipefail

echo "⚠️  WARNING: This will destroy all AWS infrastructure provisioned by Terraform."
read -p "Are you sure you want to proceed? (y/N) " confirm

if [[ "$confirm" =~ ^[Yy]$ ]]; then
    echo "Destroying infrastructure..."
    cd terraform
    terraform destroy
else
    echo "Teardown aborted. Your infrastructure is still running."
fi
