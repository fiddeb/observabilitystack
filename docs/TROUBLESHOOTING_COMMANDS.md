# Troubleshooting and Test Commands for Observability Stack

This document contains all useful commands for troubleshooting, testing, and verifying the observability stack environment.


## Git och Branch Management

### Branch Information
```bash
# Show current branch
git rev-parse --abbrev-ref HEAD

# Show all branches
git branch -a

# Show Git status
git status

# Show changes
git diff
git diff --cached

# Show commit history
git log --oneline -10
```

### Feature Branch Workflow
```bash
# Create and switch to feature branch
git checkout -b feat/my-feature

# Commit changes
git add -A
git commit -m "feat: description of change"

# Merge using our script (recommended)
./scripts/merge_feature.sh feat/my-feature

# Manual merge (with Git hook protection)
git checkout main
git merge feat/my-feature
```

---

## ArgoCD Operations

### Application Management
```bash
# Show ArgoCD applications
kubectl get applications -n argocd

# Show detailed status for our application
kubectl get application observability-stack -n argocd -o yaml

# Check targetRevision
kubectl get application observability-stack -n argocd -o jsonpath='{.spec.source.targetRevision}'

# Check sync and health status
kubectl get application observability-stack -n argocd -o jsonpath='{.status.sync.status}'
kubectl get application observability-stack -n argocd -o jsonpath='{.status.health.status}'
```

### ArgoCD Web Interface Access
```bash
# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward to ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Create ingress for ArgoCD (permanent access)
kubectl apply -f argocd-ingress.yaml

# Check ArgoCD server status
kubectl get pods -n argocd | grep argocd-server

# Restart ArgoCD server if needed
kubectl delete pod -l app.kubernetes.io/name=argocd-server -n argocd
```

### Force Sync Operations
```bash
# Our automated sync script
./scripts/force_argo_sync.sh

# Manual refresh
kubectl patch application observability-stack -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type=merge

# Manual sync
kubectl patch application observability-stack -n argocd -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' --type=merge

# Apply ArgoCD manifest
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

---

## Kubernetes Debugging

### Pod and Service Information
```bash
# List all pods in observability namespace
kubectl get pods -n observability-lab

# Show detailed pod info
kubectl get pods -n observability-lab -o wide

# Describe specific pod
kubectl describe pod <pod-name> -n observability-lab

# Show pod logs
kubectl logs <pod-name> -n observability-lab
kubectl logs <pod-name> -n observability-lab --tail=20
kubectl logs <pod-name> -n observability-lab --follow

# Logs for container in multi-container pod
kubectl logs <pod-name> -c <container-name> -n observability-lab
```

### Services and Endpoints
```bash
# List services
kubectl get services -n observability-lab

# List endpoints
kubectl get endpoints -n observability-lab

# Show service details
kubectl describe service <service-name> -n observability-lab
```

### ConfigMaps and Secrets
```bash
# List configmaps
kubectl get configmaps -n observability-lab

# Show configmap contents
kubectl get configmap <configmap-name> -n observability-lab -o yaml

# Show secrets
kubectl get secrets -n observability-lab

# Get secret value (base64 decoded)
kubectl get secret <secret-name> -n observability-lab -o jsonpath='{.data.<key>}' | base64 -d
```

### Resource Debugging
```bash
# Show all resources in namespace
kubectl get all -n observability-lab

# Show events in namespace
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Check resource usage
kubectl top pods -n observability-lab
kubectl top nodes
```

---

## Loki Testing and Debugging

### Log Ingestion Testing
```bash
# Send test log to Loki via API
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{
  "streams": [
    {
      "stream": {
        "job": "test-job",
        "service_name": "test-service"
      },
      "values": [
        ["'$(date +%s%N)'", "Test log message from curl"]
      ]
    }
  ]
}'

