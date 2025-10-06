#!/bin/bash
set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Ensure we are in the correct directory (repo root)
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Configuration
ARGOCD_APP_MANIFEST="argocd/observability-stack.yaml"

print_header "🔀 Merge Feature Branch Script"

# Check that we have a feature branch as argument
if [ $# -ne 1 ]; then
    print_error "Usage: $0 <feature-branch-name>"
    echo "Example: $0 feat/loki-s3-storage"
    exit 1
fi

FEATURE_BRANCH=$1

# Check that feature branch exists
if ! git rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
    print_error "Branch '$FEATURE_BRANCH' does not exist"
    exit 1
fi

# Check that we are on feature branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$FEATURE_BRANCH" ]; then
    print_warning "Currently on '$current_branch', switching to '$FEATURE_BRANCH'"
    git checkout "$FEATURE_BRANCH"
fi

print_step "Step 1: Commit any pending changes on feature branch"
# Commit any pending changes on feature branch
if ! git diff --quiet || ! git diff --cached --quiet; then
    print_info "Committing pending changes..."
    git add -A
    read -p "Enter commit message for pending changes: " commit_msg
    git commit -m "$commit_msg"
else
    print_success "No pending changes to commit"
fi

print_step "Step 2: Reset targetRevision to main before merge"
# Ensure that targetRevision points to main before merge
sed -i.bak "s|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g" "$ARGOCD_APP_MANIFEST"

# Commit targetRevision change
if ! git diff --quiet "$ARGOCD_APP_MANIFEST"; then
    print_info "Updating targetRevision to main before merge..."
    git add "$ARGOCD_APP_MANIFEST"
    git commit -m "fix: reset targetRevision to main before merge"
else
    print_success "targetRevision already points to main"
fi

print_step "Step 3: Switch to main and merge"
# Switch to main branch
git checkout main

# Update main from remote
print_info "Updating main branch from remote..."
git pull origin main

# Merge feature branch
print_info "Merging '$FEATURE_BRANCH' into main..."
git merge "$FEATURE_BRANCH"

print_step "Step 4: Clean up"
# Ask if we should delete feature branch
read -p "Delete feature branch '$FEATURE_BRANCH'? (y/N): " delete_branch
if [[ $delete_branch =~ ^[Yy]$ ]]; then
    git branch -d "$FEATURE_BRANCH"
    print_success "Deleted feature branch '$FEATURE_BRANCH'"
fi

# Clean up backup files
rm -f "$ARGOCD_APP_MANIFEST.bak"

print_success "Merge completed successfully!"
print_info "Next steps:"
echo "  1. Push changes: git push origin main"
echo "  2. Run ArgoCD sync: ./scripts/force_argo_sync.sh"
echo "  3. Verify deployment in cluster"
