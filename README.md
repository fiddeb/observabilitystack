# observabilitystack
observability stack with OpenTelemetry Grafana Loki Prometheus and Tempo

### install with helm

```
helm install traefik traefik/traefik
helm install --values loki_values.yaml loki --namespace=observability-lab grafana/loki --create-namespace
helm install --values tempo_values.yaml tempo --namespace=observability-lab grafana/tempo --create-namespace
helm install --values prometheus_values.yaml prometheus --namespace=observability-lab prometheus-community/prometheus  --create-namespace
helm install --values grafana_values.yaml.yaml grafana --namespace=observability-lab grafana/grafana --create-namespace
helm install --values opentelemetry_values.yaml otel-collector --namespace=observability-lab open-telemetry/opentelemetry-collector --create-namespace
```



curl -H "Content-Type: application/json" -XPOST -s "http://localhost:<portforwarded port>/loki/api/v1/push" --data-raw "{\"streams\": [{\"stream\": {\"job\": \"test\"}, \"values\": [[\"$(date +%s)000000000\", \"fizzbuzz\"]]}]}" -H X-Scope-OrgId:foo


