# Quick Troubleshooting Guide - Checklists

This document contains quick checklists for common troubleshooting scenarios.

## Emergency Troubleshooting - 5 Minute Checklist

### 1. Quick Health Check
```bash
# Are all pods running?
kubectl get pods -n observability-lab

# Is ArgoCD synced?
kubectl get application observability-stack -n argocd

# Basic connectivity
curl -s http://loki.k8s.test/ready
curl -s http://grafana.k8s.test/api/health
```

### 2. If Pods Are Down
```bash
# 1. Check events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp | tail -10

# 2. Restart problematic pods
kubectl delete pod <pod-name> -n observability-lab

# 3. Force ArgoCD sync
./scripts/force_argo_sync.sh
```

### 3. If Ingress Doesn't Work
```bash
# 1. Use port forwards as backup
kubectl port-forward service/grafana 3000:3000 -n observability-lab &
kubectl port-forward service/loki 3100:3100 -n observability-lab &

# 2. Test directly to service
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -s http://loki.observability-lab.svc.cluster.local:3100/ready
```

## Deployment Checklist

### Before Deployment
- [ ] `git status` - no uncommitted changes
- [ ] `targetRevision: main` in argocd/observability-stack.yaml

### After Deployment
- [ ] `kubectl get pods -n observability-lab` - all pods Running
- [ ] `kubectl get application observability-stack -n argocd` - Synced + Healthy
- [ ] Ingress endpoints respond: loki.k8s.test, grafana.k8s.test
- [ ] Send test log to Loki

### Verification Commands
```bash
# Pod status
kubectl get pods -n observability-lab

# ArgoCD status
kubectl get application observability-stack -n argocd

# Service endpoints
curl -s http://loki.k8s.test/ready
curl -s http://grafana.k8s.test

# Test log ingestion
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"deployment-test"},"values":[["'$(date +%s%N)'","Deployment verification test"]]}]}'

# Verify log arrived
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="deployment-test"}' --limit=5 --since=5m
```

## Multi-Tenant Troubleshooting

### Loki Tenant Checklist
```bash
# 1. Test both tenants
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"foo-test"},"values":[["'$(date +%s%N)'","Test from foo tenant"]]}]}'

curl -H "Content-Type: application/json" -H "X-Scope-OrgID: bazz" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"bazz-test"},"values":[["'$(date +%s%N)'","Test from bazz tenant"]]}]}'

# 2. Verify tenant isolation
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="foo-test"}' --limit=5 --since=5m
logcli query --addr=http://loki.k8s.test --org-id="bazz" '{job="bazz-test"}' --limit=5 --since=5m

# 3. Check automatic routing via OTEL
kubectl logs -n observability-lab deployment/otel-collector | grep -i routing
```

### Grafana Datasource Checklist
```bash
# Check that both datasources are configured
kubectl get configmap grafana -n observability-lab -o yaml | grep -A5 "loki\|bazz"

# Test datasource connectivity from Grafana pod
kubectl exec -it -n observability-lab deployment/grafana -- wget -qO- "http://loki-gateway:80/ready"
```

### OTEL Routing Checklist
- [ ] Logs with `dev.audit.category` attribute go to bazz tenant
- [ ] Other logs go to foo tenant (default)
- [ ] Routing processor works: `kubectl logs -n observability-lab deployment/otel-collector | grep routing`

## Storage Backend

**Current:** Local filesystem storage via PVCs

## Network Troubleshooting

### DNS Resolution
```bash
# Internal DNS working?
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki.observability-lab.svc.cluster.local

# External DNS (for ingress)?
nslookup loki.k8s.test
nslookup grafana.k8s.test
```

### Service Connectivity
```bash
# Test internal service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -s http://loki.observability-lab.svc.cluster.local:3100/ready

# Test cross-service connectivity
kubectl -n observability-lab exec grafana-$(kubectl get pod -n observability-lab -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' | cut -d'-' -f2-) -- wget -qO- http://loki:3100/ready
```

## Configuration Verification

### ArgoCD Branch Verification
```bash
# Current Git branch
git rev-parse --abbrev-ref HEAD

# ArgoCD targetRevision
kubectl get application observability-stack -n argocd -o jsonpath='{.spec.source.targetRevision}'

# Should match! If not:
./scripts/force_argo_sync.sh
```

## Performance Quick Checks

### Resource Usage
```bash
# Pod resource usage
kubectl top pods -n observability-lab

# Node pressure?
kubectl top nodes
kubectl describe nodes | grep -E "(Pressure|Allocatable|Allocated)"

# PVC disk usage
kubectl get pvc -n observability-lab
kubectl describe pvc -n observability-lab
```

### Application Performance
```bash
# Response times
time curl -s http://loki.k8s.test/ready
time curl -I http://grafana.k8s.test

# Log ingestion performance
time curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"perf-test"},"values":[["'$(date +%s%N)'","Performance test log"]]}]}'

# Query performance
time logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="perf-test"}' --limit=1 --since=1h
```

## Recovery Procedures

### Complete Stack Restart
```bash
# 1. Delete all pods (will be recreated)
kubectl delete pods --all -n observability-lab

# 2. Wait for restart
kubectl get pods -n observability-lab -w

# 3. Verify health
./scripts/force_argo_sync.sh
```

### ArgoCD Recovery
```bash
# 1. Reset to known good state
git checkout main
./scripts/force_argo_sync.sh

# 2. If that fails, recreate application
kubectl delete application observability-stack -n argocd
kubectl apply -f argocd/observability-stack.yaml -n argocd
```


## Emergency Contacts & Commands

### Quick Access Commands
```bash
# Port forwards for emergency access
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward service/minio-console 9090:9090 -n observability-lab &

# Backup log access
kubectl logs -l app.kubernetes.io/name=loki -n observability-lab --tail=50
kubectl logs -l app.kubernetes.io/name=grafana -n observability-lab --tail=50
```

### Links When Port Forward Is Running
- Grafana: http://localhost:3000 (admin/admin)
- Direct Loki: http://localhost:3100

### One-Liner Status Check
```bash
echo "=== Pod Status ===" && kubectl get pods -n observability-lab && echo "=== ArgoCD Status ===" && kubectl get application observability-stack -n argocd && echo "=== Endpoints ===" && curl -s http://loki.k8s.test/ready | head -1 && curl -sI http://grafana.k8s.test | head -1
```

---
