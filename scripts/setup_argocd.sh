#!/bin/bash

# Script to setup ArgoCD application with correct repository URL
# This automatically detects if you're using a fork and updates the repoURL accordingly

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Navigate to project root (in case script is run from scripts/ directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

echo -e "${GREEN}Setting up ArgoCD application...${NC}"

# Get the current git remote URL
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

if [ -z "$CURRENT_REMOTE" ]; then
    echo -e "${RED}Error: No git remote 'origin' found${NC}"
    echo "Make sure you're in a git repository with a remote origin configured"
    exit 1
fi

# Convert SSH URL to HTTPS if needed
if [[ $CURRENT_REMOTE == git@github.com:* ]]; then
    CURRENT_REMOTE=$(echo "$CURRENT_REMOTE" | sed 's/git@github.com:/https:\/\/github.com\//')
    CURRENT_REMOTE=$(echo "$CURRENT_REMOTE" | sed 's/\.git$//')
fi

# Ensure .git suffix
if [[ ! $CURRENT_REMOTE == *.git ]]; then
    CURRENT_REMOTE="${CURRENT_REMOTE}.git"
fi

echo -e "${YELLOW}Detected repository: ${CURRENT_REMOTE}${NC}"

# Check if this is the original repo or a fork
ORIGINAL_REPO="https://github.com/fiddeb/observabilitystack.git"
if [ "$CURRENT_REMOTE" = "$ORIGINAL_REPO" ]; then
    echo -e "${GREEN}Using original repository${NC}"
else
    echo -e "${YELLOW}Using forked repository${NC}"
    echo -e "${YELLOW}Original: $ORIGINAL_REPO${NC}"
    echo -e "${YELLOW}Fork: $CURRENT_REMOTE${NC}"
fi

# Create ArgoCD application with correct repoURL
echo -e "${GREEN}Creating ArgoCD application manifest...${NC}"

cat > argocd/observability-stack.yaml << EOF
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: '$CURRENT_REMOTE'
    targetRevision: main   # auto-synced with current branch
    path: helm/stackcharts
  destination:
    server: 'https://kubernetes.default.svc'
    namespace: observability-lab
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
EOF

echo -e "${GREEN}✓ ArgoCD application manifest updated with repository: ${CURRENT_REMOTE}${NC}"

# Apply to cluster if ArgoCD namespace exists
if kubectl get namespace argocd &>/dev/null; then
    echo -e "${GREEN}Applying ArgoCD application...${NC}"
    kubectl apply -f argocd/observability-stack.yaml -n argocd
    echo -e "${GREEN}✓ ArgoCD application applied successfully${NC}"
else
    echo -e "${YELLOW}ArgoCD namespace not found. Run this after installing ArgoCD:${NC}"
    echo "kubectl apply -f argocd/observability-stack.yaml -n argocd"
fi

echo -e "${GREEN}Setup complete!${NC}"