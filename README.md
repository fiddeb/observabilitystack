# ObservabilityStack

A **development and learning** observability platform built on **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo**. Perfect for **local labs**, **learning**, and **proof-of-concepts**. Deployed via **ArgoCD** for GitOps management with **S3 storage** backend.

> ⚠️  **Not for Production**: This setup is designed for development, learning, and lab environments. For production deployments, additional security, scaling, and operational considerations are required.

## Quick Start

```bash
# Clone and install
git clone https://github.com/fiddeb/observabilitystack.git
cd observabilitystack

# Install everything with one command
./scripts/install_argo.sh
```

**That's it!** Your observability stack is now running with:
- **Grafana** at http://grafana.k8s.test (admin/admin)
- **ArgoCD** at http://argocd.k8s.test (admin/<password>)
- **Prometheus** at http://prometheus.k8s.test  
- **Loki** at http://loki.k8s.test
- **Tempo** at http://tempo.k8s.test
- **OpenTelemetry Collector** at http://otel-collector.k8s.test

## Features

- **OpenTelemetry Collector** - Unified telemetry data collection and routing
- **Grafana** - Pre-configured dashboards with all data sources  
- **Loki** - Scalable log aggregation with S3 storage
- **Tempo** - High-scale distributed tracing with S3 storage
- **Prometheus** - Metrics collection with remote write support
- **Minio** - S3-compatible storage for logs and traces
- **ArgoCD** - GitOps deployment and management
- **Lab-Friendly** - Easy setup for development, learning, and testing
- **Educational** - Great for understanding observability concepts


**Data Flow:**
- **Logs** → OpenTelemetry Collector → Loki → S3 Storage → Grafana
- **Metrics** → OpenTelemetry Collector → Prometheus → Grafana  
- **Traces** → OpenTelemetry Collector → Tempo → S3 Storage → Grafana

## Test the Pipeline

Verify everything works end-to-end:

```bash
# Run automated tests
kubectl apply -f telemetry-test-jobs.yaml

# Check results in Grafana
echo "Metrics: Navigate to Prometheus → telemetrygen_tests_total"
echo "Logs: Navigate to Loki → {job=\"telemetrygen-logs\"}"  
echo "Traces: Navigate to Tempo → {service.name=\"telemetrygen\"}"
```

## Documentation

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

# Send test log
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","Hello ObservabilityStack!"]]}]}'

# Query logs  
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --since=5m

# Check S3 storage
kubectl -n observability-lab exec $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls local/loki-chunks/
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
