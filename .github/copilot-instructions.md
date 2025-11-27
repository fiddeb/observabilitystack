## Project Overview

ObservabilityStack is a **GitOps-managed observability lab** for local Kubernetes clusters. It uses a **Helm umbrella chart pattern** with ArgoCD to deploy OpenTelemetry, Grafana, Loki, Prometheus, and Tempo.

**Key Architecture Concepts:**
- **Umbrella Chart Pattern**: Single Helm chart (`helm/stackcharts`) manages all components as dependencies
- **Multi-Values Configuration**: Split values across files (`values/base.yaml`, `values/grafana.yaml`, etc.) loaded via ArgoCD `valueFiles`
- **GitOps Deployment**: ArgoCD syncs from Git tag `v0.1.0` (stable) or branch `main` (development)
- **Shared Script Library**: Common functions in `scripts/lib/common.sh` (color output, validation, waiting)

⸻

## Critical Architecture Patterns

### Helm Chart Versioning (IMPORTANT)
Helm charts have **two versions** - understand the difference:
- **Chart version**: Version of the Helm package (e.g., `grafana: 10.1.0`)
- **App version**: Version of the application itself (e.g., Grafana app `12.2.0`)
- Use `helm search repo <chart>` to see both versions
- Update chart versions in `helm/stackcharts/Chart.yaml`, then run `helm dependency update`

**Example workflow:**
```bash
# Check available versions
helm search repo grafana/grafana
# grafana/grafana  10.1.0  12.2.0  ← chart ver / app ver

# Update Chart.yaml with chart version 10.1.0 (not app version!)
# Then update dependencies
cd helm/stackcharts && helm dependency update
```

### ArgoCD Multi-Values Pattern
ArgoCD loads **all values files** in order listed in `argocd/observability-stack.yaml`:
```yaml
helm:
  valueFiles:
    - values/base.yaml              # Component on/off switches
    - values/loki.yaml              # Full Loki config
    - values/tempo.yaml             # Full Tempo config
    # ... order matters for overrides
```

### Shared Script Library Pattern
All scripts source `scripts/lib/common.sh` for consistent output and utilities:
```bash
#!/bin/bash
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

print_header "🚀 My Script"
print_step "Doing something..."
validate_prerequisites kubectl helm git || exit 1
```

⸻

## Folder Structure

**Critical paths:**
- `helm/stackcharts/Chart.yaml` - Dependency versions (loki 6.36.0, grafana 10.1.0, etc.)
- `helm/stackcharts/values/` - Split configuration (one file per component)
  - `base.yaml` - Component enable/disable flags
  - `<component>.yaml` - Full component configuration (overrides subchart defaults)
- `helm/stackcharts/charts/` - Downloaded .tgz files (managed by `helm dependency update`)
- `argocd/observability-stack.yaml` - ArgoCD Application with `targetRevision` and multi-values
- `scripts/lib/common.sh` - Shared functions (print_*, validate_*, wait_for_*)
- `docs/` - Comprehensive documentation (ARCHITECTURE.md is key for understanding design)

⸻

## Critical Developer Workflows

### 1. Update Component Chart Version
```bash
# Step 1: Check available versions
helm search repo grafana/grafana

# Step 2: Edit helm/stackcharts/Chart.yaml - update chart version
# Step 3: Update dependencies and commit
cd helm/stackcharts && helm dependency update
git add -u  # Only updated files
git add charts/grafana-*.tgz  # New chart file
git commit -m "feat: update grafana chart to X.Y.Z (app version A.B.C)"

# Step 4: Move git tag and push
git tag -d v0.1.0 && git tag v0.1.0
git push origin main
git push origin v0.1.0 --force
```

### 2. Sync Configuration Changes
After editing values files in `helm/stackcharts/values/`:
```bash
./scripts/force_argo_sync.sh  # Intelligent sync with safety checks
```

**What it does:**
- Checks if `targetRevision` matches current branch
- Updates ArgoCD if on a tag (production) vs branch (development)
- Forces Git refresh and waits for healthy deployment
- Shows pod status in target namespace

### 3. Feature Branch Workflow (CRITICAL)
**Never merge feature branches manually** - use the merge script:
```bash
./scripts/merge_feature.sh feat/my-feature
```

**Why?** ArgoCD's `targetRevision` must point to `main` before merge, or production breaks. Script auto-resets it.

**Manual workflow** (if script unavailable):
```bash
git checkout feat/my-feature
# Edit argocd/observability-stack.yaml: targetRevision: main
git add argocd/observability-stack.yaml
git commit -m "fix: reset targetRevision to main before merge"
git checkout main && git merge feat/my-feature
```

### 4. Test Configuration Changes
Before committing values changes:
```bash
./scripts/test_multi_values.sh  # Validates Helm template rendering
```

### 5. Complete Installation
From zero to running stack:
```bash
./scripts/install_argo.sh  # Installs ArgoCD + deploys entire stack
```

⸻

## Platform & Dependencies

**Primary platforms:** macOS and Linux (fully tested)  
**Limited support:** Windows (static hosts file only - no wildcard DNS)

**Stack components:**
- Kubernetes (Rancher Desktop/minikube/k3d)
- Helm 3 for chart management
- OpenTelemetry Collector (telemetry pipeline)
- Grafana 12.2.0, Loki 6.36.0, Prometheus 27.30.0, Tempo 1.23.3
- Traefik (Ingress Controller - must be pre-installed)

⸻

## Coding Standards

