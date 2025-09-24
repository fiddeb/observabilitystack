# Architecture Guide

This document explains the **design decisions**, **architectural patterns**, and **configuration philosophy** behind the ObservabilityStack.

> **Goal**: Help you understand **why** the stack is structured the way it is, and **how** to customize it for your needs.

## Table of Contents

- [Design Philosophy](#design-philosophy)
- [Architecture Overview](#architecture-overview)
- [Helm Umbrella Chart Pattern](#helm-umbrella-chart-pattern)
- [Single values.yaml Strategy](#single-valuesyaml-strategy)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Multi-Tenant Architecture](#multi-tenant-architecture)
- [Configuration Patterns](#configuration-patterns)
- [Customization Guide](#customization-guide)

## Stack Configuration

### Configuration Structure
- **Single values.yaml** - All component configurations in one file
- **Umbrella chart pattern** - All components managed as subcharts
- **GitOps deployment** - Changes managed through Git commits
- **Local filesystem storage** - No external storage dependencies

## Architecture Overview

```
┌──────────────────────────────────────────────────────────────┐
│                    ObservabilityStack                        │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐    │
│  │   ArgoCD     │    │  Traefik     │    │   Storage    │    │
│  │  (GitOps)    │    │  (Ingress)   │    │(Filesystem)  │    │
│  └──────────────┘    └──────────────┘    └──────────────┘    │
│                                                              │
│  ┌───────────────────────────────────────────────────────────┤
│  │              Observability Components                     │
│  ├───────────────────────────────────────────────────────────┤
│  │                                                           │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐    │
│  │  │   Loki   │  │  Tempo   │  │Prometheus│  │ Grafana │    │
│  │  │ (Logs)   │  │(Traces)  │  │(Metrics) │  │  (UI)   │    │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────┘    │
│  │                                                           │
│  │  ┌─────────────────────────────────────────────────────┐  │
│  │  │        OpenTelemetry Collector                      │  │
│  │  │         (Telemetry Pipeline)                        │  │
│  │  └─────────────────────────────────────────────────────┘  │
│  └───────────────────────────────────────────────────────────┤
└──────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Role | Function |
|-----------|------|----------|
| **ArgoCD** | GitOps Controller | Manages deployments from Git repository |
| **Traefik** | Ingress Controller | Routes external traffic to services |
| **Loki** | Log Aggregation | Stores and queries log data |
| **Tempo** | Trace Storage | Stores and queries distributed traces |
| **Prometheus** | Metrics Collection | Collects and stores time-series metrics |
| **Grafana** | Visualization | Provides dashboards for logs, metrics, and traces |
| **OTEL Collector** | Telemetry Pipeline | Receives, processes, and routes telemetry data |

## Helm Umbrella Chart Pattern

### Umbrella Chart Structure

The `helm/stackcharts/` directory contains an **umbrella chart** that packages all components together:

```
helm/stackcharts/
├── Chart.yaml           # Umbrella chart definition
├── Chart.lock          # Dependency lock file  
├── values.yaml         # Single configuration file
└── charts/             # Downloaded dependencies
    ├── grafana-9.3.2.tgz
    ├── loki-6.36.0.tgz
    ├── prometheus-27.30.0.tgz
    └── ...
```

#### How the Umbrella Pattern Works

**Single Deployment Command**
```bash
# Deploy entire stack with one command
helm install observability-stack ./helm/stackcharts -n observability-lab
```

**Version Management**
- `Chart.yaml` defines specific versions for all components
- `Chart.lock` locks exact versions for reproducible deployments
- `helm dependency update` downloads and packages all components

**Dependency Definition**
```yaml
# Chart.yaml automatically handles component relationships
dependencies:
  - name: grafana
    version: "9.3.2"
    repository: "https://grafana.github.io/helm-charts"
  - name: loki
    version: "6.36.0" 
    repository: "https://grafana.github.io/helm-charts"
```

### Understanding Subcharts

Each dependency becomes a **subchart** within the umbrella chart:

```
helm/stackcharts/
├── Chart.yaml              # Parent chart definition
├── values.yaml            # Values for parent + ALL subcharts
├── Chart.lock             # Locked subchart versions
└── charts/                # Downloaded subcharts
    ├── grafana-9.3.2.tgz     # Subchart: Grafana
    ├── loki-6.36.0.tgz       # Subchart: Loki  
    ├── prometheus-27.30.0.tgz # Subchart: Prometheus
    └── ...
```

#### **How Subcharts Work**

**Value Inheritance**
```yaml
# values.yaml structure maps to subcharts
grafana:                    # ← Passed to grafana subchart
  adminPassword: secretpwd
  datasources: [...]
  
loki:                      # ← Passed to loki subchart  
  enabled: true
  singleBinary:
    replicas: 1
    
prometheus:                # ← Passed to prometheus subchart
  server:
    persistentVolume:
      size: 8Gi
```

**Subchart Templates**
Each subchart has its own templates that get rendered:
```
grafana subchart templates → grafana-deployment.yaml, grafana-service.yaml
loki subchart templates    → loki-statefulset.yaml, loki-configmap.yaml  
prometheus subchart templates → prometheus-deployment.yaml, etc.
```

**Dependency Management**
```bash
# Download/update all subcharts
helm dependency update helm/stackcharts/

# This downloads:
# - grafana-9.3.2.tgz from https://grafana.github.io/helm-charts  
# - loki-6.36.0.tgz from https://grafana.github.io/helm-charts
# - etc.
```

#### **Subchart Configuration Patterns**

**Global Values**
```yaml
# Shared across all subcharts
global:
  storageClass: "local-path"
  imagePullSecrets: []
  
# Each subchart can access global values
grafana:
  # Uses global.storageClass automatically
  persistence:
    enabled: true
    
loki:  
  # Also uses global.storageClass
  persistence:
    enabled: true
```

**Conditional Subcharts**
The `condition` field in `Chart.yaml` determines which subcharts are installed:

```yaml
# Chart.yaml - Defines the conditions
dependencies:
  - name: loki
    version: "6.36.0" 
    repository: "https://grafana.github.io/helm-charts"
    condition: loki.enabled        # ← Controls if this subchart installs
  
  - name: grafana
    version: "9.3.2"
    repository: "https://grafana.github.io/helm-charts" 
    condition: grafana.enabled     # ← Controls if this subchart installs
```

```yaml
# values.yaml - Sets the condition values
loki:
  enabled: true    # ← This value is checked by "condition: loki.enabled"
  # ... rest of loki configuration

grafana:
  enabled: true    # ← This value is checked by "condition: grafana.enabled"  
  # ... rest of grafana configuration

tempo:
  enabled: false   # ← Setting to false will skip tempo installation
```

**How It Works:**
- Helm checks `values.yaml` for the condition path (e.g., `loki.enabled`)
- If `true`, the subchart is included in deployment
- If `false` or missing, the subchart is skipped entirely
- This allows selective component installation from the same umbrella chart

**Practical Examples:**
```bash
# Deploy only logs and visualization (no metrics or tracing)
# In values.yaml:
loki:
  enabled: true
grafana: 
  enabled: true
prometheus:
  enabled: false   # Skip metrics collection
tempo:
  enabled: false   # Skip tracing
opentelemetry-collector:
  enabled: true    # Keep collector for log processing
```

**Cross-Subchart References**
```yaml
# Grafana subchart references other subcharts
grafana:
  datasources:
    datasources.yaml:
      datasources:
      - name: Prometheus
        # Reference to prometheus subchart service
        url: http://{{ include "prometheus.fullname" . }}:{{ .Values.prometheus.server.service.port }}
      - name: Loki  
        # Reference to loki subchart service
        url: http://{{ include "loki.serviceName" . }}:{{ .Values.loki.service.port }}
```


#### Declarative Infrastructure
```yaml
# argocd/observability-stack.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: observability-stack
spec:
  source:
    path: helm/stackcharts        # Points to umbrella chart
    targetRevision: main          # Tracks main branch
```

**Change Workflow**
1. Edit `values.yaml` 
2. Commit to Git
3. Sync ArgoCD or use scripts/force_argo_sync.sh
4. See changes in ArgoCD UI

#### **Adding New Components**

To add a new component (e.g., Jaeger for tracing):

```yaml
# 1. Add to Chart.yaml dependencies
dependencies:
  - name: jaeger
    version: "0.71.2"
    repository: https://jaegertracing.github.io/helm-charts

# 2. Add configuration to values.yaml
jaeger:
  enabled: true
  # ... jaeger configuration

# 3. Update dependencies  
helm dependency update helm/stackcharts/

# 4. Commit changes
git add . && git commit -m "feat: add Jaeger tracing"
```

---

## Next Steps

After understanding this architecture:

1. ** Read**: [Installation Guide](INSTALLATION.md) for setup
2. ** Practice**: [Usage Guide](USAGE_GUIDE.md) for hands-on experience  
3. ** Customize**: Edit `values.yaml` for your specific needs
4. ** Monitor**: Use [Troubleshooting Guide](QUICK_TROUBLESHOOTING.md) when issues arise
