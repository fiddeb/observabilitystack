#!/bin/bash

# Mimir Migration Setup Script
# This script sets up the NGDATA Mimir fork for monolithic mode

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

echo "=== Mimir Migration Setup ==="
echo "Setting up NGDATA Mimir fork for monolithic mode..."

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check required tools
echo "Checking required tools..."
if ! command_exists helm; then
    echo "Error: helm is required but not installed"
    exit 1
fi

if ! command_exists kubectl; then
    echo "Error: kubectl is required but not installed"
    exit 1
fi

# Use local NGDATA Mimir chart
echo "Using local NGDATA Mimir chart with monolithic support..."

# Check if NGDATA chart exists locally
if [ ! -d "${REPO_ROOT}/helm/ngdata-mimir-chart" ]; then
    echo "Error: NGDATA Mimir chart not found at ${REPO_ROOT}/helm/ngdata-mimir-chart"
    echo "Please ensure the NGDATA chart has been copied to the helm directory"
    exit 1
fi

echo "✓ NGDATA Mimir chart found locally"

# Create Minio buckets for Mimir
echo "Creating required S3 buckets for Mimir..."

# Get Minio pod name
MINIO_POD=$(kubectl get pods -n observability-lab | grep minio | grep -v console | awk '{print $1}' | head -1)

if [ -z "$MINIO_POD" ]; then
    echo "Error: Could not find Minio pod"
    exit 1
fi

echo "Using Minio pod: $MINIO_POD"

# Create buckets
echo "Creating mimir-blocks bucket..."
kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-blocks --ignore-existing

echo "Creating mimir-ruler bucket..."
kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-ruler --ignore-existing

echo "Creating mimir-alertmanager bucket..."
kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-alertmanager --ignore-existing

# Verify buckets were created
echo "Verifying buckets..."
kubectl -n observability-lab exec "$MINIO_POD" -- mc ls local/ | grep mimir

echo "✓ Mimir S3 buckets created successfully"

# Show next steps
echo ""
echo "=== Next Steps ==="
echo "1. Review the Mimir monolithic configuration in helm/mimir/ngdata_monolithic_values.yaml"
echo "2. Test Mimir deployment with: helm install mimir-test ./helm/ngdata-mimir-chart -f helm/mimir/ngdata_monolithic_values.yaml -n observability-lab --dry-run"
echo "3. Deploy Mimir when ready: helm install mimir ./helm/ngdata-mimir-chart -f helm/mimir/ngdata_monolithic_values.yaml -n observability-lab"
echo "4. Update ArgoCD application to include Mimir"
echo "5. Configure Grafana to use Mimir as data source"
echo "6. Stop Prometheus after verifying Mimir works"

echo ""
echo "=== Migration Status ==="
echo "✓ NGDATA chart available locally"
echo "✓ Mimir S3 buckets created"
echo "⚠ Mimir not yet deployed (manual step required)"
echo "⚠ Prometheus still active"

echo ""
echo "Migration setup completed successfully!"
