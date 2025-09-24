# Installation Guide

Complete installation instructions for the ObservabilityStack - a **development and learning** environment.

> ⚠️  **Lab Environment**: This setup is optimized for local development, learning, and experimentation. It uses simplified configurations and default credentials that are **not suitable for production** use.

## What You'll Get

A complete observability lab with:
- **Quick Setup**: One-command installation  
- **All-in-One**: Logs, metrics, traces, and visualization
- **Local Storage**: Persistent data storage with filesystem
- **GitOps**: ArgoCD-managed deployments

## Prerequisites

### 1. Kubernetes Cluster
Ensure you have a running Kubernetes cluster with `kubectl` configured:
- **Rancher Desktop** (easiest for local development)
- **Minikube** 
- **k3s/k3d** (lightweight)

### 2. Ingress Controller
Install Traefik as the ingress controller:

```bash
# Add Traefik helm repository
helm repo add traefik https://helm.traefik.io/traefik
helm repo update

# Install Traefik
helm install traefik traefik/traefik
```

### 3. DNS Configuration for Local Access

For the best lab experience, configure local DNS to access services via friendly URLs like `grafana.k8s.test`.

#### Option 1: Static Hosts File (Simple)
Add these entries to your `/etc/hosts` file:

```bash
# Add to /etc/hosts
127.0.0.1 grafana.k8s.test
127.0.0.1 loki.k8s.test  
127.0.0.1 tempo.k8s.test
127.0.0.1 prometheus.k8s.test
127.0.0.1 otel-collector.k8s.test
127.0.0.1 argocd.k8s.test
```

**Pros**: Simple, no additional tools needed  
**Cons**: Must manually add each subdomain

#### Option 2: dnsmasq (Recommended for Labs)
Set up wildcard DNS resolution for `*.k8s.test` domains:

```bash
# Install dnsmasq (macOS with Homebrew)
brew install dnsmasq

# Configure dnsmasq for wildcard resolution
echo "listen-address=127.0.0.1" >> /opt/homebrew/etc/dnsmasq.conf
echo "bind-interfaces" >> /opt/homebrew/etc/dnsmasq.conf  
echo "address=/.k8s.test/127.0.0.1" >> /opt/homebrew/etc/dnsmasq.conf

# Setup system resolver
sudo mkdir -p /etc/resolver
echo "nameserver 127.0.0.1" | sudo tee /etc/resolver/k8s.test

# Start dnsmasq
sudo brew services start dnsmasq
```

**Pros**: Automatic resolution for any `*.k8s.test` subdomain  
**Cons**: Requires additional setup

#### Option 3: No DNS (Port Forwarding Only)
If you prefer not to configure DNS, you can access everything via port forwarding (see Troubleshooting section).

### 4. Resource Requirements

**Minimum Requirements:**
- **CPU:** 2 cores (recommended: 4 cores)
- **Memory:** 4GB RAM (recommended: 8GB RAM)
- **Storage:** 10GB available disk space

**Resource Optimization:**
The stack is optimized for development environments:
- **Loki:** 200m CPU request, 500m CPU limit, 512Mi-1Gi memory
- **Prometheus:** Default resource limits  
- **Grafana:** Minimal resource usage
- **OpenTelemetry Collector:** 100m CPU, 128Mi memory



## Installation

### Quick Lab Setup
The fastest way to get your observability lab running:

```bash
# Clone the repository
git clone https://github.com/fiddeb/observabilitystack.git
cd observabilitystack

# One-command installation
./scripts/install_argo.sh
```

**What happens:**
1. Installs ArgoCD in your cluster
2. Deploys the complete observability stack
3. Configures all components with lab-friendly defaults
4. Sets up local filesystem storage for persistence

**Time:** ~5-10 minutes for complete deployment

## ArgoCD Management Interface

ArgoCD provides a web interface to monitor and manage your deployments.

### Access ArgoCD Web UI

#### Option 1: Port Forwarding (Quick Access)
```bash
# Forward ArgoCD server to local port
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Access: https://localhost:8080
# Username: admin
# Password: (from command above)
```

#### Option 2: Ingress Setup (Recommended for Labs)
Add ArgoCD to your DNS configuration and create an ingress:

```bash
# Add to /etc/hosts (if using static hosts)
echo "127.0.0.1 argocd.k8s.test" | sudo tee -a /etc/hosts

# Or for dnsmasq users, ArgoCD will automatically resolve via *.k8s.test
```

Create ArgoCD ingress:
```bash
# Create argocd-ingress.yaml
cat <<EOF > argocd-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argocd
  annotations:
    traefik.ingress.kubernetes.io/router.tls: "false"
    nginx.ingress.kubernetes.io/ssl-redirect: "false"
    nginx.ingress.kubernetes.io/force-ssl-redirect: "false"
spec:
  rules:
  - host: argocd.k8s.test
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80
EOF

# Apply the ingress
kubectl apply -f argocd-ingress.yaml

# Access: http://argocd.k8s.test
```

