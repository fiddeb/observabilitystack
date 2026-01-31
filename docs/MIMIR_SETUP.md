# Mimir Integration - Monolithic Mode

## Overview

I added Mimir to the stack in monolithic mode using NGDATA's fork of Grafana Mimir, which supports single-pod deployments.

- **Chart**: `mimir-distributed` v5.6.0 (from Grafana Helm repo)
- **Deployment Mode**: Monolithic (one pod runs all components)
- **Storage**: Local filesystem (persistent volume)
- **Ingress**: `http://mimir.k8s.test`

## Enable Mimir

### 1. Update Chart Dependencies

```bash
cd helm/stackcharts
helm dependency update
cd ../..
```

### 2. Enable in base.yaml

Edit `helm/stackcharts/values/base.yaml`:

```yaml
mimir:
  enabled: true
```

### 3. Deploy via ArgoCD

```bash
./scripts/force_argo_sync.sh
```

Or manually:

```bash
argocd app sync observability-stack --force
```

## Verify Installation

```bash
# Check pods
kubectl get pods -n observability-lab | grep mimir

# Expected output:
# mimir-0                    1/1     Running   0          2m
# mimir-nginx-xxxxx          1/1     Running   0          2m

# Test endpoints
curl http://mimir.k8s.test/ready
curl http://mimir.k8s.test/metrics
```

## Usage

### Send Metrics via Prometheus Remote Write

Configure a Prometheus instance to send metrics to Mimir:

```yaml
# prometheus-config.yaml
remote_write:
  - url: http://mimir-nginx/api/v1/push
```

### Query Metrics via Grafana

Mimir is already configured as a datasource in Grafana:
- **Name**: Mimir
- **URL**: `http://mimir-nginx/prometheus`
- **Type**: Prometheus (Mimir-compatible)

Visit `http://grafana.k8s.test` and select "Mimir" as the datasource in Explore.

### Query Metrics via API

```bash
# PromQL query
curl -G http://mimir.k8s.test/prometheus/api/v1/query \
  --data-urlencode 'query=up'

# Label values
curl http://mimir.k8s.test/prometheus/api/v1/label/__name__/values
```

## Configuration

### Key Settings

Configure in `helm/stackcharts/values/mimir.yaml`:

```yaml
mimir:
  monolithic:
    replicas: 1  # Increase for HA
    persistentVolume:
      size: "10Gi"  # Adjust as needed
    resources:
      limits:
        memory: "2Gi"
        cpu: "1000m"
  
  mimir:
    structuredConfig:
      limits:
        compactor_blocks_retention_period: 30d  # Data retention
```

### Storage Backend

**Default**: Local filesystem (`/data/mimir`)

To switch to S3/MinIO:

```yaml
mimir:
  mimir:
    structuredConfig:
      common:
        storage:
          backend: s3
          s3:
            endpoint: minio:9000
            bucket_name: mimir-blocks
            access_key_id: minioadmin
            secret_access_key: minioadmin
            insecure: true
```

### Enable AlertManager

```yaml
mimir:
  alertmanager:
    enabled: true
```

## Architecture

### Monolithic vs Microservices

**Monolithic Mode** (current setup):
- One pod runs all components (distributor, ingester, querier, etc.)
- Good for development and smaller production environments
- Simpler to set up and debug

**Microservices Mode**:
- Each component runs separately
- Better scalability for large production environments
- Requires more resources and complexity

### Components

Monolithic mode includes:
- **Distributor**: Receives metrics from remote write
- **Ingester**: Writes metrics to storage
- **Querier**: Handles PromQL queries
- **Compactor**: Compresses and retains blocks
- **Store Gateway**: Reads from long-term storage
- **Nginx**: Gateway/load balancer

## Troubleshooting

### Pod Won't Start

```bash
# Check events
kubectl describe pod mimir-0 -n observability-lab

# Check logs
kubectl logs mimir-0 -n observability-lab

# Common issues:
# - PVC binding (requires storageClass)
# - Resource limits (increase memory/CPU)
```

### No Data in Grafana

```bash
# Verify Mimir endpoint
kubectl exec -it -n observability-lab deploy/grafana -- \
  curl http://mimir-nginx/prometheus/api/v1/query?query=up

# Check that remote_write works
kubectl logs -n observability-lab mimir-0 | grep "distributor"
```

### High Memory Usage

Increase memory limits or reduce retention:

```yaml
mimir:
  monolithic:
    resources:
      limits:
        memory: "4Gi"
  mimir:
    structuredConfig:
      limits:
        compactor_blocks_retention_period: 7d  # Kortare retention
```

## Comparison with Prometheus

| Feature | Prometheus | Mimir |
|---------|-----------|-------|
| **Deployment** | Single binary | Monolithic or microservices |
| **Storage** | Local TSDB | S3/GCS/Azure/Filesystem |
| **Retention** | ~15 days (typical) | Months/years |
| **HA** | Complex | Built-in |
| **Scalability** | Limited | Horizontal |
| **PromQL** | ✅ | ✅ (compatible) |
| **Remote Write** | ✅ | ✅ |

## Next Steps

1. **OpenTelemetry**: Configure OTel Collector to send metrics to Mimir
2. **Multi-tenancy**: Use `X-Scope-OrgId` headers for tenant isolation
3. **HA Setup**: Increase replicas to 3 with zoneAwareReplication
4. **Production Storage**: Migrate to S3/MinIO for persistence

## References

- [NGDATA Mimir Fork](https://github.com/NGDATA/mimir/blob/main/operations/helm/charts/mimir-distributed/monolithic.yaml)
- [Grafana Mimir Documentation](https://grafana.com/docs/mimir/latest/)
- [Mimir Helm Chart](https://github.com/grafana/mimir/tree/main/operations/helm/charts/mimir-distributed)
