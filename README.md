# ObservabilityStack

A **development and learning** observability platform built on **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo**. Perfect for **local labs**, **learning**, and **proof-of-concepts**. Deployed via **ArgoCD** for GitOps management with **local filesystem storage** and **multi-tenant support**.

> ⚠️  **Not for Production**: This setup is designed for development, learning, and lab environments. For production deployments, additional security, scaling, and operational considerations are required.

## Features

- **OpenTelemetry Collector** - Unified telemetry data collection with intelligent routing
- **Grafana** - Pre-configured dashboards with multi-tenant data sources  
- **Loki** - Scalable log aggregation with **multi-tenant support** and optimized resource usage
- **Tempo** - High-scale distributed tracing with local filesystem storage
- **Prometheus** - Metrics collection with remote write support
- **ArgoCD** - GitOps deployment and management
- **Multi-Tenant Architecture** - Separate data isolation with 'foo' and 'bazz' tenants
- **Resource Optimized** - Runs efficiently on local development machines
- **Lab-Friendly** - Easy setup for development, learning, and testing
- **Educational** - Great for understanding observability and multi-tenancy concepts

## Quick Start

### Option 1: Direct Clone (Read-Only)
```bash
# Clone and install (read-only setup)
git clone https://github.com/fiddeb/observabilitystack.git
cd observabilitystack
./scripts/install_argo.sh
```

### Option 2: Fork for Customization (Recommended)
**Perfect for learning and experimentation:**

```bash
# 1. Fork this repository on GitHub (click Fork button)
# 2. Clone your fork (replace YOUR_USERNAME)
git clone https://github.com/YOUR_USERNAME/observabilitystack.git
cd observabilitystack

# 3. Setup ArgoCD to use your repository
./scripts/setup_argocd.sh

# 4. Install everything
./scripts/install_argo.sh
```

**Why fork?** Customize configurations, experiment safely, and contribute back via pull requests.

**That's it!** Your observability stack is now running with:
- **Grafana** at http://grafana.k8s.test (admin/admin)
- **ArgoCD** at http://argocd.k8s.test (admin/<password>)
- **Prometheus** at http://prometheus.k8s.test  
- **Loki** at http://loki.k8s.test
- **Tempo** at http://tempo.k8s.test
- **OpenTelemetry Collector** at http://otel-collector.k8s.test



**Data Flow:**
- **Logs** → OpenTelemetry Collector → Loki → Local Storage → Grafana
- **Metrics** → OpenTelemetry Collector → Prometheus → Local Storage → Grafana  
- **Traces** → OpenTelemetry Collector → Tempo → Local Storage → Grafana

## Test the Pipeline

Verify everything works end-to-end:

```bash
# Run automated tests
kubectl apply -f manifests/telemetry-test-jobs.yaml

# Check results in Grafana
"Metrics: Navigate to Prometheus → telemetrygen_tests_total"
"Logs: Navigate to Loki → {job=\"telemetrygen-logs\"}"  
"Traces: Navigate to Tempo → {service.name=\"telemetrygen\"}"
```

## Project Structure

```
observabilitystack/
├── argocd/                    # ArgoCD application definitions
│   └── observability-stack.yaml
├── docs/                      # Documentation
│   ├── ARCHITECTURE.md        # Design decisions & concepts
│   ├── INSTALLATION.md
│   ├── USAGE_GUIDE.md
│   └── ...
├── helm/stackcharts/          # Helm charts for the observability stack
│   ├── Chart.yaml
│   ├── values.yaml
│   └── charts/
├── manifests/                 # Kubernetes manifests
│   ├── argocd-ingress.yaml    # ArgoCD web access
│   └── telemetry-test-jobs.yaml # Test workloads
├── scripts/                   # Automation scripts
│   ├── install_argo.sh        # Complete installation
│   ├── force_argo_sync.sh     # ArgoCD sync management
│   └── merge_feature.sh       # Git workflow
└── app/                       # Example applications
    └── src/demo/
```

## Documentation

### Architecture & Concepts
- **[Architecture Guide](docs/ARCHITECTURE.md)** - **Design decisions, patterns, and customization concepts**

### Getting Started
- **[Installation Guide](docs/INSTALLATION.md)** - Complete setup instructions
- **[Usage Guide](docs/USAGE_GUIDE.md)** - How to send and query telemetry data

### Operations  
- **[Git Workflow](docs/GIT_WORKFLOW.md)** - Branch management and deployment
- **[Quick Troubleshooting](docs/QUICK_TROUBLESHOOTING.md)** - Emergency procedures
- **[Troubleshooting Commands](docs/TROUBLESHOOTING_COMMANDS.md)** - Complete command reference

### Automation
- **[force_argo_sync.sh](scripts/force_argo_sync.sh)** - Intelligent ArgoCD sync
- **[merge_feature.sh](scripts/merge_feature.sh)** - Safe feature branch merging

## Quick Commands

```bash
# Health check and sync
./scripts/force_argo_sync.sh

# Get ArgoCD admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Send test log to 'foo' tenant
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","Hello from foo tenant!"]]}]}'

# Send test log to 'bazz' tenant  
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: bazz" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","Hello from bazz tenant!"]]}]}'

# Query logs from specific tenant
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --since=5m
logcli query --addr=http://loki.k8s.test --org-id="bazz" '{job="test"}' --since=5m

# Check persistent volumes
kubectl get pv,pvc -n observability-lab
```

## Troubleshooting

**Quick fixes:**
```bash
# Not working? Run the health check
./scripts/force_argo_sync.sh

# Still issues? Use port forwarding
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward svc/argocd-server -n argocd 8080:443 &
```

**Need help?** Check [Quick Troubleshooting](docs/QUICK_TROUBLESHOOTING.md) for emergency procedures.

## Contributing

We welcome contributions! See our [Git Workflow](docs/GIT_WORKFLOW.md) for development practices.

```bash
# Create feature branch  
git checkout -b feat/my-awesome-feature

# Make changes and test
./scripts/force_argo_sync.sh

# Merge safely
./scripts/merge_feature.sh feat/my-awesome-feature
```

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---
