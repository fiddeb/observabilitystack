# Changelog

All notable changes to ObservabilityStack will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.1.0] - 2025-10-03

### Added
- Initial working release of ObservabilityStack
- GitOps deployment with ArgoCD
- Helm umbrella chart pattern with multi-values configuration
- OpenTelemetry Collector for telemetry pipeline
- Grafana for visualization with pre-configured datasources
- Loki for log aggregation with multi-tenant support (foo, bazz)
- Tempo for distributed tracing with local filesystem storage
- Prometheus for metrics collection
- Traefik ingress controller integration
- Documentation:
  - Installation guide (macOS, Linux, Windows)
  - Architecture guide with Mermaid diagram
  - Usage guide with smoke tests
  - Troubleshooting guide with command reference
  - Git workflow guide
- DNS setup guides for wildcard routing (dnsmasq for macOS/Linux)
- Installation scripts:
  - `install_argo.sh` - Complete stack deployment
  - `force_argo_sync.sh` - Manual ArgoCD sync
  - `setup_argocd.sh` - Fork-friendly ArgoCD setup

### Fixed
- Helm dependency update in installation script
- Mermaid diagram rendering in documentation
- ArgoCD Application manifest with multi-values support

### Documentation
- Installation instructions for macOS, Linux, and Windows
- Architecture overview with component responsibilities
- Troubleshooting guide with verified commands
- Usage examples with smoke tests
- Git workflow and branching strategy

### Known Limitations
- Not production-ready (designed for labs and learning)
- Uses local filesystem storage (no S3/object storage)
- Basic authentication and security
- Windows support limited to static hosts file (no wildcard DNS)
- Tempo search API not enabled by default

## Release Notes

This is the first tagged release of ObservabilityStack. The stack is fully functional for local development, learning, and lab environments.

### What's Working
✅ Complete observability stack deployment via GitOps  
✅ Multi-tenant log aggregation  
✅ Integrated telemetry pipeline (logs, metrics, traces)  
✅ Pre-configured backends in Grafana  
✅ DNS-based routing with Traefik  
✅ Documentation  


[Unreleased]: https://github.com/fiddeb/observabilitystack/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/fiddeb/observabilitystack/releases/tag/v0.1.0
