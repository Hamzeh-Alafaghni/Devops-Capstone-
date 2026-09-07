#!/bin/bash
set -euo pipefail

echo "Checking required CLI tools..."

for tool in aws kubectl terraform docker git; do
    if ! command -v $tool &> /dev/null; then
        echo "❌ Error: $tool is not installed or not in PATH."
        exit 1
    else
        echo "✅ $tool is installed."
    fi
done

echo "All required tools are ready to go!"
