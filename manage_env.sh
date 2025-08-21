#!/bin/bash

# DEPRECATED: This script is deprecated in favor of ArgoCD GitOps deployment
# Use ./scripts/install_argo.sh instead for production deployments
# This script is kept for legacy/manual installations only

# Manage installation, updating, and uninstallation of the test environment

set -e

# Function to display usage information
usage() {
    echo "Usage: $0 {install|update|uninstall}"
    exit 1
}

# Check that exactly one argument is provided
if [ $# -ne 1 ]; then
    usage
fi

ACTION=$1

# Define Helm repositories with separate arrays
REPO_NAMES=("grafana" "prometheus-community" "open-telemetry")
REPO_URLS=("https://grafana.github.io/helm-charts" \
           "https://prometheus-community.github.io/helm-charts" \
           "https://open-telemetry.github.io/opentelemetry-helm-charts")

# Add Helm repositories
echo "Adding necessary Helm repositories..."
for ((i=0; i<${#REPO_NAMES[@]}; i++)); do
    repo="${REPO_NAMES[$i]}"
    url="${REPO_URLS[$i]}"
    if ! helm repo list | grep -q "^$repo\s"; then
        helm repo add "$repo" "$url"
        echo "Added repository '$repo'."
    else
        echo "Repository '$repo' is already added."
    fi
done

# Update Helm repositories
echo "Updating Helm repositories..."
helm repo update

# Define the namespace for most components
NAMESPACE="observability-lab"

# Function to handle installation and updating
install_or_update() {
    COMPONENT_NAME=$1
    RELEASE_NAME=$2
    CHART=$3
    shift 3
    if [ "$ACTION" = "install" ]; then
        echo "Installing $COMPONENT_NAME..."
        helm install "$RELEASE_NAME" "$CHART" "$@"
    elif [ "$ACTION" = "update" ]; then
        echo "Updating $COMPONENT_NAME..."
        helm upgrade "$RELEASE_NAME" "$CHART" "$@"
    fi
}

# Function to handle uninstallation
uninstall_component() {
    COMPONENT_NAME=$1
    RELEASE_NAME=$2
    COMPONENT_NAMESPACE=$3
    echo "Uninstalling $COMPONENT_NAME..."
    helm uninstall "$RELEASE_NAME" --namespace "$COMPONENT_NAMESPACE" || echo "$COMPONENT_NAME was not installed."
}

# Handle actions based on the provided argument
case "$ACTION" in
    install|update)
        # Traefik (installed in the default namespace)
        install_or_update "Traefik" "traefik" "traefik/traefik"
        # Other components in the observability-lab namespace
        install_or_update "Loki" "loki" "grafana/loki" --values loki_values.yaml --namespace "$NAMESPACE" --create-namespace
        install_or_update "Tempo" "tempo" "grafana/tempo" --values tempo_values.yaml --namespace "$NAMESPACE" --create-namespace
        install_or_update "Prometheus" "prometheus" "prometheus-community/prometheus" --values prometheus_values.yaml --namespace "$NAMESPACE" --create-namespace
        install_or_update "Grafana" "grafana" "grafana/grafana" --values grafana_values.yaml --namespace "$NAMESPACE" --create-namespace
        install_or_update "OpenTelemetry Collector" "otel-collector" "open-telemetry/opentelemetry-collector" --values opentelemetry_values.yaml --namespace "$NAMESPACE" --create-namespace
        ;;
    uninstall)
        # Uninstall components in reverse order to handle dependencies

        # OpenTelemetry Collector
        uninstall_component "OpenTelemetry Collector" "otel-collector" "$NAMESPACE"

        # Grafana
        uninstall_component "Grafana" "grafana" "$NAMESPACE"

        # Prometheus
        uninstall_component "Prometheus" "prometheus" "$NAMESPACE"

        # Tempo
        uninstall_component "Tempo" "tempo" "$NAMESPACE"

        # Loki
        uninstall_component "Loki" "loki" "$NAMESPACE"
        
        # Traefik (installed in the default namespace)
        uninstall_component "Traefik" "traefik" "default"
        ;;
    *)
        usage
        ;;
esac

echo "Action '$ACTION' completed successfully."
