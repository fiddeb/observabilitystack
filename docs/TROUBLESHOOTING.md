# Troubleshooting Guide

How to debug, test, and recover the ObservabilityStack.

---

## Quick Recovery

### 5-Minute Health Check

```bash
# 1. Pod status
kubectl get pods -n observability-lab

# 2. ArgoCD sync status
kubectl get application observability-stack -n argocd

# 3. Endpoint connectivity
curl -s http://loki.k8s.test/ready
curl -s http://grafana.k8s.test/api/health
```

### Common Fixes

#### If Pods Are Down
```bash
# 1. Check recent events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp | tail -10

# 2. Restart problematic pod
kubectl delete pod <pod-name> -n observability-lab

# 3. Force ArgoCD sync
./scripts/force_argo_sync.sh
```

#### If Ingress Doesn't Work
```bash
# 1. Use port forwards as backup
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward service/loki 3100:3100 -n observability-lab &

# 2. Test service directly
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s http://loki.observability-lab.svc.cluster.local:3100/ready
```

#### Restart All Pods
```bash
# 1. Delete all pods (Kubernetes recreates them)
kubectl delete pods --all -n observability-lab

# 2. Wait for all pods to be ready
kubectl get pods -n observability-lab -w

# 3. Verify health and sync
./scripts/force_argo_sync.sh
```

#### ArgoCD Recovery
```bash
# 1. Reset to known good state
git checkout main
./scripts/force_argo_sync.sh

# 2. If that fails, recreate application
kubectl delete application observability-stack -n argocd
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

### One-Liner Status Check
```bash
echo "=== Pods ===" && kubectl get pods -n observability-lab && \
echo "=== ArgoCD ===" && kubectl get application observability-stack -n argocd && \
echo "=== Endpoints ===" && curl -s http://loki.k8s.test/ready && \
curl -sI http://grafana.k8s.test | head -1
```

---

## Deployment Checklists

### Pre-Deployment Checklist
- [ ] `git status` - No uncommitted changes
- [ ] `targetRevision: main` in `argocd/observability-stack.yaml`
- [ ] All tests pass locally
- [ ] Configuration reviewed

### Post-Deployment Checklist
- [ ] All pods Running: `kubectl get pods -n observability-lab`
- [ ] ArgoCD Synced + Healthy: `kubectl get application observability-stack -n argocd`
- [ ] Ingress endpoints respond: `loki.k8s.test`, `grafana.k8s.test`
- [ ] Test log ingestion (see [Loki Testing](#loki-testing))

### Deployment Verification
```bash
# Pod status
kubectl get pods -n observability-lab

# ArgoCD status
kubectl get application observability-stack -n argocd

# Service endpoints
curl -s http://loki.k8s.test/ready
curl -s http://grafana.k8s.test/api/health

# Test log ingestion
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{"streams":[{"stream":{"job":"deployment-test"},"values":[["'$(date +%s%N)'","Deployment verification"]]}]}'

# Verify log arrived
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job="deployment-test"}' --limit=5 --since=5m
```

---

## Git and Branch Management

### Branch Information
```bash
# Current branch
git rev-parse --abbrev-ref HEAD

# All branches
git branch -a

# Status and changes
git status
git diff
git diff --cached

# Commit history
git log --oneline -10
```

### Feature Branch Workflow
```bash
# Create feature branch
git checkout -b feat/my-feature

# Commit changes
git add -u  # For modified files
git add <filename>  # For new files
git commit -m "feat: description of change"

# Merge to main (recommended - uses script)
./scripts/merge_feature.sh feat/my-feature

# Manual merge (with Git hook protection)
git checkout main
git merge feat/my-feature
```

---

## ArgoCD Operations

### Application Status
```bash
# List all applications
kubectl get applications -n argocd

# Detailed status
kubectl get application observability-stack -n argocd -o yaml

# Check targetRevision (should match current Git branch)
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.spec.source.targetRevision}'

