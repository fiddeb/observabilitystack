#!/bin/bash
set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# Ensure we are in the correct directory (repo root)
REPO_ROOT=$(get_repo_root)
cd "$REPO_ROOT"

# Configuration
ARGOCD_NAMESPACE="argocd"
APP_NAME="observability-stack"
TARGET_NAMESPACE="observability-lab"
ARGOCD_APP_MANIFEST="argocd/observability-stack.yaml"

print_header "🔄 Force ArgoCD Sync Script"

# Get current Git branch (after ensuring correct directory)
current_branch=$(git rev-parse --abbrev-ref HEAD)

# Warning if we are not on main branch
if [ "$current_branch" != "main" ]; then
    print_warning "You are on branch '$current_branch', not 'main'"
    print_info "Consider using main branch for production deployments"
    print_info "To merge properly: ./scripts/merge_feature.sh $current_branch"
    echo ""
fi

# Step 1: Check current Git branch and ArgoCD targetRevision
print_step "Checking Git branch and ArgoCD targetRevision..."

# Get current Git branch
echo "Current Git branch: $current_branch"

# Get current targetRevision from ArgoCD application
current_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}' 2>/dev/null || echo "Unknown")
echo "ArgoCD targetRevision: $current_target"

# Check if targetRevision is a tag (starts with 'v')
if [[ "$current_target" =~ ^v[0-9]+\.[0-9]+\.[0-9]+ ]]; then
    print_success "Using stable release tag: $current_target"
    print_info "To update to a new release, manually edit argocd/observability-stack.yaml"
    skip_target_update=true
else
    skip_target_update=false
fi

# Check if targetRevision needs updating (only for branches, not tags)
if [ "$skip_target_update" = false ] && [ "$current_branch" != "$current_target" ]; then
    print_info "Updating ArgoCD targetRevision from '$current_target' to '$current_branch'"
    
    # Update targetRevision in YAML file
    sed -i.bak "s|targetRevision: .*|targetRevision: $current_branch   # auto-synced with current branch|g" "$ARGOCD_APP_MANIFEST"
    
    # Apply the updated manifest
    print_step "Applying updated ArgoCD application manifest..."
    kubectl apply -f "$ARGOCD_APP_MANIFEST" -n $ARGOCD_NAMESPACE
    
    # Wait briefly for the update to register
    sleep 3
    
    # Verify that targetRevision has been updated
    new_target=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.spec.source.targetRevision}')
    echo "New targetRevision: $new_target"
else
    print_success "ArgoCD targetRevision matches current configuration"
fi

# Function to wait for sync
wait_for_sync() {
    local max_attempts=30
    local attempt=1
    
    print_info "Waiting for synchronization to complete..."
    
    while [ $attempt -le $max_attempts ]; do
        sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Unknown")
        health_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Unknown")
        
        echo "Attempt $attempt/$max_attempts - Sync: ${sync_status}, Health: ${health_status}"
        
        if [ "$sync_status" == "Synced" ] && [ "$health_status" == "Healthy" ]; then
            print_success "Synchronization complete!"
            return 0
        fi
        
        sleep 5
        ((attempt++))
    done
    
    print_warning "Timeout: Synchronization took longer than expected"
    return 1
}

# Step 2: Check that ArgoCD application exists and show status
print_step "Checking ArgoCD application status..."
if ! kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE &>/dev/null; then
    print_error "ArgoCD application '$APP_NAME' not found in namespace '$ARGOCD_NAMESPACE'"
    exit 1
fi

# Show current status
print_info "Current status:"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

# Step 3: Force refresh (fetch latest from Git)
print_step "Forcing refresh from Git repository..."
kubectl annotate application $APP_NAME -n $ARGOCD_NAMESPACE argocd.argoproj.io/refresh=hard --overwrite

# Step 4: Wait briefly for refresh to complete
print_info "Waiting for refresh..."
sleep 5

# Step 5: Check if there are changes that need syncing
print_step "Checking sync status after refresh..."
sync_status=$(kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o jsonpath='{.status.sync.status}')
echo "Sync status: $sync_status"

if [ "$sync_status" == "OutOfSync" ]; then
    print_info "Application is OutOfSync - forcing synchronization..."
    
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
    print_success "Application is already synced"
else
    print_info "Sync status: $sync_status"
fi

# Step 7: Wait for sync to complete
wait_for_sync

# Step 8: Show final results
print_step "Final status:"
kubectl get application $APP_NAME -n $ARGOCD_NAMESPACE -o wide

print_step "Resources in target namespace:"
kubectl get pods,svc,configmap -n $TARGET_NAMESPACE -l "app.kubernetes.io/instance=observability-stack" 2>/dev/null || echo "No resources found yet"

print_success "Script complete!"
