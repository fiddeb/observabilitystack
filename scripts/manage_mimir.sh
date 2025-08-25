#!/bin/bash

# Mimir Migration Helper Script
# This script helps enable/disable Mimir in the observability stack

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
    echo "Usage: $0 [enable|disable|status]"
    echo "  enable  - Enable Mimir and disable Prometheus"
    echo "  disable - Disable Mimir and enable Prometheus"
    echo "  status  - Show current Mimir/Prometheus status"
    exit 1
}

check_buckets() {
    echo "Checking required S3 buckets for Mimir..."
    
    # Get Minio pod name
    MINIO_POD=$(kubectl get pods -n observability-lab | grep minio | grep -v console | awk '{print $1}' | head -1)
    
    if [ -z "$MINIO_POD" ]; then
        echo "Warning: Could not find Minio pod. S3 buckets may not be available."
        return 1
    fi
    
    # Check buckets
    if kubectl -n observability-lab exec "$MINIO_POD" -- mc ls local/ | grep -q "mimir-blocks"; then
        echo "✓ mimir-blocks bucket exists"
    else
        echo "Creating mimir-blocks bucket..."
        kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-blocks --ignore-existing
    fi
    
    if kubectl -n observability-lab exec "$MINIO_POD" -- mc ls local/ | grep -q "mimir-ruler"; then
        echo "✓ mimir-ruler bucket exists"
    else
        echo "Creating mimir-ruler bucket..."
        kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-ruler --ignore-existing
    fi
    
    if kubectl -n observability-lab exec "$MINIO_POD" -- mc ls local/ | grep -q "mimir-alertmanager"; then
        echo "✓ mimir-alertmanager bucket exists"
    else
        echo "Creating mimir-alertmanager bucket..."
        kubectl -n observability-lab exec "$MINIO_POD" -- mc mb local/mimir-alertmanager --ignore-existing
    fi
    
    echo "✓ All Mimir S3 buckets ready"
}

enable_mimir() {
    echo "=== Enabling Mimir and disabling Prometheus ==="
    
    # Check S3 buckets first
    check_buckets
    
    # Update values to enable Mimir and disable Prometheus
    cd "${REPO_ROOT}/helm/stackcharts"
    
    # Create temporary values override
    cat > /tmp/mimir-override.yaml << EOF
mimir-distributed:
  enabled: true

prometheus:
  enabled: false
EOF
    
    echo "Upgrading observability stack with Mimir enabled..."
    helm upgrade observability-stack . \
        --namespace observability-lab \
        --values /tmp/mimir-override.yaml \
        --wait
    
    rm /tmp/mimir-override.yaml
    
    echo "✓ Mimir enabled successfully!"
    echo ""
    echo "Mimir endpoints:"
    echo "  Write: http://mimir-nginx.observability-lab.svc:80/api/v1/push"
    echo "  Read:  http://mimir-nginx.observability-lab.svc:80/prometheus"
}

disable_mimir() {
    echo "=== Disabling Mimir and enabling Prometheus ==="
    
    cd "${REPO_ROOT}/helm/stackcharts"
    
    # Create temporary values override
    cat > /tmp/prometheus-override.yaml << EOF
mimir-distributed:
  enabled: false

prometheus:
  enabled: true
EOF
    
    echo "Upgrading observability stack with Prometheus enabled..."
    helm upgrade observability-stack . \
        --namespace observability-lab \
        --values /tmp/prometheus-override.yaml \
        --wait
    
    rm /tmp/prometheus-override.yaml
    
    echo "✓ Prometheus enabled, Mimir disabled!"
}

show_status() {
    echo "=== Current Status ==="
    
    if kubectl get pods -n observability-lab | grep -q "mimir-monolithic"; then
        echo "✓ Mimir: ENABLED"
        kubectl get pods -n observability-lab | grep mimir || true
    else
        echo "✗ Mimir: DISABLED"
    fi
    
    if kubectl get pods -n observability-lab | grep -q "prometheus"; then
        echo "✓ Prometheus: ENABLED"
        kubectl get pods -n observability-lab | grep prometheus || true
    else
        echo "✗ Prometheus: DISABLED"
    fi
}

case "${1:-}" in
    enable)
        enable_mimir
        ;;
    disable)
        disable_mimir
        ;;
    status)
        show_status
        ;;
    *)
        usage
        ;;
esac
