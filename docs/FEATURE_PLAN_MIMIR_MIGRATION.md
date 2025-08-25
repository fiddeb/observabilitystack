# Feature Planning: Migrate Prometheus to Mimir Monolithic Mode

## Overview

This document outlines the plan to replace the current Prometheus metrics collection system with Grafana Mimir in monolithic mode. Mimir provides enhanced scalability, long-term storage capabilities, and improved query performance while maintaining full Prometheus API compatibility.

## Current State Analysis

### Existing Prometheus Configuration
- **Deployment**: Prometheus server via Helm chart in stackcharts/values.yaml
- **Storage**: Local storage within Kubernetes cluster
- **Access**: Available at http://prometheus.k8s.test via ingress
- **Integration**: Connected to Grafana as datasource, receives metrics from OpenTelemetry Collector
- **Retention**: Limited by local storage capacity

### Limitations of Current Setup
- No long-term storage beyond local disk capacity
- Single point of failure (not highly available)
- Limited scalability for high ingestion rates
- No multi-tenancy support
- Storage tied to pod lifecycle

## Target State: Mimir Monolithic Mode

### Benefits of Mimir Migration
- **Long-term storage**: Utilizes existing S3 (Minio) backend for persistence
- **Better scalability**: Single binary deployment with improved performance
- **Enhanced queries**: More efficient query engine with better caching
- **API compatibility**: Drop-in replacement for Prometheus API
- **Multi-tenancy**: Support for tenant isolation (future capability)
- **Durability**: Data persisted in object storage

### Mimir Monolithic Architecture
- Single binary containing all Mimir components
- Uses S3 (Minio) for blocks storage
- Maintains Prometheus scrape configuration compatibility
- Provides same HTTP endpoints as Prometheus

## Implementation Plan

### Phase 1: Configuration Design

#### 1.1 Mimir Values Configuration
Based on the monolithic.yaml example, create mimir section in stackcharts/values.yaml:

```yaml
mimir:
  enabled: true
  deploymentMode: monolithic
  fullnameOverride: mimir
  
  mimir:
    structuredConfig:
      limits:
        compactor_blocks_retention_period: 30d  # Adjust for lab environment
      common:
        storage:
          backend: s3
          s3:
            endpoint: minio:9000
            region: notset
            insecure: true
            access_key_id: minio
            secret_access_key: minio123
      blocks_storage:
        storage_prefix: blocks
        s3:
          bucket_name: mimir-blocks
      
  monolithic:
    replicas: 1  # Single replica for lab environment
    persistentVolume:
      enabled: true
      size: "8Gi"
      storageClass: "default"
```

#### 1.2 Storage Integration
- **Bucket**: Create mimir-blocks bucket in Minio
- **Credentials**: Reuse existing Minio credentials via secrets
- **Persistence**: Local volume for WAL and cache data

#### 1.3 Service Configuration
- **Service name**: mimir (to replace prometheus service references)
- **Port**: 8080 (Mimir default HTTP port)
- **Ingress**: http://mimir.k8s.test or maintain prometheus.k8s.test

### Phase 2: Integration Points

#### 2.1 Grafana Datasource Update
Current Prometheus datasource configuration needs updating:
```yaml
# From:
- name: Prometheus
  type: prometheus
  url: http://prometheus:80

# To:
- name: Mimir
  type: prometheus  # Mimir is Prometheus API compatible
  url: http://mimir:8080
```

#### 2.2 OpenTelemetry Collector Configuration
Update OTEL Collector exporters configuration:
```yaml
# From:
exporters:
  prometheus:
    endpoint: "http://prometheus.observability-lab.svc.cluster.local:80"

# To:
exporters:
  prometheusremotewrite:
    endpoint: "http://mimir.observability-lab.svc.cluster.local:8080/api/v1/push"
```

#### 2.3 Remote Write Endpoints
- **Tempo**: Update metricsGenerator.remoteWriteUrl from prometheus to mimir
- **Any external Prometheus**: Configure remote write to Mimir

