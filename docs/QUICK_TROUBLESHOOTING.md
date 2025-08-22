# Snabb Felsökningsguide - Checklists

Detta dokument innehåller snabba checklists för vanliga felsökningsscenarier.

## 🚨 Akut Felsökning - 5 Minuter Checklist

### 1. Snabb Hälsokontroll
```bash
# Är alla pods igång?
kubectl get pods -n observability-lab

# Är ArgoCD synkad?
kubectl get application observability-stack -n argocd

# Grundläggande connectivity
curl -I http://loki.k8s.test/ready
curl -I http://grafana.k8s.test
```

### 2. Om Pods är Nere
```bash
# 1. Kolla events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp | tail -10

# 2. Restart problematiska pods
kubectl delete pod <pod-name> -n observability-lab

# 3. Force ArgoCD sync
./scripts/force_argo_sync.sh
```

### 3. Om Ingress inte Fungerar
```bash
# 1. Kolla port forwards som backup
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward service/loki 3100:3100 -n observability-lab &

# 2. Testa direkt till service
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://loki.observability-lab.svc.cluster.local:3100/ready
```

## 📋 Deployment Checklist

### Före Deployment
- [ ] `git status` - inga uncommittade ändringar
- [ ] `targetRevision: main` i argocd/observability-stack.yaml
- [ ] Alla tester passerar lokalt

### Efter Deployment
- [ ] `kubectl get pods -n observability-lab` - alla pods Running
- [ ] `kubectl get application observability-stack -n argocd` - Synced + Healthy
- [ ] Ingress endpoints svarar: loki.k8s.test, grafana.k8s.test
- [ ] Skicka testlogg till Loki
- [ ] Kontrollera S3 buckets har data

### Verifiering Commands
```bash
# Pod status
kubectl get pods -n observability-lab

# ArgoCD status  
kubectl get application observability-stack -n argocd

# Service endpoints
curl -I http://loki.k8s.test/ready
curl -I http://grafana.k8s.test

# Test log ingestion
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"deployment-test"},"values":[["'$(date +%s%N)'","Deployment verification test"]]}]}'

# Verify log arrived
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="deployment-test"}' --limit=5 --since=5m
```

## 🔍 S3/Minio Checklist

### Minio Health Check
```bash
# 1. Minio pod running?
kubectl get pods -n observability-lab | grep minio

# 2. Buckets exist?
kubectl -n observability-lab exec -it $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls local/

# 3. Data in buckets?
kubectl -n observability-lab exec -it $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls local/loki-chunks/
kubectl -n observability-lab exec -it $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls local/tempo-traces/

# 4. Credentials working?
kubectl get secret minio -n observability-lab -o jsonpath='{.data.root-password}' | base64 -d
```

### S3 Integration Verification
```bash
# Test S3 connectivity from Loki
kubectl -n observability-lab exec loki-0 -- wget -qO- http://minio:9000/minio/health/live

# Test S3 connectivity from Tempo  
kubectl -n observability-lab exec tempo-0 -- wget -qO- http://minio:9000/minio/health/live

# Check S3 config in runtime
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/config | grep -A 10 s3
```

## 🌐 Network Troubleshooting

### DNS Resolution
```bash
# Internal DNS working?
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki.observability-lab.svc.cluster.local
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup minio.observability-lab.svc.cluster.local

# External DNS (for ingress)?
nslookup loki.k8s.test
nslookup grafana.k8s.test
```

### Service Connectivity
```bash
# Test internal service connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://loki.observability-lab.svc.cluster.local:3100/ready

# Test cross-service connectivity  
kubectl -n observability-lab exec grafana-$(kubectl get pod -n observability-lab -l app.kubernetes.io/name=grafana -o jsonpath='{.items[0].metadata.name}' | cut -d'-' -f2-) -- wget -qO- http://loki:3100/ready
```

## 🔧 Configuration Verification

### Quick Config Checks
```bash
# Loki using S3?
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/config | grep -E "s3|minio"

# Tempo using S3?
kubectl -n observability-lab exec tempo-0 -- cat /etc/tempo/tempo.yaml | grep -E "s3|minio"

# Environment variables correct?
kubectl -n observability-lab exec loki-0 -- env | grep -E "MINIO|S3"
kubectl -n observability-lab exec tempo-0 -- env | grep -E "MINIO|S3"
```

### ArgoCD Branch Verification
```bash
# Current Git branch
git rev-parse --abbrev-ref HEAD

# ArgoCD targetRevision
kubectl get application observability-stack -n argocd -o jsonpath='{.spec.source.targetRevision}'

# Should match! If not:
./scripts/force_argo_sync.sh
```

## 🚀 Performance Quick Checks

### Resource Usage
```bash
# Pod resource usage
kubectl top pods -n observability-lab

# Node pressure?
kubectl top nodes
kubectl describe nodes | grep -E "(Pressure|Allocatable|Allocated)"

# Disk usage in Minio
kubectl -n observability-lab exec $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- df -h
```

### Application Performance
```bash
# Response times
time curl -I http://loki.k8s.test/ready
time curl -I http://grafana.k8s.test

# Log ingestion performance
time curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{"streams":[{"stream":{"job":"perf-test"},"values":[["'$(date +%s%N)'","Performance test log"]]}]}'

# Query performance
time logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="perf-test"}' --limit=1 --since=1h
```

## 🔄 Recovery Procedures

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

### Data Recovery (från S3)
```bash
# Check what data exists in S3
kubectl -n observability-lab exec -it $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls --recursive local/loki-chunks/
kubectl -n observability-lab exec -it $(kubectl get pod -n observability-lab -l app=minio -o jsonpath='{.items[0].metadata.name}') -- mc ls --recursive local/tempo-traces/

# Data should persist across pod restarts automatically
```

## 📱 Emergency Contacts & Commands

### Quick Access Commands
```bash
# Port forwards för emergency access
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward service/minio-console 9090:9090 -n observability-lab &

# Backup log access
kubectl logs -l app.kubernetes.io/name=loki -n observability-lab --tail=50
kubectl logs -l app.kubernetes.io/name=grafana -n observability-lab --tail=50
```

### Links när Port Forward är Igång
- Grafana: http://localhost:3000 (admin/admin)
- Minio Console: http://localhost:9090 (minio/minio-password)
- Direct Loki: http://localhost:3100

### One-Liner Status Check
```bash
echo "=== Pod Status ===" && kubectl get pods -n observability-lab && echo "=== ArgoCD Status ===" && kubectl get application observability-stack -n argocd && echo "=== Endpoints ===" && curl -sI http://loki.k8s.test/ready | head -1 && curl -sI http://grafana.k8s.test | head -1
```

---

*Quick Reference Guide - Spara som bookmark! 🔖*
