#!/bin/bash
set -e

# Variabler
ARGOCD_NAMESPACE="argocd"
OBS_NAMESPACE="observability-lab"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ARGOCD_APP_MANIFEST="${SCRIPT_DIR}/../argocd/observability-stack.yaml"
ARGOCD_INGRESS_MANIFEST="${SCRIPT_DIR}/../manifests/argocd-ingress.yaml"

# Installera Argo CD
echo "Skapar namespace $ARGOCD_NAMESPACE..."
kubectl create namespace $ARGOCD_NAMESPACE || echo "Namespace $ARGOCD_NAMESPACE finns redan"

echo "Installerar Argo CD..."
kubectl apply -n $ARGOCD_NAMESPACE -f $ARGOCD_MANIFEST_URL

# Vänta på att Argo CD-servern är klar (justera timeout efter behov)
echo "Väntar på att Argo CD-servern ska bli tillgänglig..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n $ARGOCD_NAMESPACE

# Konfigurera ArgoCD för HTTP-access (insecure mode)
echo "Konfigurerar ArgoCD för HTTP-access..."
kubectl patch configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --type merge -p '{"data":{"server.insecure":"true"}}' || echo "ConfigMap kunde inte patchas, skapar ny..."
kubectl create configmap argocd-cmd-params-cm -n $ARGOCD_NAMESPACE --from-literal=server.insecure=true --dry-run=client -o yaml | kubectl apply -f -

# Starta om ArgoCD server för att tillämpa insecure konfiguration
echo "Startar om ArgoCD server..."
kubectl rollout restart deployment/argocd-server -n $ARGOCD_NAMESPACE
kubectl rollout status deployment/argocd-server -n $ARGOCD_NAMESPACE --timeout=300s

# Installera ArgoCD Ingress för HTTP-access
echo "Installerar ArgoCD ingress..."
kubectl apply -f $ARGOCD_INGRESS_MANIFEST

# Applicera Applikationsmanifestet så att Argo CD tar över deploymenten av stacken
echo "Applicerar Argo CD-applikationsmanifest..."
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