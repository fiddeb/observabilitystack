# observabilitystack
observability stack with OpenTelemetry Grafana Loki Prometheus and Tempo

### install with helm

helm install traefik traefik/traefik
helm install --values loki_values.yaml loki --namespace=observability-lab grafana/loki
helm install --values grafana_values.yaml.yaml grafana --namespace=observability-lab grafana/grafana
helm install --values opentelemetry_values.yaml otel-collector --namespace=observability-lab open-telemetry/opentelemetry-collector 
 
