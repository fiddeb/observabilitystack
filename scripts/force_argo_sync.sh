#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure we are in the correct directory (repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$REPO_ROOT"

# Configuration
ARGOCD_NAMESPACE="argocd"
APP_NAME="observability-stack"
TARGET_NAMESPACE="observability-lab"
ARGOCD_APP_MANIFEST="argocd/observability-stack.yaml"

echo -e "${BLUE}🔄 Force ArgoCD Sync Script${NC}"
echo "=================================="

# Get current Git branch (after ensuring correct directory)
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Warning if we are not on main branch
if [ "$current_branch" != "main" ]; then
    echo -e "${YELLOW}⚠️  WARNING: You are on branch '$current_branch', not 'main'${NC}"
    echo -e "${YELLOW}💡 Consider using main branch for production deployments${NC}"
    echo -e "${YELLOW}   To merge properly: ./scripts/merge_feature.sh $current_branch${NC}"
    echo ""
fi

# Step 1: Check current Git branch and ArgoCD targetRevision
echo -e "${BLUE}📋 Checking Git branch and ArgoCD targetRevision...${NC}"

# Get current Git branch
echo -e "Current Git branch: ${YELLOW}$current_branch${NC}"

# Get current targetRevision from ArgoCD application
current_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "Unknown")
echo -e "ArgoCD targetRevision: ${YELLOW}$current_target${NC}"

# Check if targetRevision is a tag (starts with 'v')
if [[ "$current_target" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    echo -e "${GREEN}✅ Using stable release tag: $current_target${NC}"
    echo -e "${BLUE}💡 To update to a new release, manually edit argocd/observability-stack.yaml${NC}"
    skip_target_update=true
else
    skip_target_update=false
fi

# Check if targetRevision needs updating (only for branches, not tags)
if [ "$skip_target_update" = false ] && [ "$current_branch" != "$current_target" ]; then
    echo -e "${YELLOW}🔄 Updating ArgoCD targetRevision from '$current_target' to '$current_branch'${NC}"
    
    # Update targetRevision in YAML file
    sed -i.bak "s|targetRevision: .*|targetRevision: $current_branch   # auto-synced with current branch|g" "$ARGOCD_APP_MANIFEST"
    
    # Apply the updated manifest
    echo -e "${BLUE}📝 Applying updated ArgoCD application manifest...${NC}"
    kubectl apply -f "$ARGOCD_APP_MANIFEST" -n $ARGOCD_NAMESPACE
    
    # Wait briefly for the update to register
    sleep 3
    
    # Verify that targetRevision has been updated
    new_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}')
    echo -e "New targetRevision: ${GREEN}$new_target${NC}"
else
    echo -e "${GREEN}✅ ArgoCD targetRevision matches current configuration${NC}"
fi

# Function to wait for sync
wait_for_sync() {
    local max_attempts=30
    local attempt=1
    
    echo -e "${YELLOW}⏳ Waiting for synchronization to complete...${NC}"
    
    while [ $attempt -le $max_attempts ]; do
        sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        health_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        echo -e "Attempt $attempt/$max_attempts - Sync: ${sync_status}, Health: ${health_status}"
        
        if [ "$sync_status" == "Synced" ] && [ "$health_status" == "Healthy" ]; then
            echo -e "${GREEN}✅ Synchronization complete!${NC}"
            return 0
        fi
        
        sleep 5
        ((attempt++))
    done
    
    echo -e "${YELLOW}⚠️  Timeout: Synchronization took longer than expected${NC}"
    return 1
}

# Step 2: Check that ArgoCD application exists and show status
echo -e "${BLUE}📊 Checking ArgoCD application status...${NC}"
if ! kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE &>/dev/null; then
    echo -e "${RED}❌ ArgoCD application '$APP_NAME' not found in namespace '$ARGOCD_NAMESPACE'${NC}"
    exit 1
fi

# Show current status
echo -e "${BLUE}📋 Current status:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

# Step 3: Force refresh (fetch latest from Git)
echo -e "${BLUE}🔄 Forcing refresh from Git repository...${NC}"
kubectl annotate application $APP_NAME -n $ARGOCD_NAMESPACE argocd.argoproj.io/refresh=hard --overwrite

# Step 4: Wait briefly for refresh to complete
echo -e "${YELLOW}⏳ Waiting for refresh...${NC}"
sleep 5

# Step 5: Check if there are changes that need syncing
echo -e "${BLUE}🔍 Checking sync status after refresh...${NC}"
sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}')
echo "Sync status: $sync_status"

if [ "$sync_status" == "OutOfSync" ]; then
    echo -e "${YELLOW}🔄 Application is OutOfSync - forcing synchronization...${NC}"
    
    # Step 6: Force sync
    kubectl patch application $APP_NAME -n $ARGOCD_NAMESPACE --type='merge' -p='{
        "operation": {
            "sync": {
                "syncStrategy": {
                    "apply": {
                        "force": true
                    }
                }
            }
        }
    }'
    
    # Enable auto-sync if not active
    kubectl patch application $APP_NAME -n $ARGOCD_NAMESPACE --type='merge' -p='{
        "spec": {
            "syncPolicy": {
                "automated": {
                    "prune": true,
                    "selfHeal": true
                }
            }
        }
    }'
    
elif [ "$sync_status" == "Synced" ]; then
    echo -e "${GREEN}✅ Application is already synced${NC}"
else
    echo -e "${YELLOW}ℹ️  Sync status: $sync_status${NC}"
fi

# Step 7: Wait for sync to complete
wait_for_sync

# Step 8: Show final results
echo -e "${BLUE}📊 Final status:${NC}"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

echo -e "${BLUE}📦 Resources in target namespace:${NC}"
kubectl get pods,svc,configmap -n $TARGET_NAMESPACE -l "app.kubernetes.io/instance=observability-stack" 2>/dev/null || echo "No resources found yet"

echo -e "${GREEN}🎉 Script complete!${NC}"
