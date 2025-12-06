include bootstrap.env

SCRIPTS_DIR := scripts
CERTS_DIR := certs
DEFAULTS_DIR := defaults
CLUSTER_DIR := cluster
TOOLS_DIR := tools

.DEFAULT_GOAL := install

.PHONY: help gitlab velero argocd prepare check bootstrap delete tls monitoring velero-clean lint print-config
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

prepare: ## Install binary prerequisites
	@$(SCRIPTS_DIR)/install-prerequisites.sh

check: prepare ## Check for required tools
	@$(SCRIPTS_DIR)/check-requirements.sh

install: check ## Run full bootstrap workflow
	@$(SCRIPTS_DIR)/bootstrap.sh

delete: ## Delete the cluster
	@kind delete cluster --name $(CLUSTER_NAME)

tls: ## Regenerate mkcert TLS
	@$(CERTS_DIR)/install.sh

gitlab: ## Install/Reinstall Gitlab instance
	@$(SCRIPTS_DIR)/install-gitlab.sh

velero: ## Install Velero server
	@$(SCRIPTS_DIR)/install-velero.sh

argocd: ## Install ArgoCD
	@$(SCRIPTS_DIR)/install-argocd.sh

monitoring: ## Install Prometheus and Grafana monitoring stack
	@$(SCRIPTS_DIR)/install-monitoring.sh

velero-clean: ## Uninstall Velero and MinIO
	@helm uninstall velero -n velero || true
	@helm uninstall minio -n minio || true
	@kubectl delete pvc --all -n minio || true

lint: ## Lint shell scripts (requires shellcheck)
	@if command -v shellcheck >/dev/null 2>&1; then \
	  echo "[+] Running shellcheck..."; \
	  shellcheck -x $(SCRIPTS_DIR)/*.sh $(CERTS_DIR)/install.sh; \
	else \
	  echo "[WARN] shellcheck not found. Install it to lint scripts (e.g., apt install -y shellcheck)"; \
	fi

print-config: ## Show effective configuration from bootstrap.env
	@echo "K8S_VERSION=$(K8S_VERSION)"; \
	echo "CLUSTER_NAME=$(CLUSTER_NAME)"; \
	echo "DOMAIN=$(DOMAIN)"; \
	echo "CLUSTER_ISSUER_NAME=$(CLUSTER_ISSUER_NAME)"; \
	echo "CA_SECRET_NAME=$(CA_SECRET_NAME)"
