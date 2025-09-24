# Architecture Guide

This document explains the **design decisions**, **architectural patterns**, and **configuration philosophy** behind the ObservabilityStack.

> 🎯 **Goal**: Help you understand **why** the stack is structured the way it is, and **how** to customize it for your needs.

## Table of Contents

- [Design Philosophy](#design-philosophy)
- [Architecture Overview](#architecture-overview)
- [Helm Umbrella Chart Pattern](#helm-umbrella-chart-pattern)
- [Single values.yaml Strategy](#single-valuesyaml-strategy)
- [GitOps with ArgoCD](#gitops-with-argocd)
- [Multi-Tenant Architecture](#multi-tenant-architecture)
- [Configuration Patterns](#configuration-patterns)
- [Customization Guide](#customization-guide)

## Design Philosophy

### 🎓 **Learning-First Design**
The ObservabilityStack prioritizes **learning and understanding** over production complexity:

- **Single source of truth** - One `values.yaml` file instead of scattered configurations
- **Transparent configuration** - All settings visible and documented in one place
- **Minimal abstractions** - Direct Helm chart usage without custom operators
- **GitOps workflow** - Industry-standard deployment pattern you'll use in real projects

### 🔧 **Development Environment Optimized**
Designed for **local development** and **proof-of-concepts**:

- **Resource efficient** - Optimized for laptop/desktop environments
- **Fast iteration** - Quick configuration changes and deployments
- **Local storage** - No external dependencies like S3 or cloud databases
- **Easy reset** - Simple to tear down and rebuild

### 🏗️ **Production Patterns**
Despite being for learning, it follows **production-ready patterns**:

- **Helm charts** - Industry standard for Kubernetes packaging
- **GitOps** - Declarative configuration management
- **Namespace isolation** - Proper resource separation
- **Ingress configuration** - Real-world networking setup

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                    ObservabilityStack                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐   │
│  │   ArgoCD     │    │  Traefik     │    │   Storage    │   │
│  │  (GitOps)    │    │  (Ingress)   │    │(Filesystem)  │   │
│  └──────────────┘    └──────────────┘    └──────────────┘   │
│                                                             │
│  ┌─────────────────────────────────────────────────────────┤
│  │              Observability Components                   │
│  ├─────────────────────────────────────────────────────────┤
│  │                                                         │
│  │  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌─────────┐  │
│  │  │   Loki   │  │  Tempo   │  │Prometheus│  │ Grafana │  │
│  │  │ (Logs)   │  │(Traces)  │  │(Metrics) │  │  (UI)   │  │
│  │  └──────────┘  └──────────┘  └──────────┘  └─────────┘  │
│  │                                                         │
│  │  ┌─────────────────────────────────────────────────────┐  │
│  │  │        OpenTelemetry Collector                      │  │
│  │  │         (Telemetry Pipeline)                        │  │
│  │  └─────────────────────────────────────────────────────┘  │
│  └─────────────────────────────────────────────────────────┘
└─────────────────────────────────────────────────────────────┘
```

### Component Responsibilities

| Component | Role | Why This Choice |
|-----------|------|----------------|
| **ArgoCD** | GitOps Controller | Industry standard, declarative deployments |
| **Traefik** | Ingress Controller | Simple, automatic service discovery |
| **Loki** | Log Aggregation | Lightweight, Prometheus-like queries |
| **Tempo** | Trace Storage | Cost-effective, integrates well with Grafana |
| **Prometheus** | Metrics Collection | De facto standard for Kubernetes metrics |
| **Grafana** | Visualization | Unified view of logs, metrics, and traces |
| **OTEL Collector** | Telemetry Pipeline | Vendor-neutral, future-proof data routing |

## Helm Umbrella Chart Pattern

### Why Umbrella Charts?

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

#### ✅ **Benefits of Umbrella Pattern**

**Single Deployment Unit**
```bash
# Deploy entire stack with one command
helm install observability-stack ./helm/stackcharts -n observability-lab
```

**Version Consistency**
- All components deployed with compatible versions
- `Chart.lock` ensures reproducible deployments
- Easy to upgrade entire stack atomically

**Simplified Dependencies**
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

#### 🔄 **Alternative: Individual Charts**

You *could* install each component separately:
```bash
# More complex, harder to manage
helm install grafana grafana/grafana -f grafana-values.yaml
helm install loki grafana/loki -f loki-values.yaml
helm install prometheus prometheus-community/prometheus -f prometheus-values.yaml
# ... repeat for each component
```

**Why we chose umbrella approach:**
- ✅ Single configuration file
- ✅ Atomic deployments/rollbacks
- ✅ Easier version management
- ✅ Better for learning (less complexity)

## Single values.yaml Strategy

### The Monolithic Configuration Approach

All component configurations live in **one file**: `helm/stackcharts/values.yaml`

```yaml
# helm/stackcharts/values.yaml
loki:
  enabled: true
  # ... loki configuration

grafana:  
  # ... grafana configuration

prometheus:
  # ... prometheus configuration

opentelemetry-collector:
  # ... otel configuration
```

### Why Single File vs Multiple Files?

#### ✅ **Benefits of Single values.yaml**

**Learning & Understanding**
- See all configurations in one place
- Understand component relationships
- Easy to search and modify

**Configuration Consistency**  
- Cross-component settings (like tenant names) defined once
- Shared values can be referenced between components
- Reduces configuration drift

**GitOps Friendly**
- Single file to track in Git
- Clear diff when making changes  
- Atomic configuration updates

**Debugging Simplified**
- All settings visible during troubleshooting
- No need to hunt across multiple files
- Easy to share complete configuration

#### ⚠️ **Trade-offs**

**File Size**
- Can become large (1000+ lines)
- Solution: Good documentation and sections

**Merge Conflicts**
- Multiple people editing same file
- Solution: Feature branches and proper Git workflow

**Component Coupling**
- Changes to one component in same file as others
- Solution: Clear section boundaries and comments

### Alternative Approaches & Why We Didn't Choose Them

#### 📁 **Split Configuration Pattern**
```
values/
├── grafana.yaml
├── loki.yaml  
├── prometheus.yaml
└── otel.yaml
```

**Pros:** Smaller files, less merge conflicts  
**Cons:** Harder to see cross-component configuration, more complex templating

#### 🎛️ **ConfigMap Pattern**
```
configmaps/
├── grafana-config.yaml
├── loki-config.yaml
└── ...
```

**Pros:** Native Kubernetes resources  
**Cons:** Loses Helm templating benefits, harder to manage

#### 🔧 **Custom Operator Pattern**
```yaml
apiVersion: observability.io/v1
kind: ObservabilityStack
spec:
  components: [grafana, loki, prometheus]
```

**Pros:** Kubernetes-native, sophisticated lifecycle management  
**Cons:** Additional complexity, custom code to maintain, harder to understand

## GitOps with ArgoCD

### Why GitOps + Umbrella Chart?

```
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│    Git      │───▶│   ArgoCD    │───▶│ Kubernetes  │
│ (Source)    │    │(Controller) │    │ (Target)    │
└─────────────┘    └─────────────┘    └─────────────┘
     │                     │                 │
     ▼                     ▼                 ▼
┌─────────────┐    ┌─────────────┐    ┌─────────────┐
│values.yaml  │    │Helm Release │    │  Running    │
│Chart.yaml   │    │Sync Status  │    │   Pods      │  
│Chart.lock   │    │Health Check │    │ Services    │
└─────────────┘    └─────────────┘    └─────────────┘
```

#### Benefits for Learning

**Declarative Infrastructure**
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
3. ArgoCD automatically syncs
4. See changes in ArgoCD UI

**Rollback Safety**
```bash
# Easy rollback via Git
git revert <commit-hash>
git push
# ArgoCD automatically rolls back
```

## Multi-Tenant Architecture  

### Tenant Isolation Strategy

The stack implements **soft multi-tenancy** for learning purposes:

```yaml
# OpenTelemetry Collector routing
processors:
  routing:
    from_attribute: dev.audit.category
    table:
      - statement: route() where attributes["dev.audit.category"] != nil
        pipelines: [logs/audit]  # Routes to 'bazz' tenant
```

#### Data Flow by Tenant

```
Application Logs
      │
      ▼
┌─────────────┐
│ OTEL        │
│ Collector   │  ◄─── Intelligent routing based on attributes
└─────────────┘
      │
      ├─── logs with dev.audit.category ──▶ Loki 'bazz' tenant
      │
      └─── all other logs ──▶ Loki 'foo' tenant
                             
┌─────────────┐              ┌─────────────┐
│ Grafana     │◄─────────────┤ Separate    │
│ Datasources │              │ Loki        │
│             │              │ Tenants     │
│ • loki-foo  │              │             │
│ • loki-bazz │              │ • X-Scope-  │
└─────────────┘              │   OrgID:foo │
                             │ • X-Scope-  │
                             │   OrgID:bazz│
                             └─────────────┘
```

### Why This Multi-Tenant Approach?

**Learning Value**
- Understand tenant isolation concepts
- See how headers control data routing  
- Practice with realistic data separation

**Practical Implementation**
- Uses standard Loki multi-tenancy features
- No custom authentication needed
- Easy to add more tenants

**Real-World Preparation**
- Same patterns used in production
- Prepares for proper RBAC implementation
- Understanding of data isolation challenges

## Configuration Patterns

### Common Customization Scenarios

#### 1. **Resource Adjustment**
```yaml
loki:
  singleBinary:
    resources:
      limits:
        cpu: 1000m      # Increase for better performance  
        memory: 2Gi     # Increase for larger datasets
      requests:
        cpu: 500m       # Minimum guaranteed resources
        memory: 1Gi
```

#### 2. **Storage Configuration**  
```yaml
loki:
  loki:
    storage:
      type: 'filesystem'                    # For local development
      # type: 's3'                         # For production
      filesystem:
        chunks_directory: /var/loki/chunks  
        rules_directory: /var/loki/rules
```

#### 3. **Ingress Customization**
```yaml  
grafana:
  ingress:
    enabled: true
    hosts: ['grafana.yourdomain.com']      # Change domain
    annotations:
      cert-manager.io/cluster-issuer: letsencrypt  # Add TLS
```

#### 4. **Adding New Tenants**
```yaml
# 1. Add OTEL routing rule
opentelemetry-collector:
  config:
    processors:
      routing:
        table:
          - statement: route() where attributes["my.tenant.id"] == "newtenant"
            pipelines: [logs/newtenant]

# 2. Add exporter  
    exporters:
      otlphttp/newtenant:
        logs_endpoint: http://loki-gateway.../otlp/v1/logs
        headers:
          "X-Scope-OrgID": newtenant

# 3. Add Grafana datasource
grafana:
  datasources:
    datasources.yaml:
      datasources:
      - name: loki-newtenant
        type: loki  
        url: http://loki-gateway
        jsonData:
          httpHeaderName1: "X-Scope-OrgID"
        secureJsonData:
          httpHeaderValue1: "newtenant"
```

### Configuration Best Practices

#### **Resource Planning**
```yaml
# Development (laptop)
resources:
  requests: { cpu: 100m, memory: 256Mi }
  limits:   { cpu: 500m, memory: 1Gi }

# Staging (small cluster)  
resources:
  requests: { cpu: 500m, memory: 1Gi }
  limits:   { cpu: 2, memory: 4Gi }

# Production (dedicated nodes)
resources:  
  requests: { cpu: 2, memory: 4Gi }
  limits:   { cpu: 4, memory: 8Gi }
```

#### **Environment-Specific Overrides**
```yaml
# Base configuration in values.yaml
loki:
  enabled: true
  
# Override for production (via ArgoCD or Helm)
# values-prod.yaml
loki:
  singleBinary:
    replicas: 3
  storage:
    type: s3
```

## Customization Guide

### Getting Started with Changes

#### 1. **Local Development Workflow**
```bash
# 1. Create feature branch
git checkout -b feat/customize-grafana

# 2. Edit configuration
vim helm/stackcharts/values.yaml

# 3. Test changes
./scripts/force_argo_sync.sh

# 4. Commit and merge
git add . && git commit -m "feat: customize Grafana dashboards"
./scripts/merge_feature.sh feat/customize-grafana
```

#### 2. **Understanding Component Dependencies**

**Startup Order** (handled automatically by Kubernetes):
1. Storage (PVCs)
2. Loki, Tempo, Prometheus (data stores)  
3. OpenTelemetry Collector (depends on endpoints)
4. Grafana (depends on datasources)

**Network Dependencies**:
```yaml  
# Grafana needs to reach these services
grafana:
  datasources:
    - name: prometheus
      url: http://prometheus.observability-lab.svc.cluster.local
    - name: loki  
      url: http://loki-gateway.observability-lab.svc.cluster.local
    - name: tempo
      url: http://tempo.observability-lab.svc.cluster.local:3200
```

#### 3. **Adding New Components**

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

### Advanced Customizations

#### **Custom Dashboards**
```yaml
grafana:
  dashboardProviders:
    dashboardproviders.yaml:
      providers:
      - name: 'custom'
        type: file
        folder: '/var/lib/grafana/dashboards/custom'
        
  dashboards:
    custom:
      my-dashboard:
        gnetId: 12345  # Grafana.com dashboard ID
        datasource: Prometheus
```

#### **Custom OTEL Processing**
```yaml
opentelemetry-collector:
  config:
    processors:
      attributes:
        actions:
        - action: insert
          key: environment  
          value: development
        - action: update
          key: service.name
          from_attribute: k8s.deployment.name
```

#### **External Integrations**
```yaml
# Send metrics to external Prometheus
opentelemetry-collector:
  config:
    exporters:
      prometheusremotewrite/external:
        endpoint: https://prometheus.external.com/api/v1/write
        headers:
          Authorization: "Bearer ${EXTERNAL_TOKEN}"
```

## Troubleshooting Architecture Issues

### Common Problems & Solutions

#### **"Single values.yaml is too large"**
**Symptoms**: Difficult to navigate, merge conflicts  
**Solutions**:
- Use YAML anchors for repeated configs
- Split into logical sections with clear comments
- Consider splitting only if team >5 people

#### **"Resource conflicts between components"**  
**Symptoms**: Pods pending, OOM kills  
**Solutions**:
```yaml
# Add resource quotas per component
loki:
  resources:
    requests: {cpu: 200m, memory: 512Mi}
    limits:   {cpu: 500m, memory: 1Gi}
    
grafana:  
  resources:
    requests: {cpu: 100m, memory: 128Mi}
    limits:   {cpu: 200m, memory: 256Mi}
```

#### **"Configuration drift between environments"**
**Symptoms**: Different behavior in dev vs prod  
**Solutions**:
- Use ArgoCD ApplicationSets for multi-env
- Environment-specific value overrides
- Automated configuration validation

### Monitoring the Architecture

#### **Key Health Indicators**
```bash  
# Component health
kubectl get pods -n observability-lab

# ArgoCD sync status  
kubectl get applications -n argocd

# Resource usage
kubectl top pods -n observability-lab
```

#### **Configuration Validation**
```bash
# Validate Helm chart
helm lint helm/stackcharts/

# Dry-run deployment  
helm template observability-stack helm/stackcharts/ --debug

# Check ArgoCD health
kubectl get application observability-stack -n argocd -o yaml
```

---

## Next Steps

After understanding this architecture:

1. **📖 Read**: [Installation Guide](INSTALLATION.md) for setup
2. **🚀 Practice**: [Usage Guide](USAGE_GUIDE.md) for hands-on experience  
3. **🔧 Customize**: Edit `values.yaml` for your specific needs
4. **🔍 Monitor**: Use [Troubleshooting Guide](QUICK_TROUBLESHOOTING.md) when issues arise

**Questions or improvements?** The architecture is designed to evolve with your learning!