# Sync and health status
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.status.sync.status}'
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.status.health.status}'
```

### ArgoCD Web Interface
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access at: https://localhost:8080 (admin/<password>)

# Create ingress for permanent access
kubectl apply -f manifests/argocd-ingress.yaml
```

### Force Sync
```bash
# Automated sync script (recommended)
./scripts/force_argo_sync.sh

# Manual refresh
kubectl patch application observability-stack -n argocd \
  -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' \
  --type=merge

# Manual sync
kubectl patch application observability-stack -n argocd \
  -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' \
  --type=merge

# Apply ArgoCD application manifest
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

### ArgoCD Server Management
```bash
# Check ArgoCD server status
kubectl get pods -n argocd | grep argocd-server

# Restart ArgoCD server if needed
kubectl delete pod -l app.kubernetes.io/name=argocd-server -n argocd
```

### Branch Verification
```bash
# Current Git branch
git rev-parse --abbrev-ref HEAD

# ArgoCD targetRevision
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.spec.source.targetRevision}'

# Should match! If not, sync:
./scripts/force_argo_sync.sh
```

---

## Kubernetes Debugging

### Pod and Service Information
```bash
# List all pods
kubectl get pods -n observability-lab
kubectl get pods -n observability-lab -o wide

# Describe specific pod
kubectl describe pod <pod-name> -n observability-lab

# Pod logs
kubectl logs <pod-name> -n observability-lab
kubectl logs <pod-name> -n observability-lab --tail=20 --follow

# Logs for specific container
kubectl logs <pod-name> -c <container-name> -n observability-lab

# Previous container logs (for crashed pods)
kubectl logs <pod-name> -n observability-lab --previous
```

### Services and Endpoints
```bash
# List services
kubectl get services -n observability-lab

# List endpoints
kubectl get endpoints -n observability-lab

# Service details
kubectl describe service <service-name> -n observability-lab
```

### ConfigMaps and Secrets
```bash
# List configmaps
kubectl get configmaps -n observability-lab

# Show configmap contents
kubectl get configmap <configmap-name> -n observability-lab -o yaml

# List secrets
kubectl get secrets -n observability-lab

# Get secret value (base64 decoded)
kubectl get secret <secret-name> -n observability-lab \
  -o jsonpath='{.data.<key>}' | base64 -d
```

### Resource Overview
```bash
# All resources
kubectl get all -n observability-lab

# Recent events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Resource usage
kubectl top pods -n observability-lab
kubectl top nodes
```

---

## Loki Testing

### Log Ingestion
```bash
# Send single test log
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{
    "streams": [{
      "stream": {
        "job": "test-job",
        "service_name": "test-service"
      },
      "values": [
        ["'$(date +%s%N)'", "Test log message"]
      ]
    }]
  }'

# Send multiple logs (chunk testing)
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{
    "streams": [{
      "stream": {
        "job": "multi-test",
        "service_name": "batch-test"
      },
      "values": [
        ["'$(date +%s%N)'", "First message"],
        ["'$(date +%s%N)'", "Second message"],
        ["'$(date +%s%N)'", "Third message"]
      ]
    }]
  }'
```

### Log Querying
```bash
# Basic query
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job="test-job"}' --limit=100 --since=1h

# Query specific service
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{service_name="test-service"}' --limit=50 --since=30m

# Pattern matching
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job=~"test.*"}' --limit=200 --since=2h

# Live tail
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job="test-job"}' --tail --since=1m
```

### Multi-Tenant Testing
```bash
# Test foo tenant
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{"streams":[{"stream":{"job":"foo-test"},"values":[["'$(date +%s%N)'","Test from foo"]]}]}'

# Test bazz tenant
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: bazz" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{"streams":[{"stream":{"job":"bazz-test"},"values":[["'$(date +%s%N)'","Test from bazz"]]}]}'

# Verify tenant isolation
logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job="foo-test"}' --limit=5 --since=5m
logcli query --addr=http://loki.k8s.test --org-id="bazz" \
  '{job="bazz-test"}' --limit=5 --since=5m

