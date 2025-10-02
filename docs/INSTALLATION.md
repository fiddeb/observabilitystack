# Installation Guide

Complete installation instructions for the ObservabilityStack - a **development and learning** environment.

> **New to the Stack?** Read the [Architecture Guide](ARCHITECTURE.md) first to understand the design decisions and configuration patterns.

> **Lab Environment**: This setup is optimized for local development, learning, and experimentation. It uses simplified configurations and default credentials that are **not suitable for production** use.

## What You'll Get

A complete observability lab with:
- **Quick Setup**: One-command installation  
- **All-in-One**: Logs, metrics, traces, and visualization
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
#### Option 2: dnsmasq (Recommended for Labs)
Set up wildcard DNS resolution for `*.k8s.test` domains:

##### macOS Setup

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

# Verify DNS resolution
dig grafana.k8s.test @127.0.0.1
```

##### Linux Setup

**Ubuntu/Debian:**
```bash
# Install dnsmasq
sudo apt-get update
sudo apt-get install -y dnsmasq

# Configure dnsmasq for wildcard resolution
echo "listen-address=127.0.0.1" | sudo tee -a /etc/dnsmasq.conf
echo "bind-interfaces" | sudo tee -a /etc/dnsmasq.conf
echo "address=/.k8s.test/127.0.0.1" | sudo tee -a /etc/dnsmasq.conf

# Configure NetworkManager to use dnsmasq
echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf

# Restart services
sudo systemctl restart dnsmasq
sudo systemctl restart NetworkManager

# Verify DNS resolution
dig grafana.k8s.test @127.0.0.1
```

**Fedora/RHEL/CentOS:**
```bash
# Install dnsmasq
sudo dnf install -y dnsmasq  # or: sudo yum install -y dnsmasq

# Configure dnsmasq for wildcard resolution
echo "listen-address=127.0.0.1" | sudo tee -a /etc/dnsmasq.conf
echo "bind-interfaces" | sudo tee -a /etc/dnsmasq.conf
echo "address=/.k8s.test/127.0.0.1" | sudo tee -a /etc/dnsmasq.conf

# Configure NetworkManager to use dnsmasq
echo -e "[main]\ndns=dnsmasq" | sudo tee /etc/NetworkManager/conf.d/dnsmasq.conf

# Restart services
sudo systemctl restart dnsmasq
sudo systemctl restart NetworkManager

# Verify DNS resolution
dig grafana.k8s.test @127.0.0.1
```

##### Windows Setup

**Windows users:** Use Option 1 (static hosts file) at `C:\Windows\System32\drivers\etc\hosts` (requires admin privileges). Wildcard DNS setup on Windows requires more complex configurations beyond the scope of this lab.


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

### Fork the Repository (Recommended)

**Important**: If you plan to make changes to the configuration or experiment with customizations, create a fork first:

1. **Fork the repository** on GitHub:
   - Go to https://github.com/fiddeb/observabilitystack
   - Click the "Fork" button in the top-right corner
   - This creates your own copy that you can modify

2. **Clone your fork** (replace `YOUR_USERNAME` with your GitHub username):
   ```bash
   git clone https://github.com/YOUR_USERNAME/observabilitystack.git
   cd observabilitystack
   ```

3. **Add upstream remote** (to get updates from the original repo):
   ```bash
   git remote add upstream https://github.com/fiddeb/observabilitystack.git
   ```
   This creates a connection to the original repository so you can pull in updates and new features later.

**Why fork?**
- **Customization**: Modify configurations for your specific needs
- **Learning**: Experiment with changes without affecting the original
- **Contributions**: Create pull requests to contribute improvements
- **GitOps**: ArgoCD can monitor your fork for automatic deployments

### Quick Lab Setup
The fastest way to get your observability lab running:

```bash
# Clone the repository (or your fork - see above)
git clone https://github.com/fiddeb/observabilitystack.git
cd observabilitystack

# Setup ArgoCD application (automatically detects your repository)
./scripts/setup_argocd.sh

# One-command installation
./scripts/install_argo.sh
```

**What happens:**
1. Updates Helm chart dependencies (downloads required charts)
2. Installs ArgoCD in your cluster
3. Configures ArgoCD for HTTP access (insecure mode)
4. Installs ArgoCD ingress for web access
5. Deploys the complete observability stack
6. Configures all components with lab-friendly defaults
7. Sets up local filesystem storage for persistence

**Time:** ~5-10 minutes for complete deployment

**After installation, ArgoCD is immediately accessible at:**
- **URL:** http://argocd.k8s.test
- **Username:** admin  
- **Password:** `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`

## ArgoCD Management Interface

ArgoCD provides a web interface to monitor and manage your deployments.

### Access ArgoCD Web UI

ArgoCD ingress is automatically installed and configured during setup.

#### Primary Access (Recommended)
```bash
# Access ArgoCD via ingress
open http://argocd.k8s.test

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo
```

**Login credentials:**
- **Username:** admin
- **Password:** (from command above)

#### Backup Access (Port Forwarding)
If DNS/ingress doesn't work, use port forwarding:

```bash
# Forward ArgoCD server to local port
kubectl port-forward svc/argocd-server -n argocd 8080:80 &

