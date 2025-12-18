# Mimir Integration - Monolithic Mode

## Overview

Mimir har lagts till i ObservabilityStack i **monolitiskt läge** baserat på NGDATA's fork av Grafana Mimir som har stöd för monolithic deployment.

- **Chart**: `mimir-distributed` v5.6.0 (från Grafana Helm repo)
- **Deployment Mode**: Monolithic (en pod kör alla komponenter)
- **Storage**: Lokalt filesystem (persistent volume)
- **Ingress**: `http://mimir.k8s.test`

## Aktivera Mimir

### 1. Uppdatera Chart Dependencies

```bash
cd helm/stackcharts
helm dependency update
cd ../..
```

### 2. Aktivera i base.yaml

Redigera `helm/stackcharts/values/base.yaml`:

```yaml
mimir:
  enabled: true
```

### 3. Deploy via ArgoCD

```bash
./scripts/force_argo_sync.sh
```

Eller manuellt:

```bash
argocd app sync observability-stack --force
```

## Verifiera Installation

```bash
# Kolla pods
kubectl get pods -n observability-lab | grep mimir

# Förväntat resultat:
# mimir-0                    1/1     Running   0          2m
# mimir-nginx-xxxxx          1/1     Running   0          2m

# Testa endpoints
curl http://mimir.k8s.test/ready
curl http://mimir.k8s.test/metrics
```

## Användning

### Skicka Metrics via Prometheus Remote Write

Konfigurera en Prometheus instance för att skicka metrics till Mimir:

```yaml
# prometheus-config.yaml
remote_write:
  - url: http://mimir-nginx/api/v1/push
```

### Query Metrics via Grafana

Mimir är redan konfigurerad som datasource i Grafana:
- **Namn**: Mimir
- **URL**: `http://mimir-nginx/prometheus`
- **Typ**: Prometheus (Mimir-compatible)

Besök `http://grafana.k8s.test` och välj "Mimir" som datasource i Explore.

### Query Metrics via API

```bash
# PromQL query
curl -G http://mimir.k8s.test/prometheus/api/v1/query \
  --data-urlencode 'query=up'

# Label values
curl http://mimir.k8s.test/prometheus/api/v1/label/__name__/values
```

## Konfiguration

### Viktiga Inställningar

Konfigurera i `helm/stackcharts/values/mimir.yaml`:

```yaml
mimir:
  monolithic:
    replicas: 1  # Öka för HA
    persistentVolume:
      size: "10Gi"  # Justera efter behov
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

**Standard**: Lokalt filesystem (`/data/mimir`)

För att byta till S3/MinIO:

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

### Aktivera AlertManager

```yaml
mimir:
  alertmanager:
    enabled: true
```

## Architecture

### Monolithic vs Microservices

**Monolithic Mode** (nuvarande setup):
- En enda pod kör alla komponenter (distributor, ingester, querier, etc.)
- Perfekt för utveckling och mindre produktionsmiljöer
- Enklare att sätta upp och felsöka

**Microservices Mode**:
- Varje komponent körs separat
- Bättre skalbarhet för stora produktionsmiljöer
- Kräver mer resurser och komplexitet

### Komponenter

I monolitiskt läge inkluderas:
- **Distributor**: Tar emot metrics från remote write
- **Ingester**: Skriver metrics till storage
- **Querier**: Hanterar PromQL queries
- **Compactor**: Komprimerar och behåller blocks
- **Store Gateway**: Läser från långtidslagring
- **Nginx**: Gateway/load balancer

## Troubleshooting

### Pod startar inte

```bash
# Kolla events
kubectl describe pod mimir-0 -n observability-lab

# Kolla logs
kubectl logs mimir-0 -n observability-lab

# Vanliga problem:
# - PVC binding (kräver storageClass)
# - Resource limits (öka minne/CPU)
```

### Ingen data i Grafana

```bash
# Verifiera Mimir endpoint
kubectl exec -it -n observability-lab deploy/grafana -- \
  curl http://mimir-nginx/prometheus/api/v1/query?query=up

# Kolla att remote_write fungerar
kubectl logs -n observability-lab mimir-0 | grep "distributor"
```

### High Memory Usage

Öka memory limits eller minska retention:

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

## Jämförelse med Prometheus

| Feature | Prometheus | Mimir |
|---------|-----------|-------|
| **Deployment** | Single binary | Monolithic eller microservices |
| **Storage** | Lokal TSDB | S3/GCS/Azure/Filesystem |
| **Retention** | ~15 dagar (typiskt) | Månader/år |
| **HA** | Svår | Inbyggd |
| **Skalbarhet** | Begränsad | Horisontell |
| **PromQL** | ✅ | ✅ (kompatibel) |
| **Remote Write** | ✅ | ✅ |

## Nästa Steg

1. **Integrera med OpenTelemetry**: Konfigurera OTel Collector att skicka metrics till Mimir
2. **Multi-tenancy**: Använd `X-Scope-OrgId` headers för tenant isolation
3. **HA Setup**: Öka replicas till 3 med zoneAwareReplication
4. **Production Storage**: Migrera till S3/MinIO för persistens

## Referenser

- [NGDATA Mimir Fork](https://github.com/NGDATA/mimir/blob/main/operations/helm/charts/mimir-distributed/monolithic.yaml)
- [Grafana Mimir Documentation](https://grafana.com/docs/mimir/latest/)
- [Mimir Helm Chart](https://github.com/grafana/mimir/tree/main/operations/helm/charts/mimir-distributed)