# Check OTLP routing
kubectl logs -n observability-lab deployment/otel-collector | grep -i routing
```

### Multi-Tenant Checklist
- [ ] Logs with `dev.audit.category` attribute go to bazz tenant
- [ ] Other logs go to foo tenant (default)
- [ ] Routing processor works: check OTLP collector logs
- [ ] Both Grafana datasources configured (Loki-foo and Loki-bazz)

### Loki Configuration
```bash
# Runtime configuration
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/config

# Loki metrics
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/metrics

# Ready status
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/ready

# Loki logs with filtering
kubectl logs loki-0 -n observability-lab --tail=20 | \
  grep -E "(error|warn|chunk|flush|filesystem)"
```

### Grafana Datasource Verification
```bash
# Check datasource configuration
kubectl get configmap grafana -n observability-lab -o yaml | grep -A5 "loki\|bazz"

# Test datasource connectivity from Grafana pod
kubectl exec -it -n observability-lab deployment/grafana -- \
  wget -qO- "http://loki-gateway:80/ready"
```

---

## Tempo/Tracing Testing

### Trace Ingestion
```bash
# Send test trace via OTLP Collector (recommended)
curl -X POST http://otel-collector.k8s.test:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "test-service"}
        }]
      },
      "instrumentationLibrarySpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
          "endTimeUnixNano": "'$((($(date +%s) + 1) * 1000000000))'"
        }]
      }]
    }]
  }'

# Send directly to Tempo (requires port-forward)
kubectl port-forward service/tempo 3200:3200 -n observability-lab &
curl -X POST http://localhost:3200/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "direct-tempo-test"}
        }]
      },
      "instrumentationLibrarySpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "direct-test-span",
          "kind": 1,
          "startTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
          "endTimeUnixNano": "'$((($(date +%s) + 1) * 1000000000))'"
        }]
      }]
    }]
  }'
```

> **Important**: Current configuration does NOT have Tempo search API enabled. Use Grafana to search and view traces.

### Tempo Configuration
```bash
# Show Tempo configmap
kubectl get configmap tempo -n observability-lab -o yaml

# Check environment variables
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 10 -B 5 "env:"

# Tempo logs
kubectl logs tempo-0 -n observability-lab --tail=20

# Tempo metrics
kubectl -n observability-lab exec tempo-0 -- wget -qO- http://localhost:3200/metrics
```

### Tempo Storage Verification
```bash
# Verify traces written to filesystem
kubectl -n observability-lab exec tempo-0 -- ls -lh /var/tempo/traces/

# Check ingestion metrics
kubectl -n observability-lab exec tempo-0 -- wget -qO- "http://localhost:3200/metrics" | \
  grep -E "tempo_distributor|tempo_ingester"
```

---

## OpenTelemetry Collector Testing

### Collector Status
```bash
# Show collector logs
kubectl logs -l app=otel-collector -n observability-lab --tail=20

# Check configuration
kubectl get configmap otel-collector -n observability-lab -o yaml

# Test collector health
curl http://otel-collector.k8s.test:13133/
```

### OTLP Endpoints
```bash
# Test OTLP HTTP endpoint (port 4318)
curl -X POST http://otel-collector.k8s.test:4318/v1/traces \
  -H "Content-Type: application/json" \
  -d '{
    "resourceSpans": [{
      "resource": {
        "attributes": [{
          "key": "service.name",
          "value": {"stringValue": "curl-test"}
        }]
      },
      "instrumentationLibrarySpans": [{
        "spans": [{
          "traceId": "'$(openssl rand -hex 16)'",
          "spanId": "'$(openssl rand -hex 8)'",
          "name": "test-operation",
          "startTimeUnixNano": "'$(($(date +%s) * 1000000000))'",
          "endTimeUnixNano": "'$((($(date +%s) + 1) * 1000000000))'"
        }]
      }]
    }]
  }'

# OTLP gRPC endpoint (port 4317)
# Use OpenTelemetry SDK or grpcurl for testing
```


---

## Network and Connectivity

### DNS Resolution
```bash
# Internal DNS (cluster services)
kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup loki.observability-lab.svc.cluster.local

