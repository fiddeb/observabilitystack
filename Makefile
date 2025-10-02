# Makefile
.PHONY: install sync merge clean status help

help:
	@echo "ObservabilityStack - Available commands:"
	@echo "  make install    - Install ArgoCD and stack"
	@echo "  make sync       - Force ArgoCD sync"
	@echo "  make status     - Show cluster status"
	@echo "  make clean      - Uninstall everything"
	@echo "  make merge      - Merge current feature branch"

install:
	@./scripts/install_argo.sh

sync:
	@./scripts/force_argo_sync.sh

status:
	@kubectl get application observability-stack -n argocd -o wide
	@kubectl get pods -n observability-lab

merge:
	@./scripts/merge_feature.sh $$(git branch --show-current)

clean:
	@echo "Removing observability stack..."
	@kubectl delete application observability-stack -n argocd
	@kubectl delete namespace observability-lab
	@echo "Done!"