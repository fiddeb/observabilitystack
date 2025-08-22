# Usage Guide

How to use the ObservabilityStack for learning and experimenting with telemetry data.

> 💡 **Lab Environment**: This guide assumes you're using the lab setup with default credentials and configurations. Perfect for learning observability concepts!

## Overview

The ObservabilityStack provides a complete learning platform with:
- **OpenTelemetry Collector** as the central telemetry ingestion point
- **Loki** for log storage and querying
- **Tempo** for distributed tracing  
- **Prometheus** for metrics collection
- **Grafana** for unified visualization
- **Minio** for S3-compatible storage

## Data Flow

```
Applications → OpenTelemetry Collector → Backends → Grafana
```

**Detailed Flow:**
- **Logs** → OpenTelemetry Collector → Loki (S3 storage) → Grafana
- **Metrics** → OpenTelemetry Collector → Prometheus → Grafana  
- **Traces** → OpenTelemetry Collector → Tempo (S3 storage) → Grafana

## Sending Telemetry Data

### OpenTelemetry Collector Endpoints

**Internal (from within cluster):**
- gRPC: `otel-collector.observability-lab.svc.cluster.local:4317`
- HTTP: `otel-collector.observability-lab.svc.cluster.local:4318`

**External (via ingress):**
- HTTP: `http://otel-collector.k8s.test`

### Example: Sending Logs

#### Via OTLP HTTP
```bash
curl -X POST http://otel-collector.k8s.test/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}},
          {"key": "service.version", "value": {"stringValue": "1.0.0"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)'000000000",
          "body": {"stringValue": "Application started successfully"},
          "severityText": "INFO",
          "attributes": [
            {"key": "user.id", "value": {"stringValue": "user123"}},
            {"key": "action", "value": {"stringValue": "startup"}}
          ]
        }]
      }]
    }]
  }'
```

#### Direct to Loki (bypass OTEL)
```bash
curl -H "Content-Type: application/json" \
     -H "X-Scope-OrgID: foo" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{
       "streams": [{
         "stream": {
           "job": "my-application",
           "level": "info",
           "service": "my-service"
         },
         "values": [
           ["'$(date +%s%N)'", "Direct log message to Loki"]
         ]
       }]
     }'
```

### Example: Sending Metrics

```bash
curl -X POST http://otel-collector.k8s.test/v1/metrics \
  -H "Content-Type: application/json" \
  -d '{
    "resourceMetrics": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}},
          {"key": "host.name", "value": {"stringValue": "web-server-01"}}
        ]
      },
      "scopeMetrics": [{
        "metrics": [{
          "name": "http_requests_total",
          "description": "Total HTTP requests",
          "unit": "1",
          "sum": {
            "dataPoints": [{
              "timeUnixNano": "'$(date +%s)'000000000",
              "asInt": "157",
              "attributes": [
                {"key": "method", "value": {"stringValue": "GET"}},
                {"key": "status", "value": {"stringValue": "200"}}
              ]
            }],
            "aggregationTemporality": 2,
            "isMonotonic": true
          }
        }]
      }]
    }]
  }'
```

### Example: Sending Traces

```bash
curl -X POST http://otel-collector.k8s.test/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "my-service"}},
          {"key": "service.version", "value": {"stringValue": "1.0.0"}}
        ]
      },
      "scopeSpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "HTTP GET /api/users",
          "kind": 3,
          "startTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
          "endTimeUnixNano": "'$((($(date +%s) + 2) * 1000000000))'",
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.url", "value": {"stringValue": "/api/users"}},
            {"key": "http.status_code", "value": {"intValue": "200"}}
          ],
          "status": {"code": 1}
        }]
      }]
    }]
  }'
```

## Using Grafana

### Access Grafana
- URL: http://grafana.k8s.test
- Default credentials: no log in needed default (admin/admin)

### Pre-configured Data Sources
All data sources are automatically configured:

1. **Prometheus** - Metrics from OpenTelemetry Collector
2. **Loki** - Logs with multi-tenancy support
3. **Tempo** - Distributed traces with service map

### Querying Data

#### Prometheus Queries
```promql
# HTTP request rate
rate(http_requests_total[5m])

# Memory usage
container_memory_usage_bytes

# Custom metrics from OpenTelemetry
telemetrygen_tests_total
```

#### Loki Queries
```logql
# All logs from a service
{service_name="my-service"}

# Error logs only
{service_name="my-service"} |= "error"

# Logs with specific labels
{job="my-application", level="error"}

# Count errors per minute  
sum(count_over_time({service_name="my-service"} |= "error" [1m])) by (service_name)
```