kubectl run -it --rm debug --image=busybox --restart=Never -- \
  nslookup tempo.observability-lab.svc.cluster.local

# External DNS (ingress)
nslookup loki.k8s.test
nslookup grafana.k8s.test
```

### Service Connectivity
```bash
# Test internal service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s http://loki.observability-lab.svc.cluster.local:3100/ready

kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -s http://tempo.observability-lab.svc.cluster.local:3200/ready

# Test cross-service connectivity
kubectl -n observability-lab exec deployment/grafana -- \
  wget -qO- http://loki:3100/ready
```

### Port Forwarding
```bash
# Loki
kubectl port-forward service/loki 3100:3100 -n observability-lab &

# Grafana
kubectl port-forward service/grafana 3000:80 -n observability-lab &

# Prometheus
kubectl port-forward service/prometheus 9090:80 -n observability-lab &

# Tempo
kubectl port-forward service/tempo 3200:3200 -n observability-lab &

# List active port forwards
ps aux | grep "kubectl port-forward"

# Stop all port forwards
pkill -f "kubectl port-forward"
```

**Access URLs (when port-forwarding):**
- Grafana: http://localhost:3000 (admin/admin)
- Loki: http://localhost:3100
- Prometheus: http://localhost:9090
- Tempo: http://localhost:3200

### Ingress Testing
```bash
# Test ingress endpoints
curl -s http://grafana.k8s.test
curl -s http://loki.k8s.test/ready

# Check ingress resources
kubectl get ingress -n observability-lab
kubectl describe ingress <ingress-name> -n observability-lab
```

---

## Configuration Verification

### Environment Variables
```bash
# Loki environment
kubectl get pod loki-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl -n observability-lab exec loki-0 -- env | sort

# Tempo environment
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl -n observability-lab exec tempo-0 -- env | sort

# Grafana environment
kubectl get pod -n observability-lab -l app.kubernetes.io/name=grafana -o yaml | \
  grep -A 20 "env:"
```

### Volume Mounts
```bash
# Loki volumes
kubectl get pod loki-0 -n observability-lab -o yaml | \
  grep -A 10 -B 5 "volumeMounts"

# Tempo volumes
kubectl get pod tempo-0 -n observability-lab -o yaml | \
  grep -A 10 -B 5 "volumeMounts"
```

### Configuration Files
```bash
# Loki config
kubectl -n observability-lab exec loki-0 -- cat /etc/loki/config/config.yaml

# Tempo config
kubectl -n observability-lab exec tempo-0 -- cat /etc/tempo/tempo.yaml

# Prometheus config
kubectl -n observability-lab exec deployment/prometheus -- \
  cat /etc/prometheus/prometheus.yml
```

---

## Performance and Monitoring

### Resource Usage
```bash
# Pod resource usage
kubectl top pods -n observability-lab

# Node resource usage
kubectl top nodes
kubectl describe nodes | grep -E "(Pressure|Allocatable|Allocated)"

# Resource requests and limits
kubectl describe pods -n observability-lab | grep -E "(Requests|Limits)"

# Detailed resource info
kubectl describe pod <pod-name> -n observability-lab | \
  grep -A 10 -B 5 -E "(Requests|Limits|Containers)"
```

### Storage Usage
```bash
# Check PVC status
kubectl get pvc -n observability-lab

# PVC details
kubectl describe pvc -n observability-lab

# Disk usage in pods
kubectl -n observability-lab exec loki-0 -- df -h /var/loki
kubectl -n observability-lab exec tempo-0 -- df -h /var/tempo
```

### Application Metrics
```bash
# Loki metrics
curl http://loki.k8s.test:3100/metrics | grep loki_

# Tempo metrics
curl http://tempo.k8s.test:3200/metrics | grep tempo_

# Prometheus targets
curl http://prometheus.k8s.test/api/v1/targets

# Grafana health
curl http://grafana.k8s.test/api/health
```

### Performance Testing
```bash
# Response times
time curl -s http://loki.k8s.test/ready
time curl -I http://grafana.k8s.test

