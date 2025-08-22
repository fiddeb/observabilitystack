# ObservabilityStack

A complete, production-ready observability platform built on **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo**. Deployed via **ArgoCD** for GitOps management with **S3 storage** backend.

## 🚀 Quick Start

```bash
# Clone and install
git clone https://github.com/fiddeb/observabilitystack.git
cd observabilitystack

# Install everything with one command
./scripts/install_argo.sh
```

**That's it!** Your observability stack is now running with:
- 📊 **Grafana** at http://grafana.k8s.test (admin/admin)
- 📈 **Prometheus** at http://prometheus.k8s.test  
- 📝 **Loki** at http://loki.k8s.test
- 🔍 **Tempo** at http://tempo.k8s.test
- 🔄 **OpenTelemetry Collector** at http://otel-collector.k8s.test

## ✨ Features

- **🔄 OpenTelemetry Collector** - Unified telemetry data collection and routing
- **📊 Grafana** - Pre-configured dashboards with all data sources  
- **📝 Loki** - Scalable log aggregation with S3 storage
- **🔍 Tempo** - High-scale distributed tracing with S3 storage
- **📈 Prometheus** - Metrics collection with remote write support
- **💾 Minio** - S3-compatible storage for logs and traces
- **🚀 ArgoCD** - GitOps deployment and management
- **🛠️ Production Ready** - S3 persistence, multi-tenancy, auto-scaling

## 📋 Architecture

```
Applications → OpenTelemetry Collector → Grafana
                      ↓
        Loki ← → Tempo ← → Prometheus
              ↓
            Minio S3
```

**Data Flow:**
- **📝 Logs** → OpenTelemetry Collector → Loki → S3 Storage → Grafana
- **📈 Metrics** → OpenTelemetry Collector → Prometheus → Grafana  
- **🔍 Traces** → OpenTelemetry Collector → Tempo → S3 Storage → Grafana

## 🧪 Test the Pipeline

Verify everything works end-to-end:

```bash
# Run automated tests
kubectl apply -f telemetry-test-jobs.yaml

# Check results in Grafana
echo "📊 Metrics: Navigate to Prometheus → telemetrygen_tests_total"
echo "📝 Logs: Navigate to Loki → {job=\"telemetrygen-logs\"}"  
echo "🔍 Traces: Navigate to Tempo → {service.name=\"telemetrygen\"}"
```

## 📖 Documentation

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

## 🔧 Quick Commands

```bash
# Health check and sync
./scripts/force_argo_sync.sh

# Send test log
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","Hello ObservabilityStack!"]]}]}'

# Query logs  
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --since=5m

# Check S3 storage
kubectl -n observability-lab exec $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls local/loki-chunks/
```

## 🆘 Troubleshooting

**Quick fixes:**
```bash
# Not working? Run the health check
./scripts/force_argo_sync.sh

# Still issues? Use port forwarding
kubectl port-forward service/grafana 3000:80 -n observability-lab &
```

**Need help?** Check [Quick Troubleshooting](docs/QUICK_TROUBLESHOOTING.md) for emergency procedures.

## 🤝 Contributing

We welcome contributions! See our [Git Workflow](docs/GIT_WORKFLOW.md) for development practices.

```bash
# Create feature branch  
git checkout -b feat/my-awesome-feature

# Make changes and test
./scripts/force_argo_sync.sh

# Merge safely
./scripts/merge_feature.sh feat/my-awesome-feature
```

**Data Flow:**
- **Metrics** → OpenTelemetry Collector → Prometheus (via remote write)
- **Logs** → OpenTelemetry Collector → Loki (with tenant ID: "foo")
- **Traces** → OpenTelemetry Collector → Tempo (stored in Minio S3)

### Testing the Complete Telemetry Pipeline

The observability stack includes automated test jobs that verify all three telemetry signals work end-to-end through the OpenTelemetry Collector:

#### Quick Test - Run All Signals

```bash
# Run test jobs for metrics, logs, and traces
kubectl apply -f telemetry-test-jobs.yaml

# Check job completion status
kubectl get jobs -n observability-lab

# Wait for jobs to complete (should take ~30 seconds)
kubectl wait --for=condition=complete job/telemetrygen-metrics -n observability-lab --timeout=60s
kubectl wait --for=condition=complete job/telemetrygen-logs -n observability-lab --timeout=60s  
kubectl wait --for=condition=complete job/telemetrygen-traces -n observability-lab --timeout=60s
```

#### Verification in Grafana

Open Grafana at `http://grafana.k8s.test` and verify each signal:

**1. Metrics (Prometheus datasource):**
- Navigate to Explore → Prometheus
- Query: `telemetrygen_tests_total` or `{__name__=~"telemetrygen.*"}`
- Should show test metrics generated by the telemetrygen-metrics job

**2. Logs (Loki datasource):**
- Navigate to Explore → Loki  
- Query: `{job="telemetrygen-logs"}` or `{service_name="telemetrygen"}`
- Should show test log entries with body containing "This is a test log message"

**3. Traces (Tempo datasource):**
- Navigate to Explore → Tempo
- Search by service name: `telemetrygen` 
- Or query: `{service.name="telemetrygen"}`
- Should show distributed traces from the telemetrygen-traces job

#### Manual Testing

You can also test individual signals manually:

