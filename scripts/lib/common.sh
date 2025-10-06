#!/usr/bin/env bash
# Common functions for observability stack scripts

set -Eeuo pipefail

# Color codes
export RED='\033[0;31m'
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export BLUE='\033[0;34m'
export NC='\033[0m'

# Get repository root directory
get_repo_root() {
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[1]}")" && pwd)"
    echo "$(cd "$script_dir/.." && pwd)"
}

# Change to repository root
cd_repo_root() {
    local repo_root=$(get_repo_root)
    cd "$repo_root"
}

# Print colored messages
print_info() {
    echo -e "${BLUE}$1${NC}"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

print_header() {
    echo ""
    echo "=================================="
    echo "$1"
    echo "=================================="
    echo ""
}

# Validate that a command exists
validate_command() {
    local cmd="$1"
    if ! command -v "$cmd" &> /dev/null; then
        print_error "Required command not found: $cmd"
        return 1
    fi
    return 0
}

# Validate multiple prerequisites
validate_prerequisites() {
    local missing=()
    
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        print_error "Missing required commands: ${missing[*]}"
        echo "Please install missing tools and try again"
        return 1
    fi
    
    return 0
}

# Check Kubernetes cluster connectivity
validate_k8s_cluster() {
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        echo "Please ensure your cluster is running and kubeconfig is configured"
        return 1
    fi
    return 0
}

# Wait for deployment to be ready
wait_for_deployment() {
    local deployment="$1"
    local namespace="$2"
    local timeout="${3:-300}"
    
    print_info "Waiting for deployment $deployment in namespace $namespace..."
    if kubectl wait --for=condition=available --timeout="${timeout}s" \
        deployment/"$deployment" -n "$namespace" &> /dev/null; then
        print_success "Deployment $deployment is ready"
        return 0
    else
        print_error "Deployment $deployment failed to become ready within ${timeout}s"
        return 1
    fi
}

# Check if namespace exists
namespace_exists() {
    local namespace="$1"
    kubectl get namespace "$namespace" &> /dev/null
}

# Create namespace if it doesn't exist
ensure_namespace() {
    local namespace="$1"
    if namespace_exists "$namespace"; then
        print_info "Namespace $namespace already exists"
    else
        print_info "Creating namespace $namespace..."
        kubectl create namespace "$namespace"
        print_success "Namespace $namespace created"
    fi
}