### Phase 3: Migration Strategy (Lab Environment)

#### 3.1 Direct Replacement Approach
Since this is a lab environment with no production data to protect:

1. **Direct replacement**: Replace Prometheus with Mimir in single deployment
2. **Fresh start**: No data migration needed - start with clean Mimir installation
3. **Immediate switch**: Update all configurations to point to Mimir directly
4. **Quick validation**: Basic functional testing to ensure ingestion and queries work

#### 3.2 Simplified Data Approach
- **No historical data preservation**: Accept loss of existing metrics (lab environment)
- **Fresh metrics collection**: Start collecting new metrics in Mimir immediately
- **Simplified testing**: Focus on functional validation rather than data continuity

### Phase 4: Configuration Files

#### 4.1 Files to Modify
- `helm/stackcharts/values.yaml`: Add Mimir configuration, disable Prometheus
- `helm/stackcharts/Chart.yaml`: Add Mimir Helm chart dependency
- Documentation updates for new endpoints and features

#### 4.2 New Dependencies
**Interim Strategy**: Use NGDATA fork until monolithic mode is merged upstream

Option A - Use NGDATA fork (recommended for now):
```yaml
dependencies:
  - name: mimir-distributed
    version: "main"  # Or specific fork version
    repository: https://github.com/NGDATA/mimir/tree/main/operations/helm/charts/mimir-distributed
    condition: mimir.enabled
```

Option B - Future official chart (when monolithic mode is merged):
```yaml
dependencies:
  - name: mimir-distributed
    version: "~5.8.0+"  # Future version with monolithic support
    repository: https://grafana.github.io/helm-charts
    condition: mimir.enabled
```

**Migration Strategy**: Start with NGDATA fork, then migrate to official chart when feature is available upstream.

### Phase 5: Testing and Validation

#### 5.1 Functional Tests
- Verify metrics ingestion from OpenTelemetry Collector
- Test Grafana dashboard functionality with new datasource
- Validate query performance and API compatibility
- Test S3 storage integration and persistence

#### 5.2 Performance Tests
- Compare query response times between Prometheus and Mimir
- Validate ingestion rates and resource utilization
- Test data persistence across pod restarts

## Success Criteria

### Functional Requirements
- Mimir successfully ingests metrics from OpenTelemetry Collector
- Data persists across pod restarts via S3 storage

### Performance Requirements
- Basic functionality validation (queries return data)
- S3 storage integration working

### Operational Requirements
- Basic monitoring to ensure Mimir is functioning
- Documentation updated for new architecture


## Dependencies

### Internal
- Existing S3 (Minio) storage infrastructure
- OpenTelemetry Collector configuration
- Grafana datasource configuration

### External
- NGDATA Mimir fork availability and stability
- S3 bucket creation capability  
- Network connectivity between components
- Monitoring of upstream merge status for migration to official chart

## Next Steps

1. **Review and approve** this planning document
2. **Evaluate NGDATA fork stability** and monolithic mode implementation
3. **Create feature branch** for Mimir integration using NGDATA fork
4. **Implement Phase 1** configuration design with fork-specific settings
5. **Test in development** environment
6. **Monitor upstream progress** for official monolithic mode support
7. **Plan migration path** from fork to official chart when available
8. **Proceed with migration** following the defined phases

## References

- [Grafana Mimir Documentation](https://grafana.com/docs/mimir/)
- [Official Mimir Helm Chart](https://github.com/grafana/mimir/tree/main/operations/helm/charts/mimir-distributed)
- [NGDATA Mimir Fork with Monolithic Mode](https://github.com/NGDATA/mimir/tree/main/operations/helm/charts/mimir-distributed)
- [Monolithic Mode Configuration Example](https://github.com/NGDATA/mimir/blob/main/operations/helm/charts/mimir-distributed/monolithic.yaml)
- [Prometheus to Mimir Migration Guide](https://grafana.com/docs/mimir/latest/migration/migrate-from-prometheus/)
