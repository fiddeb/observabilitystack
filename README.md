# ObservabilityStack

A minimal observability stack leveraging **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo** for testing.

## Features
- **OpenTelemetry**: Vendor-agnostic way to receive, process and export telemetry data.
- **Grafana**: Visualization of telemetry.
- **Loki**: Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus
- **Prometheus**: Metric collection and alerting.
- **Tempo**: Grafana Tempo is an open source, easy-to-use, and high-scale distributed tracing backend.
- **Minio**: S3-compatible object storage backend for Loki and Tempo traces/logs.

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
- Loki (with Minio storage backend)
- Tempo (with Minio storage backend) 
- Prometheus (metrics collection)
- Grafana (visualization with all datasources)
- Minio (S3-compatible object storage)

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

- Loki: `http://loki.k8s.test` to use logcli or push logs directly to loki
- Grafana: `http://grafana.k8s.test` to visualize telemetry data
- Tempo: `http://tempo.k8s.test` for distributed tracing queries
- OpenTelemetry Collector: `http://otel.k8s.test` to send telemetry signals (not yet configured in [opentelemetry_values.yaml](opentelemetry_values.yaml))

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