#### Tempo Queries
```
# Search by service name
{service.name="my-service"}

# Search by operation
{name="HTTP GET /api/users"}

# Search by trace ID
{traceID="abc123def456"}
```

## Testing the Pipeline

### Automated Tests
Run the complete test suite:

```bash
# Deploy test jobs
kubectl apply -f telemetry-test-jobs.yaml

# Wait for completion
kubectl wait --for=condition=complete job/telemetrygen-metrics -n observability-lab --timeout=60s
kubectl wait --for=condition=complete job/telemetrygen-logs -n observability-lab --timeout=60s
kubectl wait --for=condition=complete job/telemetrygen-traces -n observability-lab --timeout=60s

```

### Manual Verification

#### Check Log Ingestion
```bash
# Send test log
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{"streams":[{"stream":{"job":"test"},"values":[["'$(date +%s%N)'","Test log message"]]}]}'

# Query logs
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --limit=10 --since=5m
```

#### Check S3 Storage
```bash
# Get Minio pod name
MINIO_POD=$(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}')

# Check Loki data in S3
kubectl -n observability-lab exec $MINIO_POD -- mc ls local/loki-chunks/

# Check Tempo data in S3  
kubectl -n observability-lab exec $MINIO_POD -- mc ls local/tempo-traces/
```

## Application Integration

### OpenTelemetry SDKs
Configure your applications to send telemetry to the OpenTelemetry Collector:

**Environment Variables:**
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.k8s.test
export OTEL_SERVICE_NAME=my-application
export OTEL_RESOURCE_ATTRIBUTES=service.version=1.0.0,environment=production
```

**For internal cluster applications:**
```bash
export OTEL_EXPORTER_OTLP_ENDPOINT=http://otel-collector.observability-lab.svc.cluster.local:4318
```

### Kubernetes Applications
Add OpenTelemetry auto-instrumentation to your deployments:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: my-app
spec:
  template:
    spec:
      containers:
      - name: app
        image: my-app:latest
        env:
        - name: OTEL_EXPORTER_OTLP_ENDPOINT
          value: "http://otel-collector.observability-lab.svc.cluster.local:4318"
        - name: OTEL_SERVICE_NAME
          value: "my-application"
        - name: OTEL_RESOURCE_ATTRIBUTES
          value: "service.version=1.0.0,environment=production"
```

## Storage and Retention

### S3 Storage (Minio)
- **Loki logs**: Stored in `loki-chunks` bucket
- **Tempo traces**: Stored in `tempo-traces` bucket  
- **Persistence**: Data persists across pod restarts

### Access Minio Console
```bash
# Port forward to Minio console
kubectl port-forward service/minio-console 9090:9090 -n observability-lab &

# Get admin password
kubectl get secret minio -n observability-lab -o jsonpath='{.data.root-password}' | base64 -d

# Access: http://localhost:9090 (minio / <password>)
```

## Monitoring and Alerts

### Built-in Metrics
The stack exposes metrics for monitoring itself:

- **Loki metrics**: http://loki.k8s.test:3100/metrics
- **Tempo metrics**: http://tempo.k8s.test:3200/metrics  
- **Prometheus metrics**: http://prometheus.k8s.test/metrics
- **OTEL Collector metrics**: Available in Prometheus

### Health Checks
```bash
# Check service health
curl http://loki.k8s.test/ready
curl http://tempo.k8s.test/ready
curl http://prometheus.k8s.test/-/ready

# Automated health check
./scripts/force_argo_sync.sh
```

## Advanced Configuration

### Multi-tenancy
Loki supports multi-tenancy via the `X-Scope-OrgID` header:

```bash
# Send logs to tenant "production"
curl -H "X-Scope-OrgID: production" ...

# Send logs to tenant "staging"  
curl -H "X-Scope-OrgID: staging" ...
```

### Custom Configuration
Modify values in `helm/stackcharts/values.yaml` and apply:

```bash
# Edit configuration
vim helm/stackcharts/values.yaml

# Apply changes
./scripts/force_argo_sync.sh
```

## Troubleshooting

For detailed troubleshooting, see:
- [Troubleshooting Commands](TROUBLESHOOTING_COMMANDS.md) - Complete command reference
- [Quick Troubleshooting](QUICK_TROUBLESHOOTING.md) - Emergency procedures
