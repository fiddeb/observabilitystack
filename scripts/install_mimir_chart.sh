#!/bin/bash
# Install NGDATA Mimir chart with monolithic support
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "🔧 Installing NGDATA Mimir Chart"

TEMP_DIR=$(mktemp -d)
CHARTS_DIR="${PROJECT_ROOT}/helm/stackcharts/charts"
MIMIR_CHART_DIR="${CHARTS_DIR}/mimir-distributed"

cleanup() {
    print_step "Cleaning up temporary directory..."
    rm -rf "${TEMP_DIR}"
}
trap cleanup EXIT

print_step "Cloning NGDATA/mimir fork..."
git clone --depth 1 https://github.com/NGDATA/mimir.git "${TEMP_DIR}/mimir"

print_step "Copying mimir-distributed chart..."
if [ -d "${MIMIR_CHART_DIR}" ]; then
    print_warning "Mimir chart already exists. Removing old version..."
    rm -rf "${MIMIR_CHART_DIR}"
fi

cp -r "${TEMP_DIR}/mimir/operations/helm/charts/mimir-distributed" "${MIMIR_CHART_DIR}"

print_step "Verifying chart installation..."
if [ -f "${MIMIR_CHART_DIR}/Chart.yaml" ]; then
    print_success "✅ Mimir chart installed successfully!"
    echo ""
    print_step "Chart location: ${MIMIR_CHART_DIR}"
    echo ""
    print_step "Next steps:"
    echo "  1. Update dependencies: cd helm/stackcharts && helm dependency update"
    echo "  2. Enable Mimir: Edit values/base.yaml and set mimir.enabled: true"
    echo "  3. Sync ArgoCD: ./scripts/force_argo_sync.sh"
else
    print_error "❌ Failed to install chart"
    exit 1
fi
