## Project Overview

ObservabilityStack: GitOps observability lab using Helm umbrella chart + ArgoCD for OpenTelemetry, Grafana, Loki, Prometheus, Tempo.

**Architecture:**
- Umbrella chart (`helm/stackcharts`) with all components as dependencies
- Multi-file values: `values/base.yaml` (enables), `values/<component>.yaml` (config)
- GitOps: ArgoCD syncs from tag `v0.1.0` (stable) or `main` (dev)
- Shared scripts in `scripts/lib/common.sh`

---

## Key Patterns

### Helm Versioning
- Chart version ≠ app version (e.g., grafana chart 10.1.0 = app 12.2.0)
- Update `helm/stackcharts/Chart.yaml` then `helm dependency update`

### ArgoCD Multi-Values
Values files load in order from `argocd/observability-stack.yaml`. Order matters for overrides.

### Scripts
All scripts source `scripts/lib/common.sh` for `print_*`, `validate_*`, `wait_for_*` functions.

---

## Structure

- `helm/stackcharts/Chart.yaml` - Dependency versions
- `helm/stackcharts/values/<component>.yaml` - Component configs
- `helm/stackcharts/charts/` - Downloaded .tgz (managed by helm)
- `argocd/observability-stack.yaml` - ArgoCD app with targetRevision
- `scripts/lib/common.sh` - Shared functions
- `docs/ARCHITECTURE.md` - Design details

---

## Workflows

**Update chart version:**
```bash
helm search repo grafana/grafana  # Find versions
# Edit Chart.yaml with chart version
cd helm/stackcharts && helm dependency update
git add -u && git add charts/*.tgz
git commit -m "feat: update grafana to X.Y.Z"
```

**Sync config:** `./scripts/force_argo_sync.sh`

**Feature branches:** Use `./scripts/merge_feature.sh` (resets targetRevision before merge)

**Install:** `./scripts/install_argo.sh`

---

## Standards

**Shell:**
- `set -Eeuo pipefail`, source `lib/common.sh`
- Use `print_*` functions, validate with `validate_prerequisites`

**YAML:** 2-space indent, comment non-defaults, one component per file

**Git:** Semantic commits (`feat:`, `fix:`), `git add -u` for updates

**Safety:** Dry-run before apply, test multi-values before commit

---

## Platforms

macOS/Linux fully tested. Windows: static hosts only (no wildcard DNS).

Stack: K8s (Rancher Desktop/k3d), Helm 3, OTel Collector, Grafana, Loki, Prometheus, Tempo, Traefik.

---

## Operations

**Install:** `./scripts/install_argo.sh`  
**Sync:** `./scripts/force_argo_sync.sh`

**DNS:** Configure dnsmasq `address=/.k8s.test/127.0.0.1` (see docs/INSTALLATION.md)

**Access:**
- Grafana: http://grafana.k8s.test
- Loki: http://loki.k8s.test (multi-tenant via `X-Scope-OrgId`)
- OTel: http://otel-collector.k8s.test
- ArgoCD: http://argocd.k8s.test

---

## Quick Tests

**Loki:**
```bash
curl -H "Content-Type: application/json" -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  --data-raw '{"streams":[{"stream":{"job":"test"},"values":[["'"$(date +%s)000000000"'","test"]]}]}' \
  -H "X-Scope-OrgId: foo"
```

**All signals:** `kubectl apply -f manifests/telemetry-test-jobs.yaml`

---

## Troubleshooting

- Ingress issues → Check Traefik + Ingress objects
- Empty Grafana → Verify datasources + service URLs
- No data → Check OTel pipelines + pod logs
- Chart not deploying → `helm dependency update` + commit .tgz
- ArgoCD out of sync → Run force sync or check targetRevision

