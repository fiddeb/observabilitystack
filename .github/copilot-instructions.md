Project Overview

ObservabilityStack is a minimal, local-friendly observability lab using OpenTelemetry, Grafana, Loki, Prometheus, and Tempo. It targets quick experimentation on a single-node Kubernetes cluster with simple ingress via Traefik.
	•	Telemetry: OTLP (logs/metrics/traces) via OpenTelemetry Collector
	•	Visualization: Grafana (anonymous access by default)
	•	Logs: Loki (multi-tenant capable)
	•	Metrics: Prometheus (scrape + alerting)
	•	Traces: Tempo (distributed tracing backend)
	•	Ingress: Traefik (installed manually)

⸻

Folder Structure

This repo is small by design. If some folders are not present yet, treat them as recommendations.

    •	/scripts: helper scripts (e.g., [`install_argo.sh`](scripts/install_argo.sh) for ArgoCD bootstrap, [`force_argo_sync.sh`](scripts/force_argo_sync.sh) for manual syncing)
    •	/helm: Helm charts and values organized by component
        ◦	/helm/stackcharts: umbrella chart for the entire observability stack
            - [`Chart.yaml`](helm/stackcharts/Chart.yaml): Chart dependencies and versions
            - [`values/`](helm/stackcharts/values/): Split configuration files (one per component)
                - `base.yaml`: Component enable/disable flags
                - `loki.yaml`, `tempo.yaml`, `prometheus.yaml`, `grafana.yaml`, etc.: Component-specific configurations
            - [`charts/`](helm/stackcharts/charts/): Downloaded dependency charts (.tgz files)
    •	/argocd: ArgoCD application manifests ([`observability-stack.yaml`](argocd/observability-stack.yaml) for GitOps deployment with multi-values support)
    •	/app: demo applications with telemetry instrumentation
    •	/metrics: collected metrics and monitoring data
    •	/docs: comprehensive documentation
        ◦	[`ARCHITECTURE.md`](docs/ARCHITECTURE.md): Umbrella chart pattern, multi-values configuration, and design decisions
        ◦	[`INSTALLATION.md`](docs/INSTALLATION.md): Complete setup instructions
        ◦	[`USAGE_GUIDE.md`](docs/USAGE_GUIDE.md): How to use the system
        ◦	[`TROUBLESHOOTING.md`](docs/TROUBLESHOOTING.md): Emergency procedures, debugging, and complete command reference
        ◦	[`GIT_WORKFLOW.md`](docs/GIT_WORKFLOW.md): Git and development workflow guidelines
    •	/dashboards (optional): Grafana dashboard JSON models and provisioning
    •	/manifests: Kubernetes manifests (ArgoCD ingress, test jobs)
    •	project root: [`README.md`](README.md), [`LICENSE`](LICENSE)

⸻

Libraries and Frameworks
	•	Kubernetes (local cluster such as Rancher Desktop/minikube/k3d)
	•	Helm for chart-based installs
	•	OpenTelemetry Collector for telemetry pipelines
	•	Grafana, Loki, Prometheus, Tempo (Grafana Labs ecosystem)
	•	Traefik (Ingress Controller)

⸻

Platform Support
	•	Primary: macOS and Linux (fully documented and tested)
	•	Limited: Windows (basic guidance only - static hosts file approach)
	•	Note: Project maintainer has deep experience with macOS/Linux; Windows support is minimal and community-driven

⸻

Coding Standards
	•	Shell (bash): POSIX-ish, set -Eeuo pipefail; echo intent before actions
	•	YAML: 2-space indent, comment non-defaults, prefer small diffs; keep overrides in separate files (e.g., *-local.yaml)
	•	Commits: Semantic Commit Messages style eg feat: add hat wobble
	•	Safety: use dry-runs by default (helm upgrade --install --dry-run --debug, kubectl apply --server-side --dry-run=client)
	•	Prefer git add -u befor git add . if files only updates, and use git add filname if new file etc.

⸻