# Log ingestion performance
time curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{"streams":[{"stream":{"job":"perf-test"},"values":[["'$(date +%s%N)'","Performance test"]]}]}'

# Query performance
time logcli query --addr=http://loki.k8s.test --org-id="foo" \
  '{job="perf-test"}' --limit=1 --since=1h
```

---

## Troubleshooting Playbook

### Issue: Pod Not Ready/Running

```bash
# Step 1: Check pod status
kubectl get pods -n observability-lab
kubectl describe pod <pod-name> -n observability-lab

# Step 2: Check recent events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Step 3: Check logs
kubectl logs <pod-name> -n observability-lab --previous
kubectl logs <pod-name> -n observability-lab

# Step 4: Check resource constraints
kubectl describe pod <pod-name> -n observability-lab | grep -E "(Requests|Limits)"

# Step 5: Restart pod if necessary
kubectl delete pod <pod-name> -n observability-lab
```

### Issue: Service Not Accessible

```bash
# Step 1: Check service endpoints
kubectl get endpoints <service-name> -n observability-lab

# Step 2: Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl -v http://<service-name>.observability-lab.svc.cluster.local:<port>

# Step 3: Check network policies
kubectl get networkpolicies -n observability-lab

# Step 4: Check ingress configuration
kubectl get ingress -n observability-lab
kubectl describe ingress <ingress-name> -n observability-lab
```

### Issue: Storage Problems (Filesystem)

```bash
# Step 1: Check PVC status
kubectl get pvc -n observability-lab
kubectl describe pvc -n observability-lab

# Step 2: Check disk space
kubectl -n observability-lab exec loki-0 -- df -h /var/loki
kubectl -n observability-lab exec tempo-0 -- df -h /var/tempo

# Step 3: Check for permission issues
kubectl logs loki-0 -n observability-lab | grep -i "permission denied"
kubectl logs tempo-0 -n observability-lab | grep -i "permission denied"

# Step 4: Check PV status
kubectl get pv
kubectl describe pv <pv-name>
```

### Issue: ArgoCD Sync Problems

```bash
# Step 1: Check application status
kubectl get application observability-stack -n argocd
kubectl get application observability-stack -n argocd -o yaml

# Step 2: Force refresh and sync
./scripts/force_argo_sync.sh

# Step 3: Check Git connectivity
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.status.conditions}'

# Step 4: Check targetRevision matches Git branch
git rev-parse --abbrev-ref HEAD
kubectl get application observability-stack -n argocd \
  -o jsonpath='{.spec.source.targetRevision}'

# Step 5: Recreate application if necessary
kubectl delete application observability-stack -n argocd
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

### Issue: No Logs/Traces Appearing

```bash
# Step 1: Verify component is running
kubectl get pods -n observability-lab | grep -E "loki|tempo|otel"

# Step 2: Check OTLP Collector
kubectl logs -l app=otel-collector -n observability-lab --tail=50

# Step 3: Test direct ingestion
# For Loki:
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" \
  -XPOST "http://loki.k8s.test/loki/api/v1/push" \
  -d '{"streams":[{"stream":{"job":"debug"},"values":[["'$(date +%s%N)'","Debug test"]]}]}'

# Step 4: Check storage
kubectl -n observability-lab exec loki-0 -- ls -lh /var/loki/chunks/
kubectl -n observability-lab exec tempo-0 -- ls -lh /var/tempo/traces/

# Step 5: Check Grafana datasource configuration
kubectl get configmap grafana -n observability-lab -o yaml
```

### Issue: Grafana Datasources Not Working

```bash
# Step 1: Check datasource configuration
kubectl get configmap grafana -n observability-lab -o yaml | \
  grep -A 20 "datasources"

# Step 2: Test connectivity from Grafana pod
kubectl exec -it -n observability-lab deployment/grafana -- \
  wget -qO- http://loki-gateway:80/ready

kubectl exec -it -n observability-lab deployment/grafana -- \
  wget -qO- http://tempo:3200/ready

# Step 3: Check Grafana logs
kubectl logs -n observability-lab deployment/grafana --tail=50

# Step 4: Restart Grafana
kubectl delete pod -n observability-lab -l app.kubernetes.io/name=grafana
```

