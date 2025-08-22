# Installation Guide

Complete installation instructions for the ObservabilityStack - a **development and learning** environment.

> ⚠️  **Lab Environment**: This setup is optimized for local development, learning, and experimentation. It uses simplified configurations and default credentials that are **not suitable for production** use.

## What You'll Get

A complete observability lab with:
- **Quick Setup**: One-command installation  
- **All-in-One**: Logs, metrics, traces, and visualization
- **S3 Storage**: Persistent data storage with Minio
- **GitOps**: ArgoCD-managed deployments
- **Learning Focus**: Great for understanding observability concepts

## Prerequisites

### 1. Kubernetes Cluster
Ensure you have a running Kubernetes cluster with `kubectl` configured. Grkubeat options for labs:
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
4. Sets up S3 storage backend with Minio

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
- **Loki** - Log aggregation and storage (with S3 backend)  
- **Tempo** - Distributed tracing storage (with S3 backend)
- **Prometheus** - Metrics collection and storage
- **Grafana** - Unified visualization dashboard (pre-configured datasources)
- **Minio** - S3-compatible object storage for persistence

**Lab Features:**
- Default credentials for easy access
- Pre-configured data sources in Grafana
- Sample dashboards and test data
- S3 storage for data persistence across restarts

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
  - **Features**: Pre-configured datasources, sample dashboards
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

# Verify in Grafana
echo "🎯 Open Grafana and check:"
echo "📊 Metrics: Explore → Prometheus → telemetrygen_tests_total"
echo "📝 Logs: Explore → Loki → {job=\"telemetrygen-logs\"}"  
echo "🔍 Traces: Explore → Tempo → {service.name=\"telemetrygen\"}"
```

**Expected Results:**
- Metrics show up in Prometheus datasource
- Logs appear in Loki with test messages
- Traces visible in Tempo with service map
- Data persists in Minio S3 storage

## Troubleshooting Lab Setup

### DNS Not Working?
**Solution 1 - Port Forwarding (Always Works)**
```bash
# Access via localhost ports
kubectl port-forward service/grafana 3000:80 -n observability-lab &
kubectl port-forward service/loki 3100:3100 -n observability-lab &
kubectl port-forward service/prometheus 9090:80 -n observability-lab &
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

### 1. **Explore Grafana**
- Browse pre-configured dashboards
- Try the Explore section for each datasource
- Create your first custom dashboard

### 2. **Send Custom Data**
- Follow [Usage Guide](USAGE_GUIDE.md) to send your own logs, metrics, and traces
- Use the OpenTelemetry Collector endpoints
- Experiment with different data formats

### 3. **Understand the Architecture**
- Explore how data flows through the system
- Check Minio console to see stored data
- Monitor component metrics in Prometheus

### 4. **Experiment and Learn**
- Break things and fix them (it's a lab!)
- Try different configurations in `helm/stackcharts/values.yaml`
- Add your own dashboards and alerts

### Learning Resources
- **[Usage Guide](USAGE_GUIDE.md)** - How to use the stack
- **[Git Workflow](GIT_WORKFLOW.md)** - How to make changes safely
- **OpenTelemetry Documentation** - https://opentelemetry.io/docs/