# Multiple logs for chunk testing
curl -H "Content-Type: application/json" -H "X-Scope-OrgID: foo" -XPOST "http://loki.k8s.test/loki/api/v1/push" -d '{
  "streams": [
    {
      "stream": {
        "job": "s3-test",
        "service_name": "s3-validation"
      },
      "values": [
        ["'$(date +%s%N)'", "First test message"],
        ["'$(date +%s%N)'", "Second test message"],
        ["'$(date +%s%N)'", "Third test message"]
      ]
    }
  ]
```

### Log Querying
```bash
# Use logcli to query logs
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test-job"}' --limit=100 --since=1h

# Query specific service
logcli query --addr=http://loki.k8s.test --org-id="foo" '{service_name="test-service"}' --limit=50 --since=30m

# Query with pattern matching
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job=~"test.*"}' --limit=200 --since=2h

# Live tail
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test-job"}' --tail --since=1m
```

### Loki Configuration Verification
```bash
# Show Loki runtime configuration
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/config

# Check Loki metrics
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/metrics

# Check Loki ready status
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/ready

# Show Loki logs with filtering
kubectl logs loki-0 -n observability-lab --tail=20 | grep -E "(error|warn|chunk|flush|filesystem)"
kubectl logs loki-0 -n observability-lab --tail=50 | grep -E "(storage|filesystem|local)"
```

---

## Tempo/Tracing Testing

### Tempo Configuration
```bash
# Show Tempo configmap
kubectl get configmap tempo -n observability-lab -o yaml

# Check Tempo environment variables
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 10 -B 5 "env:"

# Show Tempo logs
kubectl logs tempo-0 -n observability-lab --tail=20

# Check Tempo metrics
kubectl -n observability-lab exec tempo-0 -- wget -qO- http://localhost:3200/metrics
```

### Trace Testing
```bash
# IMPORTANT: Tempo must have search enabled for the search API to work
# Current configuration does NOT have search enabled

# Send test trace via OpenTelemetry Collector (recommended)
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

# Alternative: Send directly to Tempo (requires port-forward)
# kubectl port-forward service/tempo 3200:3200 -n observability-lab &
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

# IMPORTANT: Tempo must have search enabled for the search API to work
# Current configuration does NOT have search enabled
# Use Grafana to search traces instead

# Verify that traces are written to filesystem storage
kubectl -n observability-lab exec tempo-0 -- ls -lh /var/tempo/traces/

# Check Tempo metrics for trace ingestion
kubectl -n observability-lab exec tempo-0 -- wget -qO- "http://localhost:3200/metrics" | grep -E "tempo_distributor|tempo_ingester"
```

---

## Storage Backend

**Current setup:** Local filesystem storage via PVCs

For S3/Minio setup (deprecated), see [`docs/deprecated/MINIO_SETUP.md`](deprecated/MINIO_SETUP.md)

---

## OpenTelemetry Collector Testing

### Collector Status
```bash
# Show OpenTelemetry Collector logs
kubectl logs -l app=otel-collector -n observability-lab --tail=20

# Check collector configuration
kubectl get configmap otel-collector -n observability-lab -o yaml

# Test collector endpoints
curl -X POST http://otel-collector.k8s.test:4318/v1/traces -H "Content-Type: application/json" -d '{}'
curl -X POST http://otel-collector.k8s.test:4317/v1/traces -H "Content-Type: application/json" -d '{}'
```

### OTLP Testing
```bash
# Send test spans via OTLP HTTP
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

# Test collector health
curl http://otel-collector.k8s.test:13133/
```

---

## Network and Connectivity

### Service Discovery
```bash
# Check DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki.observability-lab.svc.cluster.local
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup tempo.observability-lab.svc.cluster.local

# Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://loki.observability-lab.svc.cluster.local:3100/ready
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://tempo.observability-lab.svc.cluster.local:3200/ready
```

### Port Forwarding for Local Access
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

### Ingress Testing
```bash
# Test ingress endpoints (if configured)
curl -I http://grafana.k8s.test
curl -I http://loki.k8s.test/ready
curl -I http://tempo.k8s.test/ready
curl -I http://prometheus.k8s.test
curl -I http://otel-collector.k8s.test:4318/v1/traces

