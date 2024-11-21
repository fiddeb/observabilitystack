# ObservabilityStack

A minimal observability stack leveraging **OpenTelemetry**, **Grafana**, **Loki**, **Prometheus**, and **Tempo** for test.

## Features
- **OpenTelemetry**: Standardized telemetry data collection and export.
- **Grafana**: visualization of telemetry.
- **Loki**: Log aggregation and querying.
- **Prometheus**: Metric collection and alerting.
- **Tempo**: Distributed tracing.

---

## Installation Instructions

Install the components using Helm:

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

---

## Testing Loki Logging

You can test the Loki installation by sending a test log:

```bash
curl -H "Content-Type: application/json" -XPOST -s \
"http://loki.dev.local/loki/api/v1/push" \
--data-raw '{
  "streams": [
    {
      "stream": { "job": "test" },
      "values": [
        ["$(date +%s)000000000", "fizzbuzz"]
      ]
    }
  ]
}' \
-H "X-Scope-OrgId: foo"
```

---

## Using Ingress

If an ingress controller (e.g., Traefik) is configured, update your `/etc/hosts` file to map domain names for the services. Add the following entries:

```plaintext
127.0.0.1 loki.dev.local grafana.dev.local otel.dev.local
```

This setup will allow you to access the services via:

- Loki: `http://loki.dev.local` to use logcli or push logs directly to loki
- Grafana: `http://grafana.dev.local` to visualize telemetry data
- OpenTelemetry Collector: `http://otel.dev.local` to send telemetry signals (not yet configured in [opentelemetry_values.yaml](opentelemetry_values.yaml))

---

## Customization

- Modify the `values.yaml` files for each service (`loki_values.yaml`, `tempo_values.yaml`, etc.) to customize configurations like resource limits, persistence, and authentication.

---

## Dashboard and Visualization

Access **Grafana** to set up dashboards and visualize metrics, logs, and traces:

1. Log in to Grafana (`http://grafana.dev.local` or the relevant address). No log in needed.

To enable login:
update grafana_values.yaml under grafana.ini
  auth:
    disable_login: false
  auth.anonymous:
    enabled: false
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