#### Get ArgoCD Credentials
```bash
# Username is always: admin

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Optional: Change admin password via CLI
argocd account update-password --current-password <current-admin-password> --new-password <new-password>
```

### Manual ArgoCD Setup
If you prefer manual setup:

```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create the observability application
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

## Lab Components

The installation deploys a complete observability stack:

- **OpenTelemetry Collector** - Central telemetry ingestion point
- **Loki** - Log aggregation and storage (with local filesystem)
- **Tempo** - Distributed tracing storage (with local filesystem) 
- **Prometheus** - Metrics collection and storage
- **Grafana** - Unified visualization dashboard (pre-configured datasources)

**Lab Features:**
- Default credentials for easy access
- Pre-configured data sources in Grafana
- Local filesystem storage for data persistence across restarts
- Simplified setup without S3 complexity

## Verification

### Check Deployment Status
```bash
# Verify all pods are running
kubectl get pods -n observability-lab

# Check ArgoCD application status
kubectl get application observability-stack -n argocd
```

### Access Your Lab Environment
After installation, your observability lab is available at:

- **Grafana** (Main Dashboard): http://grafana.k8s.test 
  - **Credentials**: admin/admin (default lab credentials)
  - **Features**: Pre-configured datasources with multi-tenant support, sample dashboards
  - **Data Sources**: Prometheus, Loki (foo tenant), Loki (bazz tenant), Tempo
- **ArgoCD** (GitOps Management): http://argocd.k8s.test
  - **Username**: admin
  - **Password**: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
  - **Features**: Monitor deployments, sync applications, view Git integration
- **Prometheus** (Metrics): http://prometheus.k8s.test  
- **Loki** (Logs): http://loki.k8s.test
- **Tempo** (Traces): http://tempo.k8s.test
- **OpenTelemetry Collector**: http://otel-collector.k8s.test

> 💡 **First Visit**: Start with Grafana to explore the pre-configured dashboards, then check ArgoCD to see how GitOps deployment works

### Test Your Lab Setup
Verify everything works with built-in tests:

```bash
# Run automated test suite
kubectl apply -f telemetry-test-jobs.yaml

# Wait for tests to complete (~30 seconds)
kubectl wait --for=condition=complete job/telemetrygen-metrics -n observability-lab --timeout=60s
kubectl wait --for=condition=complete job/telemetrygen-logs -n observability-lab --timeout=60s
kubectl wait --for=condition=complete job/telemetrygen-traces -n observability-lab --timeout=60s
```
# Verify in Grafana
Open Grafana and check:
- **Metrics**: Explore → Prometheus → `telemetrygen_tests_total`
- **Logs (foo tenant)**: Explore → Loki → `{job="telemetrygen"}`
- **Logs (bazz tenant)**: Explore → Loki-bazz → `{job="audit-logs"}` 
- **Traces**: Explore → Tempo → `{service.name="telemetrygen"}`

> 🔍 **Multi-Tenant Testing**: Test both Loki datasources in Grafana to see tenant isolation in action. Send logs with `dev.audit.category` attribute to see automatic routing to the bazz tenant.

## Troubleshooting Lab Setup

### DNS Not Working?
**Solution 1 - Port Forwarding (Always Works)**
```bash
# Access via localhost ports
kubectl port-forward service/grafana 3000:3000 -n observability-lab &
kubectl port-forward service/loki 3100:3100 -n observability-lab &
kubectl port-forward service/prometheus 9090:9090 -n observability-lab &
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

# Access at:
# - Grafana: http://localhost:3000
# - Loki: http://localhost:3100  
# - Prometheus: http://localhost:9090
# - ArgoCD: https://localhost:8080 (admin/<get-password>)
```

**Get ArgoCD Password:**
```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Solution 2 - Check DNS Configuration**
```bash
# Test DNS resolution
nslookup grafana.k8s.test

# If using dnsmasq, restart it
sudo brew services restart dnsmasq

# If using /etc/hosts, verify entries
cat /etc/hosts | grep k8s.test
```

### Pods Not Starting?
```bash
# Quick health check
./scripts/force_argo_sync.sh

# Check pod status
kubectl get pods -n observability-lab

# Check events for errors
kubectl get events -n observability-lab --sort-by=.metadata.creationTimestamp | tail -10
```

### Need More Help?
- **[Quick Troubleshooting Guide](QUICK_TROUBLESHOOTING.md)** - Emergency procedures
- **[Complete Command Reference](TROUBLESHOOTING_COMMANDS.md)** - All debugging commands

## Next Steps - Start Learning!

### **Send Custom Data**
- Follow [Usage Guide](USAGE_GUIDE.md) to send your own logs, metrics, and traces
- Use the OpenTelemetry Collector endpoints

### Learning Resources
- **[Usage Guide](USAGE_GUIDE.md)** - How to use the stack
- **[Git Workflow](GIT_WORKFLOW.md)** - How to make changes safely
- **OpenTelemetry Documentation** - https://opentelemetry.io/docs/
