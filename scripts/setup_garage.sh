#!/usr/bin/env bash
# Initialize Garage after first deployment:
# - assigns the cluster layout (single node)
# - imports the static lab S3 credentials used by Loki and Tempo
# - creates the buckets and grants access
#
# Prerequisites: garage enabled via values/garage.yaml and the garage pod running.

set -Eeuo pipefail

# Source common library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

NAMESPACE="${NAMESPACE:-observability-lab}"
GARAGE_POD="${GARAGE_POD:-garage-0}"

# Static lab credentials - must match helm/stackcharts/values/garage.yaml
ACCESS_KEY_ID="GK0123456789abcdef01234567"
SECRET_ACCESS_KEY="0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"
KEY_NAME="observability-stack"

BUCKETS=(loki-chunks loki-ruler loki-admin tempo-traces)

garage_cmd() {
    kubectl exec -n "$NAMESPACE" "$GARAGE_POD" -c garage -- /garage "$@"
}

print_header "Initializing Garage object storage"

validate_prerequisites kubectl || exit 1
validate_k8s_cluster || exit 1

print_step "Step 1: Waiting for Garage pod"
if ! kubectl wait --for=condition=ready --timeout=180s pod/"$GARAGE_POD" -n "$NAMESPACE" &> /dev/null; then
    print_error "Pod $GARAGE_POD in namespace $NAMESPACE is not ready"
    echo "Is garage enabled? Uncomment values/garage.yaml in argocd/observability-stack.yaml"
    exit 1
fi
print_success "Pod $GARAGE_POD is ready"

print_step "Step 2: Assigning cluster layout"
NODE_ID=$(garage_cmd node id -q 2>/dev/null | cut -d '@' -f 1)
if [ -z "$NODE_ID" ]; then
    print_error "Could not determine Garage node ID"
    exit 1
fi
print_info "Node ID: $NODE_ID"

if garage_cmd layout show 2>/dev/null | grep -q "$NODE_ID"; then
    print_info "Layout already contains node, skipping assignment"
else
    garage_cmd layout assign -z dc1 -c 2G "$NODE_ID"
    LAYOUT_VERSION=$(( $(garage_cmd layout show | grep -oE 'version ([0-9]+)' | grep -oE '[0-9]+' | tail -1) ))
    garage_cmd layout apply --version "$LAYOUT_VERSION"
    print_success "Layout assigned and applied (version $LAYOUT_VERSION)"
fi

print_step "Step 3: Importing S3 credentials"
if garage_cmd key info "$ACCESS_KEY_ID" &> /dev/null; then
    print_info "Key $ACCESS_KEY_ID already exists, skipping import"
else
    garage_cmd key import --yes -n "$KEY_NAME" "$ACCESS_KEY_ID" "$SECRET_ACCESS_KEY"
    print_success "Key $KEY_NAME imported"
fi

print_step "Step 4: Creating buckets and granting access"
for bucket in "${BUCKETS[@]}"; do
    if garage_cmd bucket info "$bucket" &> /dev/null; then
        print_info "Bucket $bucket already exists"
    else
        garage_cmd bucket create "$bucket"
        print_success "Bucket $bucket created"
    fi
    garage_cmd bucket allow --read --write --owner "$bucket" --key "$ACCESS_KEY_ID" > /dev/null
done
print_success "Bucket permissions granted to $KEY_NAME"

print_step "Step 5: Restarting Loki and Tempo to pick up S3 storage"
kubectl rollout restart statefulset/loki -n "$NAMESPACE" &> /dev/null || print_warning "Could not restart loki"
kubectl rollout restart statefulset/tempo -n "$NAMESPACE" &> /dev/null || print_warning "Could not restart tempo"

print_header "Garage initialization complete"
echo "S3 endpoint (in-cluster): http://garage:3900"
echo "Region:                   garage"
echo "Buckets:                  ${BUCKETS[*]}"
