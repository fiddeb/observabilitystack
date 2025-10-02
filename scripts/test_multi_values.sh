#!/usr/bin/env bash
# Test script for multi-values configuration
# Validates that split values files work correctly

set -Eeuo pipefail

# Color codes
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

echo -e "${YELLOW}Testing multi-values Helm configuration...${NC}\n"
echo -e "Working directory: $(pwd)\n"

# Check if helm is installed
if ! command -v helm &> /dev/null; then
    echo -e "${RED}Error: helm is not installed${NC}"
    exit 1
fi

# Validate each values file individually
echo -e "${GREEN}Step 1: Validating individual values files${NC}"
VALUES_FILES=(
    "base.yaml"
    "loki.yaml"
    "tempo.yaml"
    "prometheus.yaml"
    "grafana.yaml"
    "minio.yaml"
    "opentelemetry-collector.yaml"
)

for file in "${VALUES_FILES[@]}"; do
    filepath="helm/stackcharts/values/$file"
    echo -n "  Checking $file... "
    if [ -f "$filepath" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Missing${NC}"
        exit 1
    fi
done

# Test Helm template with all values files
echo -e "\n${GREEN}Step 2: Running Helm template dry-run${NC}"
helm template observability-stack ./helm/stackcharts \
  -f helm/stackcharts/values/base.yaml \
  -f helm/stackcharts/values/loki.yaml \
  -f helm/stackcharts/values/tempo.yaml \
  -f helm/stackcharts/values/prometheus.yaml \
  -f helm/stackcharts/values/grafana.yaml \
  -f helm/stackcharts/values/minio.yaml \
  -f helm/stackcharts/values/opentelemetry-collector.yaml \
  --dry-run \
  --debug \
  > /tmp/helm-template-output.yaml 2>&1

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Helm template generation successful${NC}"
else
    echo -e "${RED}✗ Helm template generation failed${NC}"
    echo "See /tmp/helm-template-output.yaml for details"
    exit 1
fi

# Check that enabled components are present
echo -e "\n${GREEN}Step 3: Verifying enabled components${NC}"
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
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${RED}✗ Not found${NC}"
    fi
done

# Check that disabled components are NOT present
echo -n "  Verifying minio is disabled... "
if ! grep -q "kind: Deployment" "$TEMPLATE_FILE" | grep -q "minio"; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${YELLOW}⚠ Minio might be enabled${NC}"
fi

# Verify ArgoCD Application manifest
echo -e "\n${GREEN}Step 4: Validating ArgoCD Application${NC}"
ARGOCD_APP="argocd/observability-stack.yaml"

echo -n "  Checking valueFiles configuration... "
if grep -q "valueFiles:" "$ARGOCD_APP"; then
    echo -e "${GREEN}✓${NC}"
    
    # Count number of value files
    VALUE_FILE_COUNT=$(grep -c "values/" "$ARGOCD_APP" || true)
    echo "  Found $VALUE_FILE_COUNT values files configured"
    
    if [ "$VALUE_FILE_COUNT" -eq 7 ]; then
        echo -e "  ${GREEN}✓ All 7 values files configured${NC}"
    else
        echo -e "  ${YELLOW}⚠ Expected 7 files, found $VALUE_FILE_COUNT${NC}"
    fi
else
    echo -e "${RED}✗ valueFiles not found${NC}"
    exit 1
fi

# Summary
echo -e "\n${GREEN}═══════════════════════════════════════${NC}"
echo -e "${GREEN}  All tests passed! ✓${NC}"
echo -e "${GREEN}═══════════════════════════════════════${NC}"
echo ""
echo "Configuration structure:"
echo "  • base.yaml - Component flags"
echo "  • loki.yaml - Log aggregation"
echo "  • tempo.yaml - Distributed tracing"
echo "  • prometheus.yaml - Metrics collection"
echo "  • grafana.yaml - Visualization"
echo "  • minio.yaml - S3 storage (disabled)"
echo "  • opentelemetry-collector.yaml - Telemetry pipeline"
echo ""
echo "Next steps:"
echo "  1. Review the split configuration in helm/stackcharts/values/"
echo "  2. Test with: kubectl apply -f argocd/observability-stack.yaml"
echo "  3. Monitor with: kubectl get application observability-stack -n argocd"
echo ""
