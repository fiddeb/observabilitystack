# ObservabilityStack

A complete observability stack leveraging **OpenTelemetry Collector**, **Grafana**, **Loki**, **Prometheus**, and **Tempo** for comprehensive telemetry collection and visualization.

## Features
- **OpenTelemetry Collector**: Vendor-agnostic telemetry data collection, processing, and routing
- **Grafana**: Visualization of metrics, logs, and traces with integrated datasources
- **Loki**: Horizontally scalable, highly available, multi-tenant log aggregation system
- **Prometheus**: Metric collection, storage, and alerting with remote write support
- **Tempo**: High-scale distributed tracing backend with S3 storage
- **Minio**: S3-compatible object storage backend for Loki logs and Tempo traces

---

## Installation Instructions

The observability stack is now deployed using **ArgoCD** for GitOps-based management.

### Prerequisites

1. **Install Traefik** (Ingress Controller):
   ```bash
   helm install traefik traefik/traefik
   ```

2. **Install ArgoCD and deploy the stack**:
   ```bash
   ./scripts/install_argo.sh
   ```

That's it! ArgoCD will automatically deploy and manage:
- OpenTelemetry Collector (telemetry data collection and routing)
- Loki (with Minio storage backend)
- Tempo (with Minio storage backend) 
- Prometheus (metrics collection with remote write)
- Grafana (visualization with all datasources)
- Minio (S3-compatible object storage)

---

## Using OpenTelemetry Collector

The OpenTelemetry Collector is configured to receive telemetry data via OTLP and route it to the appropriate backends:

### Sending Telemetry Data

**OTLP Endpoints:**
- gRPC: `otel-collector.observability-lab.svc.cluster.local:4317`
- HTTP: `otel-collector.observability-lab.svc.cluster.local:4318`

**Data Flow:**
- **Metrics** → OpenTelemetry Collector → Prometheus (via remote write)
- **Logs** → OpenTelemetry Collector → Loki (with tenant ID: "foo")
- **Traces** → OpenTelemetry Collector → Tempo (stored in Minio S3)

### Testing the Complete Pipeline

Run the included telemetry test jobs to verify end-to-end functionality:

```bash
kubectl apply -f telemetry-test-jobs.yaml
```

This creates three Kubernetes jobs that generate test telemetry data:
- `telemetrygen-metrics`: Generates test metrics
- `telemetrygen-logs`: Generates test logs  
- `telemetrygen-traces`: Generates test traces

Check job status:
```bash
kubectl get jobs -n observability-lab
```

All telemetry data should be visible in Grafana at `http://grafana.k8s.test`.

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

---

## Testing Loki Logging

You can test your Loki installation by sending a test log:

```bash
curl -H "Content-Type: application/json" -XPOST -s \
"http://loki.k8s.test/loki/api/v1/push" \
--data-raw "{
  \"streams\": [
    {
      \"stream\": { \"job\": \"test\" },
      \"values\": [
        [\"$(date +%s)000000000\", \"fizzbuzz\"]
      ]
    }
  ]
}" \
-H "X-Scope-OrgId: foo"
```

To verify that the log was successfully sent, use `logcli` to query Loki:

```bash
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --limit=5000 --since=60m
```

#### Explanation of the Command:
- `--addr=http://loki.k8s.test`: Specifies the URL of your Loki instance.
- `--org-id="foo"`: Specifies the tenant ID if using multi-tenancy.
- `'{job="test"}'`: Filters logs based on the label `job` with the value `test`.
- `--since=60m`: Retrieves logs generated within the last 60 minutes.
- `--limit=5000`: Limits the number of returned logs to 5000 (optional).

If everything is configured correctly, you should see your test log (`fizzbuzz`) in the `logcli result.
```bash
2024-11-21T23:26:50+01:00 {} fizzbuzz
```

## Testing Tempo Tracing

You can test your Tempo installation by sending a test trace via OTLP:

```bash
# Send a test trace (requires otel CLI or similar)
# Example using curl to send OTLP HTTP trace
curl -X POST http://tempo.k8s.test:4318/v1/traces \
  -H "Content-Type: application/x-protobuf" \
  --data-binary @test-trace.pb
```

You can also access Tempo's query interface at `http://tempo.k8s.test` and search for traces by trace ID or service name.

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
- **OpenTelemetry Collector**: Available at `otel-collector.observability-lab.svc.cluster.local:4317/4318` for OTLP telemetry ingestion

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

## Troubleshooting

- **Port Forwarding**: Use `kubectl port-forward` if services are not exposed externally.
- **Logs**: Check the logs of individual components using `kubectl logs` for debugging.

---

## Contributions

Contributions are welcome! Feel free to open an issue or submit a pull request.

---

## License

This project is licensed under the MIT License. See the `LICENSE` file for details.