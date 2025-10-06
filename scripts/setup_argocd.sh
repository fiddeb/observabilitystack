#!/bin/bash
set -Eeuo pipefail

# Script to setup ArgoCD application with correct repository URL
# This automatically detects if you're using a fork and updates the repoURL accordingly

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Navigate to project root
PROJECT_ROOT=$(get_repo_root)
cd "$PROJECT_ROOT"

print_header "Setting up ArgoCD application..."

# Get the current git remote URL
CURRENT_REMOTE=$(git remote get-url origin 2>/dev/null || echo "")

if [ -z "$CURRENT_REMOTE" ]; then
    print_error "No git remote 'origin' found"
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

echo "Detected repository: $CURRENT_REMOTE"

# Check if this is the original repo or a fork
ORIGINAL_REPO="https://github.com/fiddeb/observabilitystack.git"
if [ "$CURRENT_REMOTE" = "$ORIGINAL_REPO" ]; then
    print_success "Using original repository"
else
    print_warning "Using forked repository"
    echo "Original: $ORIGINAL_REPO"
    echo "Fork: $CURRENT_REMOTE"
fi

# Create ArgoCD application with correct repoURL
print_step "Creating ArgoCD application manifest..."

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

print_success "ArgoCD application manifest updated with repository: ${CURRENT_REMOTE}"

# Apply to cluster if ArgoCD namespace exists
if kubectl get namespace argocd &>/dev/null; then
    print_step "Applying ArgoCD application..."
    kubectl apply -f argocd/observability-stack.yaml -n argocd
    print_success "ArgoCD application applied successfully"
else
    print_warning "ArgoCD namespace not found. Run this after installing ArgoCD:"
    echo "kubectl apply -f argocd/observability-stack.yaml -n argocd"
fi

print_success "Setup complete!"