**Shell (bash):**
- Use `set -Eeuo pipefail` at the top of all scripts
- Source `scripts/lib/common.sh` for shared functions
- Use `print_*` functions for consistent output (not raw `echo`)
- Validate prerequisites with `validate_prerequisites kubectl helm git`

**YAML:**
- 2-space indentation
- Comment non-default values to explain "why"
- Keep environment-specific overrides in `*-local.yaml` (gitignored)
- One component per values file (`values/grafana.yaml`, not monolithic)

**Git commits:**
- Semantic format: `feat:`, `fix:`, `docs:`, `chore:`, `refactor:`
- Example: `feat: add loki multi-tenancy support`
- Use `git add -u` for updates, `git add <filename>` for new files
- Never `git add .` blindly

**Safety patterns:**
- Dry-run Helm: `helm upgrade --install --dry-run --debug`
- Dry-run kubectl: `kubectl apply --dry-run=client`
- Test multi-values before commit: `./scripts/test_multi_values.sh`

⸻

## Documentation Standards

**Structure:** Clear hierarchical organization with consistent markdown  
**Language:** English or Swedish as appropriate for target audience  
**Code examples:** Must be working, tested commands with expected output

**File organization:**
- `/docs/INSTALLATION.md`: Complete setup from zero to working system
- `/docs/USAGE_GUIDE.md`: How to use the system once installed
- `/docs/TROUBLESHOOTING.md`: Emergency procedures, debugging, complete command reference
- `/docs/GIT_WORKFLOW.md`: Git and development workflow guidelines
- `/docs/ARCHITECTURE.md`: **Critical** - umbrella chart pattern, multi-values design

**Requirements:**
- Cross-reference related sections with markdown links
- Include verification steps and expected results for all procedures
- Update docs in same PR as feature changes (never defer documentation)
- Remove outdated content promptly

**Emoji usage (functional only):**
- Status: ✅ ❌ ⚠️ 🔄 (success, failure, warning, in-progress)
- Alerts: ⚠️ 💡 (critical, information)
- No decorative emojis - must add functional value
- Always pair with clear text for accessibility

⸻

## Branching Policy

**No direct commits to `main`** - all work must be in feature branches:
- Branch naming: `feat/`, `fix/`, `chore/`, `docs/` prefixes (e.g., `feat/add-otel-collector`)
- Create Pull Request targeting `main` with at least one reviewer
- Ensure CI checks pass before merge
- Use `./scripts/merge_feature.sh` to safely merge (auto-resets `targetRevision`)

**Emergency fixes:** Only via review-approved fast-forward or revert+PR workflow

⸻

## Operations Guidelines

**Install (GitOps):** `./scripts/install_argo.sh` - installs ArgoCD and deploys complete stack  
**Manual sync:** `./scripts/force_argo_sync.sh` - forces ArgoCD to sync from Git

**Ingress/Hosts:** Configure dnsmasq for wildcard DNS (see `docs/INSTALLATION.md`):
- **macOS:** `address=/.k8s.test/127.0.0.1` in `/opt/homebrew/etc/dnsmasq.conf` + `/etc/resolver/k8s.test`
- **Linux:** `address=/.k8s.test/127.0.0.1` in `/etc/dnsmasq.conf` + NetworkManager/systemd-resolved
- **Windows:** Static hosts file only (wildcard DNS not supported)

**Access points:**
- Grafana: http://grafana.k8s.test (anonymous by default)
- Loki: http://loki.k8s.test (multi-tenancy via `X-Scope-OrgId`)
- OTel Collector: http://otel-collector.k8s.test
- ArgoCD: http://argocd.k8s.test

**Enable Grafana login** (edit `helm/stackcharts/values/grafana.yaml`):
```yaml
grafana:
  grafana.ini:
    auth:
      disable_login: false
    auth.anonymous:
      enabled: false
```

⸻

## UI/Dashboard Guidelines

- Keep Grafana dashboards minimal (smoke tests: one panel per signal type)
- Provision datasources via `grafana.yaml` - avoid manual setup drift
- Store dashboard JSON in `/dashboards` and auto-provision

⸻

## Quick Smoke Tests

**Push test log to Loki (tenant `foo`):**
```bash
curl -H "Content-Type: application/json" -XPOST -s \
"http://loki.k8s.test/loki/api/v1/push" \
--data-raw '{
  "streams": [
    {
      "stream": { "job": "test" },
      "values": [["'"$(date +%s)'"000000000", "fizzbuzz"]]
    }
  ]
}' \
-H "X-Scope-OrgId: foo"

logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test"}' --limit=5000 --since=60m
```

**Automated telemetry tests:**
```bash
kubectl apply -f manifests/telemetry-test-jobs.yaml
# Check Grafana: Metrics (gen{}), Logs ({job="telemetrygen-logs"}), Traces (service.name="telemetrygen")
```

⸻

## Troubleshooting (Shortlist)

- **Ingress not routing** → Check Traefik installation and Ingress objects
- **Grafana empty** → Verify datasource provisioning and service URLs
- **No logs/metrics/traces** → Check OTel pipelines, exporter endpoints, component pod logs
- **Chart updates not deploying** → Run `helm dependency update` in `helm/stackcharts`, commit `.tgz` files
- **ArgoCD out of sync** → Run `./scripts/force_argo_sync.sh` or check `targetRevision` mismatch

⸻

## Design Notes

- Minimal footprint for fast local experimentation
- Keep risky changes in `*-local.yaml` overrides (gitignored)
- Prefer small, well-explained PRs with test plans
- Document "why" for non-obvious configuration choices

