# Felsökning och Testkommandon för Observability Stack

Detta dokument samlar alla användbara kommandon för felsökning, testning och verifiering av observability stack-miljön.

## Innehållsförteckning

- [Git och Branch Management](#git-och-branch-management)
- [ArgoCD Operations](#argocd-operations)
- [Kubernetes Debugging](#kubernetes-debugging)
- [Loki Testing och Debugging](#loki-testing-och-debugging)
- [Tempo/Tracing Testing](#tempotrace-testing)
- [Minio S3 Operations](#minio-s3-operations)
- [OpenTelemetry Collector Testing](#opentelemetry-collector-testing)
- [Network och Connectivity](#network-och-connectivity)
- [Configuration Verification](#configuration-verification)
- [Performance och Monitoring](#performance-och-monitoring)

---

## Git och Branch Management

### Branch Information
```bash
# Visa aktuell branch
git rev-parse --abbrev-ref HEAD

# Visa alla branches
git branch -a

# Visa Git status
git status

# Visa ändringar
git diff
git diff --cached

# Visa commit-historik
git log --oneline -10
```

### Feature Branch Workflow
```bash
# Skapa och byt till feature branch
git checkout -b feat/my-feature

# Committa ändringar
git add -A
git commit -m "feat: beskrivning av ändring"

# Merga med vårt script (rekommenderat)
./scripts/merge_feature.sh feat/my-feature

# Manuell merge (med Git hook-skydd)
git checkout main
git merge feat/my-feature
```

---

## ArgoCD Operations

### Application Management
```bash
# Visa ArgoCD applications
kubectl get applications -n argocd

# Visa detaljerad status för vår application
kubectl get application observability-stack -n argocd -o yaml

# Kontrollera targetRevision
kubectl get application observability-stack -n argocd -o jsonpath='{.spec.source.targetRevision}'

# Kontrollera sync och health status
kubectl get application observability-stack -n argocd -o jsonpath='{.status.sync.status}'
kubectl get application observability-stack -n argocd -o jsonpath='{.status.health.status}'
```

### ArgoCD Web Interface Access
```bash
# Hämta admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Port forward till ArgoCD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Skapa ingress för ArgoCD (permanent access)
kubectl apply -f argocd-ingress.yaml

# Kontrollera ArgoCD server status
kubectl get pods -n argocd | grep argocd-server

# Restart ArgoCD server om nödvändigt
kubectl delete pod -l app.kubernetes.io/name=argocd-server -n argocd
```

### Force Sync Operations
```bash
# Vårt automatiska sync-script
./scripts/force_argo_sync.sh

# Manuell refresh
kubectl patch application observability-stack -n argocd -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}' --type=merge

# Manuell sync
kubectl patch application observability-stack -n argocd -p '{"operation":{"sync":{"syncStrategy":{"hook":{}}}}}' --type=merge

# Applicera ArgoCD manifest
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

---

## Kubernetes Debugging

### Pod och Service Information
```bash
# Lista alla pods i observability namespace
kubectl get pods -n observability-lab

# Visa detaljerad pod-info
kubectl get pods -n observability-lab -o wide

# Beskriva specifik pod
kubectl describe pod <pod-name> -n observability-lab

# Visa pod-loggar
kubectl logs <pod-name> -n observability-lab
kubectl logs <pod-name> -n observability-lab --tail=20
kubectl logs <pod-name> -n observability-lab --follow

# Loggar för container i multi-container pod
kubectl logs <pod-name> -c <container-name> -n observability-lab
```

### Services och Endpoints
```bash
# Lista services
kubectl get services -n observability-lab

# Lista endpoints
kubectl get endpoints -n observability-lab

# Visa service detaljer
kubectl describe service <service-name> -n observability-lab
```

### ConfigMaps och Secrets
```bash
# Lista configmaps
kubectl get configmaps -n observability-lab

# Visa configmap innehåll
kubectl get configmap <configmap-name> -n observability-lab -o yaml

# Visa secrets
kubectl get secrets -n observability-lab

# Hämta secret värde (base64 decoded)
kubectl get secret <secret-name> -n observability-lab -o jsonpath='{.data.<key>}' | base64 -d
```

### Resource Debugging
```bash
# Visa alla resurser i namespace
kubectl get all -n observability-lab

# Visa events i namespace
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Kontrollera resource usage
kubectl top pods -n observability-lab
kubectl top nodes
```

---

## Loki Testing och Debugging

### Log Ingestion Testing
```bash
# Skicka testlogg till Loki via API
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

# Flera loggar för chunk-testning
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
}'
```

### Log Querying
```bash
# Använd logcli för att querier loggar
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test-job"}' --limit=100 --since=1h

# Query specifik service
logcli query --addr=http://loki.k8s.test --org-id="foo" '{service_name="test-service"}' --limit=50 --since=30m

# Query med pattern matching
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job=~"test.*"}' --limit=200 --since=2h

# Live tail
logcli query --addr=http://loki.k8s.test --org-id="foo" '{job="test-job"}' --tail --since=1m
```

### Loki Configuration Verification
```bash
# Visa Loki runtime configuration
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/config

# Kontrollera Loki metrics
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/metrics

# Kontrollera Loki ready status
kubectl -n observability-lab exec loki-0 -- wget -qO- http://localhost:3100/ready

# Visa Loki loggar med filtering
kubectl logs loki-0 -n observability-lab --tail=20 | grep -E "(error|warn|chunk|s3|flush)"
kubectl logs loki-0 -n observability-lab --tail=50 | grep -E "(s3|minio|storage)"
```

---

## Tempo/Tracing Testing

### Tempo Configuration
```bash
# Visa Tempo configmap
kubectl get configmap tempo -n observability-lab -o yaml

# Kontrollera Tempo environment variables
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 10 -B 5 "env:"

# Visa Tempo loggar
kubectl logs tempo-0 -n observability-lab --tail=20

# Kontrollera Tempo metrics
kubectl -n observability-lab exec tempo-0 -- wget -qO- http://localhost:3200/metrics
```

### Trace Testing
```bash
# Skicka test trace (OTLP format)
curl -X POST http://tempo.k8s.test:4318/v1/traces \
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

# Kontrollera traces via API
kubectl -n observability-lab exec tempo-0 -- wget -qO- "http://localhost:3200/api/search?q=service.name=test-service"
```

---

## Minio S3 Operations

### Minio Access och Navigation
```bash
# Port forward till Minio console
kubectl port-forward service/minio-console 9090:9090 -n observability-lab &

# Port forward till Minio API
kubectl port-forward service/minio 9000:9000 -n observability-lab &

# Hämta Minio admin password
kubectl get secret minio -n observability-lab -o jsonpath='{.data.root-password}' | base64 -d && echo

# Hämta Minio access key (vanligtvis 'minio')
kubectl get secret minio -n observability-lab -o jsonpath='{.data.root-user}' | base64 -d && echo
```

### MC (Minio Client) Commands
```bash
# Lista Minio pods
kubectl get pods -n observability-lab | grep minio

# Exec into Minio pod för mc commands
kubectl -n observability-lab exec -it <minio-pod-name> -- bash

# Lista buckets
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls local/

# Lista innehåll i Loki chunks bucket
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls local/loki-chunks/

# Lista innehåll i Tempo traces bucket
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls local/tempo-traces/

# Rekursiv listing för att se alla filer
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls --recursive local/loki-chunks/
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls --recursive local/tempo-traces/

# Räkna antal filer i bucket
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls --recursive local/loki-chunks/ | wc -l

# Visa detaljer för specifik fil
kubectl -n observability-lab exec -it <minio-pod-name> -- mc stat local/loki-chunks/<file-path>

# Kopiera fil från bucket (för inspektion)
kubectl -n observability-lab exec -it <minio-pod-name> -- mc cp local/loki-chunks/<file-path> /tmp/

# Visa bucket policy
kubectl -n observability-lab exec -it <minio-pod-name> -- mc policy get local/loki-chunks/
```

---

## OpenTelemetry Collector Testing

### Collector Status
```bash
# Visa OpenTelemetry Collector loggar
kubectl logs -l app=otel-collector -n observability-lab --tail=20

# Kontrollera collector configuration
kubectl get configmap otel-collector -n observability-lab -o yaml

# Testa collector endpoints
curl -X POST http://otel-collector.k8s.test:4318/v1/traces -H "Content-Type: application/json" -d '{}'
curl -X POST http://otel-collector.k8s.test:4317/v1/traces -H "Content-Type: application/json" -d '{}'
```

### OTLP Testing
```bash
# Skicka test spans via OTLP HTTP
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

# Testa collector health
curl http://otel-collector.k8s.test:13133/
```

---

## Network och Connectivity

### Service Discovery
```bash
# Kontrollera DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup loki.observability-lab.svc.cluster.local
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup tempo.observability-lab.svc.cluster.local
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup minio.observability-lab.svc.cluster.local

# Testa intern connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://loki.observability-lab.svc.cluster.local:3100/ready
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -I http://tempo.observability-lab.svc.cluster.local:3200/ready
```

### Port Forwarding för Lokal Access
```bash
# Loki
kubectl port-forward service/loki 3100:3100 -n observability-lab &

# Grafana  
kubectl port-forward service/grafana 3000:80 -n observability-lab &

# Prometheus
kubectl port-forward service/prometheus 9090:80 -n observability-lab &

# Tempo
kubectl port-forward service/tempo 3200:3200 -n observability-lab &

# Minio Console
kubectl port-forward service/minio-console 9090:9090 -n observability-lab &

# Minio API
kubectl port-forward service/minio 9000:9000 -n observability-lab &

# Lista aktiva port forwards
ps aux | grep "kubectl port-forward"

# Stoppa alla port forwards
pkill -f "kubectl port-forward"
```

### Ingress Testing
```bash
# Testa ingress endpoints (om konfigurerade)
curl -I http://grafana.k8s.test
curl -I http://loki.k8s.test/ready
curl -I http://tempo.k8s.test/ready
curl -I http://prometheus.k8s.test
curl -I http://otel-collector.k8s.test:4318/v1/traces

# Kontrollera ingress configuration
kubectl get ingress -n observability-lab
kubectl describe ingress <ingress-name> -n observability-lab
```

---

## Configuration Verification

### Environment Variables och Secrets
```bash
# Kontrollera environment variables för olika pods
kubectl get pod loki-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 20 "env:"
kubectl get pod grafana-<hash> -n observability-lab -o yaml | grep -A 20 "env:"

# Verifiera S3 credentials i pods
kubectl -n observability-lab exec loki-0 -- env | grep -E "(MINIO|S3|AWS)"
kubectl -n observability-lab exec tempo-0 -- env | grep -E "(MINIO|S3|AWS)"

# Kontrollera mounted volumes
kubectl get pod loki-0 -n observability-lab -o yaml | grep -A 10 -B 5 "volumeMounts"
kubectl get pod tempo-0 -n observability-lab -o yaml | grep -A 10 -B 5 "volumeMounts"
```

### Configuration Files
```bash
# Visa Loki config fil
kubectl -n observability-lab exec loki-0 -- cat /etc/loki/config/config.yaml

# Visa Tempo config fil  
kubectl -n observability-lab exec tempo-0 -- cat /etc/tempo/tempo.yaml

# Visa Prometheus config
kubectl -n observability-lab exec prometheus-<hash> -- cat /etc/prometheus/prometheus.yml
```

---

## Performance och Monitoring

### Resource Usage
```bash
# Kontrollera resource usage för pods
kubectl top pods -n observability-lab

# Kontrollera node resource usage
kubectl top nodes

# Visa resource requests och limits
kubectl describe pods -n observability-lab | grep -E "(Requests|Limits)"

# Detaljerad resource info för specifik pod
kubectl describe pod <pod-name> -n observability-lab | grep -A 10 -B 5 -E "(Requests|Limits|Containers)"
```

### Disk Usage (Minio S3)
```bash
# Kontrollera bucket storlek
kubectl -n observability-lab exec -it <minio-pod-name> -- mc du local/loki-chunks/
kubectl -n observability-lab exec -it <minio-pod-name> -- mc du local/tempo-traces/

# Lista stora filer
kubectl -n observability-lab exec -it <minio-pod-name> -- mc ls --recursive local/loki-chunks/ | sort -k3 -h

# Disk usage för Minio pod
kubectl -n observability-lab exec <minio-pod-name> -- df -h
```

### Application Metrics
```bash
# Kontrollera Loki metrics
curl http://loki.k8s.test:3100/metrics | grep loki_

# Kontrollera Tempo metrics  
curl http://tempo.k8s.test:3200/metrics | grep tempo_

# Kontrollera Prometheus targets
curl http://prometheus.k8s.test/api/v1/targets

# Kontrollera Grafana health
curl http://grafana.k8s.test/api/health
```

---

## Troubleshooting Playbook

### Common Issues och Solutions

#### 1. Pod inte Ready/Running
```bash
# Steg 1: Kontrollera pod status
kubectl get pods -n observability-lab
kubectl describe pod <pod-name> -n observability-lab

# Steg 2: Kontrollera events
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp

# Steg 3: Kontrollera loggar
kubectl logs <pod-name> -n observability-lab --previous
kubectl logs <pod-name> -n observability-lab
```

#### 2. Service inte Accessible
```bash
# Steg 1: Kontrollera service endpoints
kubectl get endpoints <service-name> -n observability-lab

# Steg 2: Testa intern connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- curl -v http://<service-name>.<namespace>.svc.cluster.local:<port>

# Steg 3: Kontrollera network policies
kubectl get networkpolicies -n observability-lab
```

#### 3. S3/Minio Issues
```bash
# Steg 1: Kontrollera Minio pod status
kubectl get pods -n observability-lab | grep minio
kubectl logs <minio-pod-name> -n observability-lab

# Steg 2: Testa S3 connectivity från pod
kubectl -n observability-lab exec loki-0 -- wget -qO- http://minio:9000/minio/health/live

# Steg 3: Kontrollera S3 credentials
kubectl get secret minio -n observability-lab -o yaml
```

#### 4. ArgoCD Sync Issues
```bash
# Steg 1: Kontrollera application status
kubectl get application observability-stack -n argocd -o yaml

# Steg 2: Force refresh och sync
./scripts/force_argo_sync.sh

# Steg 3: Kontrollera Git connectivity
kubectl get application observability-stack -n argocd -o jsonpath='{.status.conditions}'
```

---

## Användbar Shortcuts och Aliases

Lägg till dessa i din `.zshrc` eller `.bashrc`:

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
alias pf-minio='kubectl port-forward service/minio-console 9090:9090 -n observability-lab &'
```

---

*Dokumentet uppdaterat: $(date)*
*Alla kommandon testade mot observabilitystack miljön*
