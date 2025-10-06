# GitHub Issues - ObservabilityStack

Issue templates based on project review. Copy-paste these into GitHub Issues.

---

## 🔧 Scripts & Automation

### Issue: Create shared library for script functions

**Labels:** `enhancement`, `scripts`, `refactoring`

**Description:**

Scripts have 50+ lines of duplicated code (color codes, directory navigation, common functions).

**Proposal:**
- Create `scripts/lib/common.sh` with shared functions
- Functions: color codes, repo navigation, prerequisite validation, error handling
- Update all scripts to source the library

**Benefits:**
- Reduce duplication by ~50 lines per script
- Consistent error messages
- Easier maintenance

**Files affected:**
- `scripts/install_argo.sh`
- `scripts/force_argo_sync.sh`
- `scripts/setup_argocd.sh`
- `scripts/merge_feature.sh`

---

### Issue: Add requirement validation to install script

**Labels:** `bug`, `scripts`, `dx`

**Description:**

`scripts/install_argo.sh` doesn't validate prerequisites (kubectl, helm, cluster connectivity) before starting installation, leading to confusing mid-installation failures.

**Expected behavior:**
- Check for required commands: `kubectl`, `helm`, `git`
- Verify cluster connectivity: `kubectl cluster-info`
- Clear error messages if prerequisites missing

**Current behavior:**
- Installation starts without checks
- Fails partway through with cryptic errors

---



## 📚 Documentation

### Issue: Remove non-functional Tempo search API from docs

**Labels:** `documentation`, `tempo`

**Description:**

`TROUBLESHOOTING.md` documents Tempo search API commands that don't work because search is disabled in the current configuration.

**Current state:**
```bash
# VIKTIGT: Tempo måste ha search aktiverat för search API:et att fungera
# Nuvarande konfiguration har INTE search aktiverat
```

**Action needed:**
- Remove search API commands from troubleshooting guide
- Add note: "Trace search must be performed via Grafana UI"
- OR: Enable search in Tempo configuration if intended

---

### Issue: Document multi-tenant architecture

**Labels:** `documentation`, `enhancement`

**Description:**

Project uses multi-tenancy (tenants `foo` and `bazz`) but this is not explained anywhere.

**Missing documentation:**
- What is multi-tenancy in this context?
- How to use `X-Scope-OrgID` header
- How to query different tenants
- Tenant isolation guarantees
- When to use `--org-id` flag

**Suggested location:** `docs/ARCHITECTURE.md` or new `docs/MULTI_TENANCY.md`

---

### Issue: Add security warnings for default credentials

**Labels:** `documentation`, `security`

**Description:**

Lab uses insecure default credentials without prominent security warnings.

**Default credentials:**
- Grafana: `admin/admin`
- MinIO: `minio/minio123`
- ArgoCD: Retrieved from k8s secret

**Action needed:**
- Add security notice to README.md
- Document how to change credentials
- Warn against internet exposure
- Consider adding SECURITY.md

---

### Issue: Document ArgoCD password recovery

**Labels:** `documentation`, `argocd`

**Description:**

`argocd-initial-admin-secret` may not exist or gets auto-deleted, but docs don't explain recovery.

**Add to TROUBLESHOOTING.md:**
- Check if secret exists
- Password reset procedure
- Alternative access methods

---

## 🏗️ Infrastructure & Configuration

### Issue: Review and optimize Helm values

**Labels:** `enhancement`, `configuration`

**Description:**

`helm/stackcharts/values/*.yaml` files haven't been deeply reviewed for:
- Reasonable resource requests/limits
- Consistent storage configurations
- Proper multi-tenant setup
- Conflicting settings

**Action:**
Systematic review of all component values files:
- `loki.yaml`
- `tempo.yaml`
- `prometheus.yaml`
- `grafana.yaml`
- `opentelemetry-collector.yaml`
- `minio.yaml`

---

### Issue: Verify telemetry test jobs endpoint

**Labels:** `bug`, `testing`

**Description:**

`manifests/telemetry-test-jobs.yaml` uses endpoint `otel-collector.observability-lab.svc.cluster.local:4317`

**Question:** Should this match the Helm chart service name? Need to verify actual service name created by opentelemetry-collector chart.

**Also consider:** Converting Jobs to Deployments for continuous telemetry generation (better for learning lab).

---

## 🐹 Demo Application

### Issue: Review and document demo application

**Labels:** `documentation`, `demo-app`

**Description:**

`app/src/demo/main.go` exists but:
- Not documented in README
- Unknown if properly configured to send to OTel collector
- No deployment instructions
- No Dockerfile or K8s manifests

**Action needed:**
1. Review app instrumentation
2. Verify it sends to collector
3. Add deployment instructions
4. Consider adding Dockerfile + K8s manifests
5. Document in README or USAGE_GUIDE.md

---

## 🧹 Cleanup & Maintenance

### Issue: Review tmp/ directory contents

**Labels:** `maintenance`, `cleanup`

**Description:**

`tmp/` directory contains files without clear purpose:
- `tmp/audit.conf`
- `tmp/local_otel.conf`
- `tmp/otelcol`

**Questions:**
- Are these used by anything?
- Leftover from testing?
- Should they be documented or deleted?

**Action:** Document purpose or clean up obsolete files.

---

### Issue: Audit deprecated documentation

**Labels:** `documentation`, `maintenance`

**Description:**

`tmp/deprecated/` contains old documentation:
- `MINIO_SETUP.md`
- `MINIO_TROUBLESHOOTING.md`
- `README.md`

**Action:**
- Review if any information should be preserved
- Delete if fully obsolete
- Update .gitignore if needed

---

## 🎯 Enhancements

### Issue: Add manual installation guide

**Labels:** `documentation`, `enhancement`

**Description:**

Only scripted installation is documented. Add manual step-by-step guide for users who:
- Want to understand each step
- Need to customize the process
- Are troubleshooting script issues

**Suggested location:** `docs/INSTALLATION.md` - new "Manual Installation" section

---

### Issue: Add DNS configuration troubleshooting

**Labels:** `documentation`, `troubleshooting`

**Description:**

DNS setup (`*.k8s.test`) is platform-specific but troubleshooting is minimal.

**Add to TROUBLESHOOTING.md:**
- How to verify DNS is working
- Common DNS issues (macOS, Linux, Windows)
- Fallback options (port-forward, hosts file)
- Testing with `dig`, `nslookup`

---

### Issue: Add health check script

**Labels:** `enhancement`, `scripts`

**Description:**

Create quick health check script for the entire stack.

**Suggested:** `scripts/health_check.sh`

**Features:**
- Check all pods are running
- Test all endpoints (Grafana, Loki, Tempo, Prometheus, OTel)
- Verify ArgoCD sync status
- Color-coded output (pass/fail)

---

## 📊 Priority Summary

**Critical (Fix ASAP):**
- ❌ Add prerequisite validation to install script

**High (Should fix soon):**
- ⚠️ Remove non-functional Tempo search API docs
- ⚠️ Document multi-tenant architecture
- ⚠️ Add security warnings

**Medium (Nice to have):**
- 🔧 Create shared script library
- 📚 Document ArgoCD password recovery
- 🐹 Review demo application

**Low (Future improvements):**
- 🎯 Manual installation guide
- 🎯 Health check script
- 🧹 Review tmp/ directory

---

**Total Issues:** 16

**Estimated effort:** 6-10 hours to address all critical and high priority items