# Check ingress configuration
kubectl get ingress -n observability-lab
kubectl describe ingress <ingress-name> -n observability-lab
```

---

## Configuration Verification

### Environment Variables and Secrets
```bash
# Check environment variables for different pods
kubectl get pod loki-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl get pod grafana-<hash> -n observability-lab -o yaml | grep -A 20 "env:"

# Check environment variables in pods
kubectl -n observability-lab exec loki-0 -- env | sort
kubectl -n observability-lab exec tempo-0 -- env | sort

# Check mounted volumes
kubectl get pod loki-0 -n observability-lab -o yaml | grep -A 10 -B 5 "volumeMounts"
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 10 -B 5 "volumeMounts"
```

### Configuration Files
```bash
# Show Loki config file
kubectl -n observability-lab exec loki-0 -- cat /etc/loki/config/config.yaml

# Show Tempo config file
kubectl -n observability-lab exec tempo-0 -- cat /etc/tempo/tempo.yaml

# Show Prometheus config
kubectl -n observability-lab exec prometheus-<hash> -- cat /etc/prometheus/prometheus.yml
```

---

## Performance and Monitoring

### Resource Usage
```bash
# Check resource usage for pods
kubectl top pods -n observability-lab

# Check node resource usage
kubectl top nodes

# Show resource requests and limits
kubectl describe pods -n observability-lab | grep -E "(Requests|Limits)"

# Detailed resource info for specific pod
kubectl describe pod <pod-name> -n observability-lab | grep -A 10 -B 5 -E "(Requests|Limits|Containers)"
```

### PVC Disk Usage
```bash
# Check PVC usage
kubectl get pvc -n observability-lab

# Describe PVCs for details
kubectl describe pvc -n observability-lab

# Check PV disk usage (requires exec into pods)
kubectl -n observability-lab exec loki-0 -- df -h /var/loki
kubectl -n observability-lab exec tempo-0 -- df -h /var/tempo
```

### Application Metrics
```bash
# Check Loki metrics
curl http://loki.k8s.test:3100/metrics | grep loki_

# Check Tempo metrics
curl http://tempo.k8s.test:3200/metrics | grep tempo_

# Check Prometheus targets
curl http://prometheus.k8s.test/api/v1/targets

# Check Grafana health
curl http://grafana.k8s.test/api/health
```

---

## Troubleshooting Playbook

### Common Issues and Solutions

#### 1. Pod not Ready/Running
```bash
# Step 1: Check pod status
kubectl get pods -n observability-lab
kubectl describe pod <pod-name> -n observability-lab

# Step 2: Check events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Step 3: Check logs
kubectl logs <pod-name> -n observability-lab --previous
kubectl logs <pod-name> -n observability-lab
```

#### 2. Service not Accessible
```bash
# Step 1: Check service endpoints
kubectl get endpoints <service-name> -n observability-lab

# Step 2: Test internal connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v http://<service-name>.<namespace>.svc.cluster.local:<port>

# Step 3: Check network policies
kubectl get networkpolicies -n observability-lab
```

#### 3. Storage Issues (Filesystem)
```bash
# Check PVC status
kubectl get pvc -n observability-lab

# Check disk space in pods
kubectl -n observability-lab exec loki-0 -- df -h /var/loki
kubectl -n observability-lab exec tempo-0 -- df -h /var/tempo

# Check for permission issues
kubectl logs -n observability-lab loki-0 | grep -i "permission denied"
kubectl logs -n observability-lab tempo-0 | grep -i "permission denied"
```

#### 4. ArgoCD Sync Issues
```bash
# Step 1: Check application status
kubectl get application observability-stack -n argocd -o yaml

# Step 2: Force refresh and sync
./scripts/force_argo_sync.sh

# Step 3: Check Git connectivity
kubectl get application observability-stack -n argocd -o jsonpath='{.status.conditions}'
```

---

## Useful Shortcuts and Aliases

Add these to your `.zshrc` or `.bashrc`:

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
```

---
