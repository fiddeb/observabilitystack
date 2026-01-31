# Usage Guide

How to use the ObservabilityStack for learning and experimenting with telemetry data.

> **Lab Environment**: This guide assumes you're using the lab setup with default credentials and configurations.

## Overview

The ObservabilityStack provides:
- **OpenTelemetry Collector** for telemetry ingestion with routing
- **Loki** for log storage (local filesystem) with multi-tenant support
- **Tempo** for distributed tracing (local filesystem)
- **Prometheus** for metrics
- **Grafana** for visualization with tenant-specific datasources

### Multi-Tenant Setup

Logs are isolated by tenant:
- **'foo' tenant** - Default for general logs
- **'bazz' tenant** - For audit logs
- Automatic routing based on log attributes
- Separate Grafana datasources for each

## Data Flow

```
Applications → OpenTelemetry Collector → Backends → Grafana
```

- **Logs** → OpenTelemetry Collector → Loki (local filesystem) → Grafana
- **Metrics** → OpenTelemetry Collector → Prometheus → Grafana  
- **Traces** → OpenTelemetry Collector → Tempo (local filesystem) → Grafana

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

#### Direct to Loki (Multi-Tenant)

**Send to 'foo' tenant:**
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
           ["'$(date +%s%N)'", "Log message to foo tenant"]
         ]
       }]
     }'
```

**Send to 'bazz' tenant:**
```bash
curl -H "Content-Type: application/json" \
     -H "X-Scope-OrgID: bazz" \
     -XPOST "http://loki.k8s.test/loki/api/v1/push" \
     -d '{
       "streams": [{
         "stream": {
           "job": "audit-service",
           "level": "info", 
           "category": "audit"
         },
         "values": [
           ["'$(date +%s%N)'", "Audit log message to bazz tenant"]
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

### Automatic Tenant Routing via OpenTelemetry

The OpenTelemetry Collector automatically routes logs to different tenants based on attributes:

**Route to 'bazz' tenant (audit logs):**
```bash
curl -X POST http://otel-collector.k8s.test/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "audit-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)'000000000",
          "body": {"stringValue": "User login successful"},
          "severityText": "INFO",
          "attributes": [
            {"key": "dev.audit.category", "value": {"stringValue": "authentication"}},
            {"key": "user.id", "value": {"stringValue": "user123"}}
          ]
        }]
      }]
    }]
  }'
```

**Route to 'foo' tenant (default logs):**
```bash
curl -X POST http://otel-collector.k8s.test/v1/logs \
  -H "Content-Type: application/json" \
  -d '{
    "resourceLogs": [{
      "resource": {
        "attributes": [
          {"key": "service.name", "value": {"stringValue": "web-service"}}
        ]
      },
      "scopeLogs": [{
        "logRecords": [{
          "timeUnixNano": "'$(date +%s)'000000000",
          "body": {"stringValue": "HTTP request processed"},
          "severityText": "INFO",
          "attributes": [
            {"key": "http.method", "value": {"stringValue": "GET"}},
            {"key": "http.status_code", "value": {"intValue": 200}}
          ]
        }]
      }]
    }]
  }'
```

> **Routing Logic**: Logs with a `dev.audit.category` attribute go to the 'bazz' tenant. Everything else goes to 'foo'.

## Using Grafana

### Access Grafana
- URL: http://grafana.k8s.test
- Default credentials: no log in needed default (admin/admin)

### Pre-configured Data Sources
All data sources are automatically configured:

1. **Prometheus** - Metrics from OpenTelemetry Collector
2. **Loki (foo tenant)** - Default logs from 'foo' tenant
3. **Loki (bazz tenant)** - Audit logs from 'bazz' tenant  
4. **Tempo** - Distributed traces with service map

> **Multi-Tenant Logs**: Each Loki datasource connects to a specific tenant using the `X-Scope-OrgID` header for data isolation.

### Querying Data

#### Prometheus Queries
```promql
# HTTP request rate
rate(http_requests_total[5m])

# Memory usage
container_memory_usage_bytes

# Custom metrics from OpenTelemetry
gen{}
```

#### Loki Queries

**From 'foo' tenant datasource:**
```logql
# All logs from a service
{service_name="my-service"}

# Error logs only
{service_name="my-service"} |= "error"

# Web service logs
{job="my-application", level="info"}

# Count requests per minute
sum(count_over_time({service_name="web-service"} |~ "HTTP request" [1m])) by (service_name)
```

**From 'bazz' tenant datasource (audit logs):**
```logql
# All audit logs
{job="audit-service"}

# Authentication events
{job="audit-service"} |= "login"

# Failed authentication attempts
{category="audit"} |= "failed"

# Count audit events per hour
sum(count_over_time({category="audit"} [1h])) by (category)
```

> **Tenant Isolation**: Each tenant's data is isolated. Switch between Loki datasources in Grafana to view different tenant logs.

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
kubectl apply -f manifests/telemetry-test-jobs.yaml

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

#### Check Local Storage
```bash
# Check Loki persistent volume data
kubectl get pv -l app.kubernetes.io/name=loki

# Check Tempo persistent volume data  
kubectl get pv -l app.kubernetes.io/name=tempo

# Check actual data in Loki pod
kubectl -n observability-lab exec -it deployment/loki -- ls -la /var/loki/

# Check actual data in Tempo pod
kubectl -n observability-lab exec -it deployment/tempo -- ls -la /var/tempo/
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

### Local Filesystem Storage
- **Loki logs**: Local persistent volumes  
- **Tempo traces**: Local persistent volumes
- **Persistence**: Data survives pod restarts
- **Lab setup**: No S3 configuration needed

### Check Storage Usage
```bash
# Check persistent volume claims
kubectl get pvc -n observability-lab

# Check persistent volumes
kubectl get pv

# Get storage usage for Loki
kubectl -n observability-lab exec deployment/loki -- df -h /var/loki

# Get storage usage for Tempo  
kubectl -n observability-lab exec deployment/tempo -- df -h /var/tempo
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

## Advanced

### Multi-tenancy
Loki supports multi-tenancy via the `X-Scope-OrgID` header:

```bash
# Tenant "production"
curl -H "X-Scope-OrgID: production" ...

# Tenant "staging"  
curl -H "X-Scope-OrgID: staging" ...
```
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

For detailed troubleshooting, see [Troubleshooting Guide](TROUBLESHOOTING.md).
