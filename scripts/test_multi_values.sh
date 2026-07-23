#!/usr/bin/env bash
# Test script for multi-values configuration
# Validates that split values files work correctly

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

print_header "Testing multi-values Helm configuration..."
echo "Working directory: $(pwd)"
echo ""

# Check if helm is installed
validate_command helm || exit 1

# Validate each values file individually
print_step "Step 1: Validating individual values files"
VALUES_FILES=(
    "base.yaml"
    "loki.yaml"
    "tempo.yaml"
    "prometheus.yaml"
    "grafana.yaml"
    "garage.yaml"
    "opentelemetry-collector.yaml"
)

for file in "${VALUES_FILES[@]}"; do
    filepath="helm/stackcharts/values/$file"
    echo -n "  Checking $file... "
    if [ -f "$filepath" ]; then
        print_success "✓"
    else
        print_error "✗ Missing"
        exit 1
    fi
done

# Test Helm template with all values files
echo ""
print_step "Step 2: Running Helm template dry-run"
helm template observability-stack ./helm/stackcharts \
  -f helm/stackcharts/values/base.yaml \
  -f helm/stackcharts/values/loki.yaml \
  -f helm/stackcharts/values/tempo.yaml \
  -f helm/stackcharts/values/prometheus.yaml \
  -f helm/stackcharts/values/grafana.yaml \
  -f helm/stackcharts/values/opentelemetry-collector.yaml \
  --dry-run \
  --debug \
  > /tmp/helm-template-output.yaml 2>&1

if [ $? -eq 0 ]; then
    print_success "Helm template generation successful"
else
    print_error "Helm template generation failed"
    echo "See /tmp/helm-template-output.yaml for details"
    exit 1
fi

# Check that enabled components are present
echo ""
print_step "Step 3: Verifying enabled components"
TEMPLATE_FILE="/tmp/helm-template-output.yaml"

# Components that should be present
EXPECTED_COMPONENTS=(
    "loki"
    "tempo"
    "prometheus"
    "grafana"
    "otel-collector"
)

for component in "${EXPECTED_COMPONENTS[@]}"; do
    echo -n "  Looking for $component... "
    if grep -q "$component" "$TEMPLATE_FILE"; then
        echo "✓"
    else
        echo "✗ Not found"
    fi
done

# Check that disabled components are NOT present
echo -n "  Verifying garage is disabled by default... "
if ! grep -q "kind: StatefulSet" <(grep -A3 "name: garage" "$TEMPLATE_FILE" 2>/dev/null); then
    echo "✓"
else
    print_warning "Garage might be enabled"
fi

# Test the Garage S3 storage profile
echo ""
print_step "Step 3b: Testing Garage S3 storage profile"
helm template observability-stack ./helm/stackcharts \
  -f helm/stackcharts/values/base.yaml \
  -f helm/stackcharts/values/loki.yaml \
  -f helm/stackcharts/values/tempo.yaml \
  -f helm/stackcharts/values/prometheus.yaml \
  -f helm/stackcharts/values/grafana.yaml \
  -f helm/stackcharts/values/opentelemetry-collector.yaml \
  -f helm/stackcharts/values/garage.yaml \
  --dry-run \
  > /tmp/helm-template-garage-output.yaml 2>&1

echo -n "  Verifying garage is deployed... "
if grep -q "charts/garage/templates/workload.yaml" /tmp/helm-template-garage-output.yaml; then
    echo "✓"
else
    print_error "Garage not rendered"
    exit 1
fi

echo -n "  Verifying loki uses s3 storage... "
if grep -q "object_store: s3" /tmp/helm-template-garage-output.yaml; then
    echo "✓"
else
    print_error "Loki not configured for s3"
    exit 1
fi

echo -n "  Verifying tempo uses s3 storage... "
if grep -q "backend: s3" /tmp/helm-template-garage-output.yaml; then
    echo "✓"
else
    print_error "Tempo not configured for s3"
    exit 1
fi

# Verify ArgoCD Application manifest
echo ""
print_step "Step 4: Validating ArgoCD Application"
ARGOCD_APP="argocd/observability-stack.yaml"

echo -n "  Checking valueFiles configuration... "
if grep -q "valueFiles:" "$ARGOCD_APP"; then
    echo "✓"
    
    # Count number of active (uncommented) value files
    VALUE_FILE_COUNT=$(grep -c "^\s*- values/" "$ARGOCD_APP" || true)
    echo "  Found $VALUE_FILE_COUNT values files configured"
    
    if [ "$VALUE_FILE_COUNT" -eq 9 ]; then
        print_success "All 9 values files configured"
    else
        print_warning "Expected 9 files, found $VALUE_FILE_COUNT"
    fi
else
    print_error "valueFiles not found"
    exit 1
fi

# Summary
echo ""
print_success "═══════════════════════════════════════"
print_success "  All tests passed! ✓"
print_success "═══════════════════════════════════════"
echo ""
echo "Configuration structure:"
echo "  • base.yaml - Component flags"
echo "  • loki.yaml - Log aggregation"
echo "  • tempo.yaml - Distributed tracing"
echo "  • prometheus.yaml - Metrics collection"
echo "  • grafana.yaml - Visualization"
echo "  • garage.yaml - S3 storage profile (opt-in: enables Garage + S3 for Loki/Tempo)"
echo "  • opentelemetry-collector.yaml - Telemetry pipeline"
echo ""
echo "Next steps:"
echo "  1. Review the split configuration in helm/stackcharts/values/"
echo "  2. Test with: kubectl apply -f argocd/observability-stack.yaml"
echo "  3. Monitor with: kubectl get application observability-stack -n argocd"
echo ""