**Test Logs via OpenTelemetry Collector:**
```bash
# Send log via OTLP HTTP to OpenTelemetry Collector (external endpoint)
curl -X POST http://otel-collector.k8s.test/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "manual-test"}}]},
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)'000000000",
          "body": {"stringValue": "Manual test log via OpenTelemetry Collector"},
          "severityText": "INFO"
        }]
      }]
    }]
  }'
```

**Test Metrics via OpenTelemetry Collector:**
```bash
# Send metrics via OTLP HTTP to OpenTelemetry Collector (external endpoint)
curl -X POST http://otel-collector.k8s.test/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "manual-test"}}]},
      "scopeMetrics": [{
        "metrics": [{
          "name": "manual_test_counter",
          "unit": "1",
          "sum": {
            "dataPoints": [{
              "timeUnixNano": "'$(date +%s)'000000000",
              "asInt": "42",
              "attributes": [{"key": "test", "value": {"stringValue": "manual"}}]
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

**Test Traces via OpenTelemetry Collector:**
```bash
# Send trace via OTLP HTTP to OpenTelemetry Collector (external endpoint)
curl -X POST http://otel-collector.k8s.test/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {"attributes": [{"key": "service.name", "value": {"stringValue": "manual-test"}}]},
      "scopeSpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "manual-test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(date +%s)'000000000",
          "endTimeUnixNano": "'$(($(date +%s) + 1))'000000000",
          "attributes": [{"key": "test", "value": {"stringValue": "manual"}}]
        }]
      }]
    }]
  }'
```

**Legacy: Direct Loki Test (bypassing OpenTelemetry Collector):**
```bash
curl -H "Content-Type: application/json" -XPOST -s \
"http://loki.k8s.test/loki/api/v1/push" \
--data-raw "{
  \"streams\": [
    {
      \"stream\": { \"job\": \"direct-test\" },
      \"values\": [
        [\"$(date +%s)000000000\", \"Direct Loki test - bypassing OpenTelemetry Collector\"]
      ]
    }
  ]
}" \
-H "X-Scope-OrgId: foo"

# Verify with logcli
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="direct-test"}' --limit=5000 --since=5m
```

---

### Legacy: Manual Installation Using Helm

For manual control, you can still deploy using the umbrella chart:

```bash
# Add required Helm repositories
helm repo add grafana https://grafana.github.io/helm-charts
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add minio https://charts.min.io/
helm repo update

# Install the entire stack
helm install observability-stack ./helm/stackcharts --namespace=observability-lab --create-namespace
```

## Using Ingress

If an ingress controller (e.g., Traefik) is configured, set up wildcard DNS resolution using dnsmasq:

### Setup dnsmasq for wildcard DNS

1. Configure dnsmasq to resolve `*.k8s.test` domains:
   ```bash
   # Add to /opt/homebrew/etc/dnsmasq.conf
   listen-address=127.0.0.1
   bind-interfaces
   address=/.k8s.test/127.0.0.1
   ```

2. Setup resolver for the k8s.test domain:
   ```bash
   echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/k8s.test
   ```

3. Restart dnsmasq:
   ```bash
   sudo brew services restart dnsmasq
   ```

This setup will allow you to access the services via:

- **Grafana**: `http://grafana.k8s.test` - Main dashboard for visualizing metrics, logs, and traces
- **Loki**: `http://loki.k8s.test` - Direct log ingestion and querying via logcli
- **Tempo**: `http://tempo.k8s.test` - Distributed tracing queries and trace search
- **OpenTelemetry Collector**: `http://otel-collector.k8s.test` - OTLP telemetry ingestion endpoints (/v1/logs, /v1/metrics, /v1/traces)

---

## Customization

- Modify the umbrella chart configuration in `helm/stackcharts/values.yaml` to customize configurations like resource limits, persistence, and authentication for all observability components.

---

## Dashboard and Visualization

Access **Grafana** to set up dashboards and visualize metrics, logs, and traces:

1. Log in to Grafana (`http://grafana.k8s.test` or the relevant address). No log in needed.


>To enable login:
update grafana_values.yaml under grafana.ini
```yaml
  auth:
    disable_login: false
  auth.anonymous:
    enabled: false
```
---

## Documentation

### Comprehensive Guides
- **[Troubleshooting Commands](docs/TROUBLESHOOTING_COMMANDS.md)** - Complete reference of all debugging, testing, and verification commands
- **[Quick Troubleshooting](docs/QUICK_TROUBLESHOOTING.md)** - Fast checklists and emergency procedures  
- **[Git Workflow](docs/GIT_WORKFLOW.md)** - Branch management and ArgoCD deployment procedures

### Scripts
- **[force_argo_sync.sh](scripts/force_argo_sync.sh)** - Automated ArgoCD synchronization with branch detection
- **[merge_feature.sh](scripts/merge_feature.sh)** - Safe feature branch merging with automatic targetRevision management

---

## Troubleshooting

- **Quick Health Check**: Run `./scripts/force_argo_sync.sh` to verify and sync deployment
- **Emergency Access**: Use `kubectl port-forward` if ingress services are unavailable
- **Complete Command Reference**: See [docs/TROUBLESHOOTING_COMMANDS.md](docs/TROUBLESHOOTING_COMMANDS.md)
- **Fast Recovery**: Follow checklists in [docs/QUICK_TROUBLESHOOTING.md](docs/QUICK_TROUBLESHOOTING.md)

---

## Contributions

Contributions are welcome! Feel free to open an issue or submit a pull request.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.