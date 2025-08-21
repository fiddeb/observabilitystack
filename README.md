# ObservabilityStack

A minimal observability stack leveraging **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo** for testing.

## Features
- **OpenTelemetry**: Vendor-agnostic way to receive, process and export telemetry data.
- **Grafana**: Visualization of telemetry.
- **Loki**: Loki is a horizontally scalable, highly available, multi-tenant log aggregation system inspired by Prometheus
- **Prometheus**: Metric collection and alerting.
- **Tempo**: Grafana Tempo is an open source, easy-to-use, and high-scale distributed tracing backend.

---

## Installation Instructions

You can set up the observability stack in two ways:

### Option 1: Manual Installation Using Helm

Install each component manually with Helm using the following commands:

```bash
# Traefik (reverse proxy)
helm install traefik traefik/traefik

# Loki (logging)
helm install --values loki_values.yaml loki --namespace=observability-lab grafana/loki --create-namespace

# Tempo (tracing)
helm install --values tempo_values.yaml tempo --namespace=observability-lab grafana/tempo --create-namespace

# Prometheus (metrics)
helm install --values prometheus_values.yaml prometheus --namespace=observability-lab prometheus-community/prometheus --create-namespace

# Grafana (visualization)
helm install --values grafana_values.yaml grafana --namespace=observability-lab grafana/grafana --create-namespace

# OpenTelemetry Collector
helm install --values opentelemetry_values.yaml otel-collector --namespace=observability-lab open-telemetry/opentelemetry-collector --create-namespace
```

**Important**: Traefik must be installed manually using Helm, as it is not included in the script. Run the following command to install Traefik:

```bash
helm install traefik traefik/traefik
```

---

### Option 2: Automated Installation Using Script

Use the `manage_env.sh` script to install, update, or uninstall the observability stack. This script handles the installation and configuration of Loki, Tempo, Prometheus, Grafana, and the OpenTelemetry Collector.

#### Usage

1. Ensure the script is executable:

   ```bash
   chmod +x manage_env.sh
   ```

2. Run the script with one of the following commands:
   - To **install** the stack:

     ```bash
     ./manage_env.sh install
     ```

   - To **update** the stack:

     ```bash
     ./manage_env.sh update
     ```

   - To **uninstall** the stack:

     ```bash
     ./manage_env.sh uninstall
     ```

**Note**: The script does not include Traefik. Make sure to install Traefik separately using the Helm command provided above.

---


- Always install Traefik manually with Helm before proceeding with other components (or use another Ingress controller)
- Use the manual installation method for complete control.
- Use the script `manage_env.sh` for an easier and automated setup process.


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
- OpenTelemetry Collector: `http://otel.k8s.test` to send telemetry signals (not yet configured in [opentelemetry_values.yaml](opentelemetry_values.yaml))

---

## Customization

- Modify the `values.yaml` files for each service (`loki_values.yaml`, `tempo_values.yaml`, etc.) to customize configurations like resource limits, persistence, and authentication.

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