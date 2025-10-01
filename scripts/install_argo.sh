#!/bin/bash
set -e

# Variables
ARGOCD_NAMESPACE="argocd"
OBS_NAMESPACE="observability-lab"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_APP_MANIFEST="${SCRIPT_DIR}/../argocd/observability-stack.yaml"
ARGOCD_INGRESS_MANIFEST="${SCRIPT_DIR}/../manifests/argocd-ingress.yaml"

# Install Argo CD
echo "Creating namespace $ARGOCD_NAMESPACE..."
kubectl create namespace $ARGOCD_NAMESPACE || echo "Namespace $ARGOCD_NAMESPACE already exists"

echo "Installing Argo CD..."
kubectl apply -n $ARGOCD_NAMESPACE -f $ARGOCD_MANIFEST_URL

# Wait for Argo CD server to be ready (adjust timeout as needed)
echo "Waiting for Argo CD server to become available..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n $ARGOCD_NAMESPACE

# Configure ArgoCD for HTTP access (insecure mode)
echo "Configuring ArgoCD for HTTP access..."
kubectl patch configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --type merge -p '{"data":{"server.insecure":"true"}}' || echo "ConfigMap could not be patched, creating new..."
kubectl create configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --from-literal=server.insecure=true --dry-run=client -o yaml | kubectl apply -f -

# Restart ArgoCD server to apply insecure configuration
echo "Restarting ArgoCD server..."
kubectl rollout restart deployment/argocd-server -n $ARGOCD_NAMESPACE
kubectl rollout status deployment/argocd-server -n $ARGOCD_NAMESPACE --timeout=300s

# Install ArgoCD Ingress for HTTP access
echo "Installing ArgoCD ingress..."
kubectl apply -f $ARGOCD_INGRESS_MANIFEST

# Apply Application manifest so Argo CD takes over stack deployment
echo "Applying Argo CD application manifest..."
kubectl apply -f $ARGOCD_APP_MANIFEST -n $ARGOCD_NAMESPACE

# Ge slutinformation
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