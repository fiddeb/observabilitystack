#!/bin/bash
set -e

# Variables
ARGOCD_NAMESPACE="argocd"
OBS_NAMESPACE="observability-lab"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
ARGOCD_APP_MANIFEST="${REPO_ROOT}/argocd/observability-stack.yaml"
ARGOCD_INGRESS_MANIFEST="${REPO_ROOT}/manifests/argocd-ingress.yaml"
HELM_CHART_DIR="${REPO_ROOT}/helm/stackcharts"

echo "=================================="
echo "🚀 Observability Stack Installation"
echo "=================================="
echo ""

# Step 1: Update Helm dependencies
echo "📦 Updating Helm chart dependencies..."
if [ ! -d "$HELM_CHART_DIR" ]; then
    echo "❌ Error: Helm chart directory not found: $HELM_CHART_DIR"
    exit 1
fi

cd "$HELM_CHART_DIR"
helm dependency update
echo "✅ Helm dependencies updated"
cd "$REPO_ROOT"
echo ""

# Step 2: Install Argo CD
echo "📥 Installing ArgoCD..."
echo "Creating namespace $ARGOCD_NAMESPACE..."
kubectl create namespace $ARGOCD_NAMESPACE || echo "Namespace $ARGOCD_NAMESPACE already exists"

echo "Installing Argo CD..."
kubectl apply -n $ARGOCD_NAMESPACE -f $ARGOCD_MANIFEST_URL

# Wait for Argo CD server to be ready (adjust timeout as needed)
echo "⏳ Waiting for Argo CD server to become available..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n $ARGOCD_NAMESPACE
echo "✅ ArgoCD server is ready"
echo ""

# Step 3: Configure ArgoCD for HTTP access (insecure mode)
echo "⚙️  Configuring ArgoCD for HTTP access..."
kubectl patch configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --type merge -p '{"data":{"server.insecure":"true"}}' || echo "ConfigMap could not be patched, creating new..."
kubectl create configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --from-literal=server.insecure=true --dry-run=client -o yaml | kubectl apply -f -

# Restart ArgoCD server to apply insecure configuration
echo "🔄 Restarting ArgoCD server..."
kubectl rollout restart deployment/argocd-server -n $ARGOCD_NAMESPACE
kubectl rollout status deployment/argocd-server -n $ARGOCD_NAMESPACE --timeout=300s
echo "✅ ArgoCD configured"
echo ""

# Step 4: Install ArgoCD Ingress for HTTP access
echo "🌐 Installing ArgoCD ingress..."
kubectl apply -f $ARGOCD_INGRESS_MANIFEST
echo "✅ Ingress installed"
echo ""

# Step 5: Apply Application manifest so Argo CD takes over stack deployment
echo "📋 Applying Argo CD application manifest..."
kubectl apply -f $ARGOCD_APP_MANIFEST -n $ARGOCD_NAMESPACE
echo "✅ Application manifest applied"
echo ""

# Final information
echo "=================================="
echo "🎉 Argo CD Installation Complete!"
echo "=================================="
echo ""
echo "ArgoCD Web Interface:"
echo "  URL: http://argocd.k8s.test"
echo "  Username: admin"
echo "  Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath=\"{.data.password}\" | base64 -d"
echo ""
echo "Your observability stack will be automatically synchronized."
echo "Run './scripts/force_argo_sync.sh' to force immediate sync if needed."