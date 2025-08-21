#!/bin/bash
set -e

# Variabler
ARGOCD_NAMESPACE="argocd"
OBS_NAMESPACE="observability-lab"
ARGOCD_MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml"
ARGOCD_APP_MANIFEST="../argocd/observability-stack.yaml"  # Relativ sökväg, justera om nödvändigt

# Installera Argo CD
echo "Skapar namespace $ARGOCD_NAMESPACE..."
kubectl create namespace $ARGOCD_NAMESPACE || echo "Namespace $ARGOCD_NAMESPACE finns redan"

echo "Installerar Argo CD..."
kubectl apply -n $ARGOCD_NAMESPACE -f $ARGOCD_MANIFEST_URL

# Vänta på att Argo CD-servern är klar (justera timeout efter behov)
echo "Väntar på att Argo CD-servern ska bli tillgänglig..."
kubectl wait --for=condition=available --timeout=600s deployment/argocd-server -n $ARGOCD_NAMESPACE

# Applicera Applikationsmanifestet så att Argo CD tar över deploymenten av stacken
echo "Applicerar Argo CD-applikationsmanifest..."
kubectl apply -f $ARGOCD_APP_MANIFEST -n $ARGOCD_NAMESPACE

echo "Argo CD har nu bootstrappats och din observability-stack kommer att synkroniseras automatiskt."