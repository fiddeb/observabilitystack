#!/bin/bash
set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Variables
ARGOCD_NAMESPACE="argocd"
OBS_NAMESPACE="observability-lab"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
REPO_ROOT=$(get_repo_root)
ARGOCD_APP_MANIFEST="${REPO_ROOT}/argocd/observability-stack.yaml"
ARGOCD_INGRESS_MANIFEST="${REPO_ROOT}/manifests/argocd-ingress.yaml"
HELM_CHART_DIR="${REPO_ROOT}/helm/stackcharts"

print_header "🚀 Observability Stack Installation"

# Validate prerequisites
print_step "Validating prerequisites..."
validate_prerequisites kubectl helm git || exit 1
validate_k8s_cluster || exit 1
print_success "Prerequisites validated"
echo ""

# Step 1: Update Helm dependencies
print_step "Updating Helm chart dependencies..."
if [ ! -d "$HELM_CHART_DIR" ]; then
    print_error "Helm chart directory not found: $HELM_CHART_DIR"
    exit 1
fi

cd "$HELM_CHART_DIR"
helm dependency update
print_success "Helm dependencies updated"
cd "$REPO_ROOT"
echo ""

# Step 2: Install Argo CD
print_step "Installing ArgoCD..."
ensure_namespace "$ARGOCD_NAMESPACE"

print_info "Installing Argo CD..."
kubectl apply -n "$ARGOCD_NAMESPACE" -f "$ARGOCD_MANIFEST_URL"

# Wait for Argo CD server to be ready
wait_for_deployment "argocd-server" "$ARGOCD_NAMESPACE" 600
echo ""

# Step 3: Configure ArgoCD for HTTP access (insecure mode)
print_step "Configuring ArgoCD for HTTP access..."
kubectl patch configmap argocd-cmd-params-cm -n "$ARGOCD_NAMESPACE" \
    --type merge -p '{"data":{"server.insecure":"true"}}' 2>/dev/null || \
    kubectl create configmap argocd-cmd-params-cm -n "$ARGOCD_NAMESPACE" \
    --from-literal=server.insecure=true --dry-run=client -o yaml | kubectl apply -f -

# Restart ArgoCD server to apply insecure configuration
print_info "Restarting ArgoCD server..."
kubectl rollout restart deployment/argocd-server -n "$ARGOCD_NAMESPACE"
kubectl rollout status deployment/argocd-server -n "$ARGOCD_NAMESPACE" --timeout=300s
print_success "ArgoCD configured"
echo ""

# Step 4: Install ArgoCD Ingress for HTTP access
print_step "Installing ArgoCD ingress..."
kubectl apply -f "$ARGOCD_INGRESS_MANIFEST"
print_success "Ingress installed"
echo ""

# Step 5: Apply Application manifest so Argo CD takes over stack deployment
print_step "Applying Argo CD application manifest..."
kubectl apply -f "$ARGOCD_APP_MANIFEST" -n "$ARGOCD_NAMESPACE"
print_success "Application manifest applied"
echo ""

# Final information
print_header "🎉 Argo CD Installation Complete!"
echo "ArgoCD Web Interface:"
echo "  URL: http://argocd.k8s.test"
echo "  Username: admin"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "Your observability stack will be automatically synchronized."
echo "Run './scripts/force_argo_sync.sh' to force immediate sync if needed."