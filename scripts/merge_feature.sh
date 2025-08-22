#!/bin/bash
set -e

# Färger för output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Säkerställ att vi är i rätt katalog (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Säkerställ att vi är i rätt katalog (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Konfiguration
ARGOCD_APP_MANIFEST="argocd/observability-stack.yaml"

echo -e "${BLUE}🔀 Merge Feature Branch Script${NC}"
echo "====================================="

# Kontrollera att vi har en feature branch som argument
if [ $# -ne 1 ]; then
    echo -e "${RED}❌ Usage: $0 <feature-branch-name>${NC}"
    echo "Example: $0 feat/loki-s3-storage"
    exit 1
fi

FEATURE_BRANCH=$1

# Kontrollera att feature branch existerar
if ! git rev-parse --verify "$FEATURE_BRANCH" >/dev/null 2>&1; then
    echo -e "${RED}❌ Branch '$FEATURE_BRANCH' does not exist${NC}"
    exit 1
fi

# Kontrollera att vi är på feature branch
current_branch=$(git rev-parse --abbrev-ref HEAD)
if [ "$current_branch" != "$FEATURE_BRANCH" ]; then
    echo -e "${YELLOW}⚠️  Currently on '$current_branch', switching to '$FEATURE_BRANCH'${NC}"
    git checkout "$FEATURE_BRANCH"
fi

echo -e "${BLUE}📝 Step 1: Commit any pending changes on feature branch${NC}"
# Committa eventuella ändringar på feature branch
if ! git diff --quiet || ! git diff --cached --quiet; then
    echo -e "${YELLOW}🔄 Committing pending changes...${NC}"
    git add -A
    read -p "Enter commit message for pending changes: " commit_msg
    git commit -m "$commit_msg"
else
    echo -e "${GREEN}✅ No pending changes to commit${NC}"
fi

echo -e "${BLUE}📝 Step 2: Reset targetRevision to main before merge${NC}"
# Säkerställ att targetRevision pekar på main innan merge
sed -i.bak "s|targetRevision: .*|targetRevision: main   # auto-synced with current branch|g" "$ARGOCD_APP_MANIFEST"

# Committa targetRevision-ändringen
if ! git diff --quiet "$ARGOCD_APP_MANIFEST"; then
    echo -e "${YELLOW}🔄 Updating targetRevision to main before merge...${NC}"
    git add "$ARGOCD_APP_MANIFEST"
    git commit -m "fix: reset targetRevision to main before merge"
else
    echo -e "${GREEN}✅ targetRevision already points to main${NC}"
fi

echo -e "${BLUE}📝 Step 3: Switch to main and merge${NC}"
# Byt till main branch
git checkout main

# Uppdatera main från remote
echo -e "${YELLOW}🔄 Updating main branch from remote...${NC}"
git pull origin main

# Merga feature branch
echo -e "${YELLOW}🔀 Merging '$FEATURE_BRANCH' into main...${NC}"
git merge "$FEATURE_BRANCH"

echo -e "${BLUE}📝 Step 4: Clean up${NC}"
# Fråga om vi ska ta bort feature branch
read -p "Delete feature branch '$FEATURE_BRANCH'? (y/N): " delete_branch
if [[ $delete_branch =~ ^[Yy]$ ]]; then
    git branch -d "$FEATURE_BRANCH"
    echo -e "${GREEN}✅ Deleted feature branch '$FEATURE_BRANCH'${NC}"
fi

# Rensa backup-filer
rm -f "$ARGOCD_APP_MANIFEST.bak"

echo -e "${GREEN}🎉 Merge completed successfully!${NC}"
echo -e "${BLUE}💡 Next steps:${NC}"
echo "  1. Push changes: git push origin main"
echo "  2. Run ArgoCD sync: ./scripts/force_argo_sync.sh"
echo "  3. Verify deployment in cluster"