Documentation Standards

	•	Structure: Use clear, hierarchical organization with consistent markdown formatting
	•	Language: Write in clear, concise English or Swedish as appropriate for the target audience
	•	Code examples: Always include working, tested command examples with expected output
	•	File organization:
		◦	/docs/INSTALLATION.md: Complete setup instructions from zero to working system
		◦	/docs/USAGE_GUIDE.md: How to use the system once installed
		◦	/docs/TROUBLESHOOTING.md: Emergency procedures, debugging, and complete command reference
		◦	/docs/GIT_WORKFLOW.md: Git and development workflow guidelines
	•	Cross-references: Always link between related documentation sections
	•	Verification: Include verification steps and expected results for all procedures
	•	Updates: Keep documentation current with code changes; update docs in same PR as feature changes

Emoji Usage Policy

	•	Functional only: Use emojis exclusively when they serve a clear functional purpose
	•	Approved contexts:
		◦	Status indicators: ✅ ❌ ⚠️ 🔄 (success, failure, warning, in-progress)
		◦	Alert levels: ⚠️ 💡 (critical, warning, information)
	•	Prohibited: Decorative or casual emojis that don't add functional value
	•	Consistency: Use the same emoji for the same meaning across all documentation
	•	Accessibility: Always pair emojis with clear text that conveys the same meaning

Branching Policy

	 •  No direct commits to `main` are allowed.
		 - All feature, fix, and experiment work MUST be done in feature branches.
		 - Branch naming: `feat/`, `fix/`, `chore/`, `docs/` prefixes recommended (e.g., `feat/add-otel-collector`).
		 - Create a Pull Request targeting `main` and require at least one reviewer before merge.
		 - Ensure CI checks pass and any required approvals are completed before merging.
		 - Use protected branch rules in the Git provider to enforce this policy.

	 •  Emergency fixes to `main` are only permitted via a review-approved fast-forward or a revert+PR workflow; coordinate with the team and document the reason in the PR.

⸻

Operations Guidelines
	•	Install (GitOps): ./scripts/install_argo.sh - installs ArgoCD and deploys the complete observability stack
	•	Manual sync: ./scripts/force_argo_sync.sh - forces ArgoCD to sync changes from Git
	•	Ingress/Hosts: configure dnsmasq for wildcard DNS resolution (see docs/INSTALLATION.md for platform-specific instructions):
		◦	macOS: address=/.k8s.test/127.0.0.1 in /opt/homebrew/etc/dnsmasq.conf + /etc/resolver/k8s.test
		◦	Linux: address=/.k8s.test/127.0.0.1 in /etc/dnsmasq.conf + NetworkManager/systemd-resolved integration
		◦	Windows: Use static hosts file (wildcard DNS not supported in lab setup)
	•	Access:
	•	Grafana: http://grafana.k8s.test (anonymous by default). To enable login, set in grafana_values.yaml:

grafana.ini:
  auth:
    disable_login: false
  auth.anonymous:
    enabled: false


	•	Loki: http://loki.k8s.test (supports multi-tenancy via X-Scope-OrgId)
	•	OTel Collector: http://otel.k8s.test (configure receivers/exporters in opentelemetry_values.yaml)

⸻

UI/Dashboard Guidelines
	•	Keep Grafana dashboards minimal and focused on smoke tests (one panel per signal type).
	•	Provision datasources via grafana_values.yaml; avoid manual setup drift.
	•	Prefer dashboard JSON in /dashboards and auto-provision them.

⸻

Quick Smoke Tests
	•	Push a test log to Loki (tenant foo) and verify with logcli:

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



⸻

Troubleshooting (Shortlist)
	•	Ingress not routing → check Traefik install and Ingress objects
	•	Grafana empty → verify datasource provisioning and service URLs
	•	No logs/metrics/traces → check OTel pipelines, exporter endpoints, and component pod logs

⸻

Design Notes
	•	Minimal footprint and fast setup for local experimentation
	•	Keep risky changes behind *-local.yaml overrides
	•	Prefer small, well-explained PRs with a short test plan

⸻

Documentation Maintenance

	•	Accuracy: All documented commands must be tested and verified to work
	•	Completeness: Every feature and configuration change requires corresponding documentation updates
	•	Target audience: Documentation should be accessible to developers setting up their first observability lab
	•	Real-world testing: Include common error scenarios and their solutions
	•	Version compatibility: Document which versions of tools/charts are tested and supported
	•	Cleanup: Remove outdated or obsolete documentation promptly; maintain a clean information architecture