# Access: http://localhost:8080
# Username: admin
# Password: (same as above)
```

### ArgoCD Configuration

The installation script automatically configures ArgoCD with:
- **HTTP access** (insecure mode for lab use)
- **Ingress setup** for web access via http://argocd.k8s.test
- **Observability stack application** for GitOps management

#### Get ArgoCD Credentials
```bash
# Username is always: admin

# Get password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d && echo

# Optional: Change admin password via CLI
argocd account update-password --current-password <current-admin-password> --new-password <new-password>
```

### Using Your Fork with ArgoCD

If you forked the repository, the setup automatically detects your repository URL:

```bash
# Setup ArgoCD application with correct repository (automatically detects fork)
./scripts/setup_argocd.sh
```

**What this script does:**
- Automatically detects your git remote URL (original repo or fork)
- Updates the ArgoCD application manifest with the correct `repoURL`
- Applies the configuration to your cluster
- Works with both HTTPS and SSH git URLs

**When to run this script:**
- **Before installing ArgoCD** - Sets up the correct repository URL from the start
- **After forking** - Updates the configuration to use your fork instead of the original
- **When switching between repositories** - If you change your git remote URL
- **After cloning a different fork** - Automatically adapts to the new repository

**How to run:**
```bash
# From project root directory (recommended)
./scripts/setup_argocd.sh

# Or from any directory within the project
cd scripts && ./setup_argocd.sh
cd /path/to/project && ./scripts/setup_argocd.sh
```

**Prerequisites:**
- Must be run from within the git repository
- Git remote 'origin' must be configured
- kubectl access to your cluster (optional - for automatic application)

**Manual method** (if you prefer to edit manually):
```bash
# Edit the ArgoCD application manifest
vim argocd/observability-stack.yaml

# Change the repoURL to your fork:
# spec:
#   source:
#     repoURL: https://github.com/YOUR_USERNAME/observabilitystack.git

# Apply the updated application
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

This allows ArgoCD to automatically sync changes from your fork when you push updates.

### Manual ArgoCD Setup
If you prefer manual setup:

```bash
# Update Helm dependencies first
cd helm/stackcharts
helm dependency update
cd ../..

# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Create the observability application (use your fork if you have one)
kubectl apply -f argocd/observability-stack.yaml -n argocd
```

### Updating Helm Dependencies

If you need to update chart dependencies manually:

```bash
cd helm/stackcharts
helm dependency update
```

This downloads the required Helm charts specified in `Chart.yaml`:
- Grafana, Loki, Tempo, Prometheus
- OpenTelemetry Collector
- Minio (disabled by default)

The downloaded charts are saved in `charts/` directory and committed to the repository for reproducible builds.

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

> **First Visit**: Start with Grafana to explore the pre-configured dashboards, then check ArgoCD to see how GitOps deployment works

### Test Your Lab Setup
Verify everything works with built-in tests:

```bash
# Run automated test suite
kubectl apply -f manifests/telemetry-test-jobs.yaml

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

> **Multi-Tenant Testing**: Test both Loki datasources in Grafana to see tenant isolation in action. Send logs with `dev.audit.category` attribute to see automatic routing to the bazz tenant.

## Troubleshooting Lab Setup

### Repository Setup Issues?

**Error: "No such file or directory: argocd/observability-stack.yaml"**
```bash
# Make sure you're in the project root directory
cd /path/to/observabilitystack
./scripts/setup_argocd.sh
```

**Error: "No git remote 'origin' found"**
```bash
# Add git remote if missing
git remote add origin https://github.com/YOUR_USERNAME/observabilitystack.git

# Or check existing remotes
git remote -v
```

**Script detects wrong repository**
```bash
# Check your git remote
git remote get-url origin

# Update to your fork if needed
git remote set-url origin https://github.com/YOUR_USERNAME/observabilitystack.git

# Run setup script again
./scripts/setup_argocd.sh
```

**ArgoCD application not updating**
```bash
# Force refresh in ArgoCD UI or CLI
kubectl patch app observability-stack -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'

# Or delete and recreate
kubectl delete app observability-stack -n argocd
./scripts/setup_argocd.sh
```

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

### **Understand the Architecture**
- **[Architecture Guide](ARCHITECTURE.md)** - **Why** the stack is built this way and **how** to customize it

### **Send Custom Data**
- Follow [Usage Guide](USAGE_GUIDE.md) to send your own logs, metrics, and traces
- Use the OpenTelemetry Collector endpoints

### **Customize Your Setup**
- See [Architecture Guide - Customization](ARCHITECTURE.md#customization-guide) for configuration patterns
- Learn about the single `values.yaml` approach and multi-tenant setup

### Learning Resources
- **[Usage Guide](USAGE_GUIDE.md)** - How to use the stack
- **[Git Workflow](GIT_WORKFLOW.md)** - How to make changes safely
- **OpenTelemetry Documentation** - https://opentelemetry.io/docs/
