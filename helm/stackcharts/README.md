# Observability Stack - Helm Umbrella Chart

This is the main Helm umbrella chart that bundles all observability components together.

## Chart Structure

```
stackcharts/
├── Chart.yaml          # Chart metadata and dependencies
├── values.yaml         # Default configuration values
├── charts/             # Downloaded dependency packages (.tgz files)
└── README.md           # This file
```

## Dependencies

This chart includes the following sub-charts (managed via `Chart.yaml`):

- **Grafana** - Visualization and dashboards
- **Loki** - Log aggregation system  
- **Tempo** - Distributed tracing backend
- **Prometheus** - Metrics collection and storage
- **OpenTelemetry Collector** - Telemetry data collection

## Managing Dependencies

### Update Dependencies

Download the latest versions specified in `Chart.yaml`:

```bash
cd helm/stackcharts
helm dependency update
```

This will:
1. Read dependency specifications from `Chart.yaml`
2. Download `.tgz` packages to `charts/` directory
3. Update `Chart.lock` with exact versions

### List Current Dependencies

```bash
helm dependency list
```

### charts/ Directory

The `charts/` directory contains **only** `.tgz` files - the packaged Helm charts for each dependency. These files are:
- Automatically downloaded by `helm dependency update`
- Committed to version control for reproducibility
- **Should not contain any other files** (no README.md, documentation, etc.)

⚠️ **Important:** Do not add any files to `charts/` directory manually. Helm treats anything in that directory as a chart package.

## Installation

This chart is deployed via ArgoCD, not directly with Helm. The installation script handles dependency updates:

```bash
./scripts/install_argo.sh
```

### Manual Installation (Not Recommended)

If you need to install manually:

```bash
# Update dependencies first
cd helm/stackcharts
helm dependency update

# Install
helm install observability-stack . -n observability-lab --create-namespace
```

## Configuration

All configuration is done in `values.yaml`. See that file for detailed options.

Key sections:
- `grafana:` - Grafana configuration
- `loki:` - Loki configuration  
- `tempo:` - Tempo configuration
- `prometheus:` - Prometheus configuration
- `opentelemetry-collector:` - OTel Collector configuration
- `minio:` - Minio configuration (disabled by default)

## Storage

By default, all components use local filesystem storage via PersistentVolumeClaims.

For S3/Minio configuration (deprecated), see `docs/deprecated/MINIO_SETUP.md`.

## Troubleshooting

### Dependency Issues

If you see errors about missing charts:

```bash
cd helm/stackcharts
helm dependency update
```

### Chart Version Conflicts

Check `Chart.lock` for the exact versions being used:

```bash
cat Chart.lock
```

To update to newer versions, modify `Chart.yaml` and run `helm dependency update`.

## Version Control

All dependency `.tgz` files in `charts/` are committed to the repository. This ensures:
- Reproducible deployments
- No runtime dependency on external Helm repositories  
- Faster installation (no downloads needed)

When updating dependencies, commit both:
- `Chart.lock` (updated versions)
- `charts/*.tgz` (new packages)