---

## Storage Backend

**Current Configuration:** Local filesystem storage via PVCs

### PVC Commands
```bash
# List all PVCs
kubectl get pvc -n observability-lab

# List all PVs
kubectl get pv

# PVCs for specific component
kubectl get pv -l app.kubernetes.io/name=loki
kubectl get pv -l app.kubernetes.io/name=tempo

# PVC details
kubectl describe pvc -n observability-lab
```
---

## Cleanup and Uninstall

### Quick Cleanup - Keep Cluster Running

Remove the observability stack but keep ArgoCD and cluster infrastructure:

```bash
# 1. Delete the ArgoCD application (keeps ArgoCD itself)
kubectl delete application observability-stack -n argocd

# 2. Verify resources are being removed
kubectl get pods -n observability-lab --watch

# 3. Clean up namespace (if empty)
kubectl delete namespace observability-lab

# 4. Remove ingress rules
kubectl delete ingress -n observability-lab --all

# 5. Clean up any orphaned PVCs (⚠️ deletes data!)
kubectl get pvc -n observability-lab
kubectl delete pvc --all -n observability-lab
```

### Full Uninstall

Remove everything including ArgoCD:

```bash
# 1. Delete observability stack
kubectl delete application observability-stack -n argocd

# 2. Wait for resources to be removed
kubectl wait --for=delete namespace/observability-lab --timeout=120s || true

# 3. Uninstall ArgoCD
kubectl delete namespace argocd

# 4. Remove ArgoCD CRDs
kubectl delete crd applications.argoproj.io
kubectl delete crd applicationsets.argoproj.io
kubectl delete crd appprojects.argoproj.io

# 5. Clean up any remaining PVs (⚠️ deletes all data!)
kubectl get pv | grep observability-lab
kubectl delete pv -l app.kubernetes.io/part-of=observability-stack

# 6. Remove local Git repository artifacts (optional)
rm -rf /Users/faar/Documents/Src/github/fiddeb/observabilitystack/helm/stackcharts/charts/*.tgz
rm -f /Users/faar/Documents/Src/github/fiddeb/observabilitystack/helm/stackcharts/Chart.lock
```

### Selective Component Removal

Remove individual components while keeping the rest:

#### Disable Component via Helm Values

```bash
# 1. Edit helm/stackcharts/values/base.yaml
# Set component.enabled: false (e.g., tempo.enabled: false)

# 2. Commit and push changes
git add helm/stackcharts/values/base.yaml
git commit -m "feat: disable tempo component"
git push origin main

# 3. Force ArgoCD sync
./scripts/force_argo_sync.sh

# 4. Clean up component PVCs (⚠️ deletes data!)
kubectl delete pvc -l app.kubernetes.io/name=tempo -n observability-lab
```

#### Manual Component Removal

```bash
# Example: Remove Tempo
kubectl delete statefulset tempo -n observability-lab
kubectl delete service tempo -n observability-lab
kubectl delete configmap tempo -n observability-lab
kubectl delete pvc -l app.kubernetes.io/name=tempo -n observability-lab
```

### Reset to Clean State

Start fresh without reinstalling cluster:

```bash
# 1. Remove observability stack
kubectl delete application observability-stack -n argocd
kubectl delete namespace observability-lab --wait=true

# 2. Recreate namespace
kubectl create namespace observability-lab

# 3. Reinstall via ArgoCD
./scripts/force_argo_sync.sh

# 4. Wait for healthy state
kubectl wait --for=condition=ready pod --all -n observability-lab --timeout=300s
```

### DNS Cleanup (macOS/Linux)

If you want to remove the `*.k8s.test` DNS configuration:

#### macOS
```bash
# 1. Remove resolver configuration
sudo rm /etc/resolver/k8s.test

# 2. Restart DNS (optional)
sudo killall -HUP mDNSResponder

# 3. Remove dnsmasq configuration (if you want to uninstall dnsmasq)
# Edit /opt/homebrew/etc/dnsmasq.conf and remove: address=/.k8s.test/127.0.0.1
brew services stop dnsmasq
# brew uninstall dnsmasq  # Only if you don't need it for anything else
```

#### Linux
```bash
# 1. Remove dnsmasq configuration
sudo sed -i '/address=\/.k8s.test\/127.0.0.1/d' /etc/dnsmasq.conf

# 2. Restart dnsmasq
sudo systemctl restart dnsmasq
# or
sudo service dnsmasq restart
```

### Verification After Cleanup

Confirm everything is removed:

```bash
# Check namespaces
kubectl get namespace | grep -E 'observability-lab|argocd'

# Check PVs (should show none for observability-lab)
kubectl get pv | grep observability-lab

# Check ingress
kubectl get ingress --all-namespaces

# Test DNS (should fail or timeout)
curl -s --max-time 5 http://grafana.k8s.test || echo "✅ Grafana endpoint removed"
curl -s --max-time 5 http://loki.k8s.test/ready || echo "✅ Loki endpoint removed"
```

### Troubleshooting Cleanup Issues

#### Namespace Stuck in Terminating

```bash
# 1. Check for finalizers
kubectl get namespace observability-lab -o json | jq '.spec.finalizers'

# 2. Force remove finalizers (use with caution!)
kubectl get namespace observability-lab -o json \
  | jq 'del(.spec.finalizers)' \
  | kubectl replace --raw /api/v1/namespaces/observability-lab/finalize -f -
```

#### PVCs Won't Delete

```bash
# 1. Check if PVC is bound to pods
kubectl get pods -n observability-lab -o json | \
  jq '.items[].spec.volumes[].persistentVolumeClaim.claimName'

# 2. Delete pods using the PVC first
kubectl delete pod <pod-name> -n observability-lab --force --grace-period=0

# 3. Then delete PVC
kubectl delete pvc <pvc-name> -n observability-lab
```

#### ArgoCD Application Won't Delete

```bash
# 1. Check finalizers
kubectl get application observability-stack -n argocd -o yaml | grep finalizers -A5

# 2. Remove finalizers if stuck
kubectl patch application observability-stack -n argocd \
  -p '{"metadata":{"finalizers":null}}' --type=merge

# 3. Force delete
kubectl delete application observability-stack -n argocd --force --grace-period=0
```

---

## Useful Shortcuts and Aliases

Add these to your `~/.zshrc` or `~/.bashrc`:

```bash
# Kubernetes aliases
alias k='kubectl'
alias kgp='kubectl get pods'
alias kgs='kubectl get services'
alias kgc='kubectl get configmaps'
alias kd='kubectl describe'
alias kl='kubectl logs'
alias ke='kubectl exec -it'

# Observability namespace shortcuts
alias kobs='kubectl -n observability-lab'
alias kobspods='kubectl get pods -n observability-lab'
alias kobslogs='kubectl logs -n observability-lab'

# ArgoCD shortcuts
alias argoapp='kubectl get application observability-stack -n argocd'
alias argosync='./scripts/force_argo_sync.sh'

# Port forwarding shortcuts
alias pf-grafana='kubectl port-forward service/grafana 3000:80 -n observability-lab &'
alias pf-loki='kubectl port-forward service/loki 3100:3100 -n observability-lab &'
alias pf-tempo='kubectl port-forward service/tempo 3200:3200 -n observability-lab &'
alias pf-prometheus='kubectl port-forward service/prometheus 9090:80 -n observability-lab &'

# Stop all port forwards
alias pf-stop='pkill -f "kubectl port-forward"'
```

---

## Related Documentation

- [Architecture Guide](ARCHITECTURE.md) - System design
- [Installation Guide](INSTALLATION.md) - Setup instructions
- [Usage Guide](USAGE_GUIDE.md) - How to use the stack
- [Git Workflow](GIT_WORKFLOW.md) - Branch and merge procedures

---

**Last Updated:** October 2, 2025
