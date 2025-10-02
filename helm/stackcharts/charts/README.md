# Helm Chart Dependencies

This directory contains the downloaded Helm chart dependencies for the observability stack.

## Contents

These chart packages are automatically downloaded when you run:

```bash
helm dependency update
```

## Current Dependencies

Based on `../Chart.yaml`:

- **Grafana** (`grafana-10.0.0.tgz`) - Visualization and dashboards
- **Loki** (`loki-6.36.0.tgz`) - Log aggregation system
- **Tempo** (`tempo-1.23.3.tgz`) - Distributed tracing backend
- **Prometheus** (`prometheus-27.30.0.tgz`) - Metrics collection and storage
- **OpenTelemetry Collector** (`opentelemetry-collector-0.122.2.tgz`) - Telemetry data collection
- **Minio** (`minio-17.0.21.tgz`) - S3-compatible storage (disabled by default)

## Updating Dependencies

To update all dependencies to their latest versions specified in `Chart.yaml`:

```bash
cd helm/stackcharts
helm dependency update
```

This will:
1. Read `Chart.yaml` for dependency specifications
2. Download `.tgz` packages from specified Helm repositories
3. Update `Chart.lock` with exact versions

## Version Control

These `.tgz` files **are committed to the repository** to ensure:
- Reproducible builds
- No runtime dependency on external Helm repositories
- Faster installation (no download required)

## Do Not Manually Edit

The contents of this directory are managed by Helm. Do not manually:
- Add or remove `.tgz` files
- Modify existing packages
- Change Chart.lock

Instead, modify `../Chart.yaml` and run `helm dependency update`.
