include bootstrap.env

SCRIPTS_DIR := scripts
CERTS_DIR := certs
DEFAULTS_DIR := defaults
CLUSTER_DIR := cluster
TOOLS_DIR := tools

.DEFAULT_GOAL := help

.PHONY: help gitlab velero prepare check bootstrap delete tls certs ingress monitoring velero-clean opencost lint print-config
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

bootstrap: check ## Run full bootstrap workflow (Kind, TLS, cert-manager, Ingress, Prometheus)
	@$(SCRIPTS_DIR)/bootstrap.sh

delete: ## Delete the cluster
	@kind delete cluster --name $(CLUSTER_NAME)

tls: ## Regenerate mkcert TLS
	@$(CERTS_DIR)/install.sh

certs: ## Reapply cert-manager CA secret + ClusterIssuer
	@kubectl create secret tls mkcert-ca-secret \
		--cert=$(CERTS_DIR)/rootCA.pem \
		--key=$(CERTS_DIR)/rootCA-key.pem \
		-n cert-manager \
		--dry-run=client -o yaml | kubectl apply -f -
	@envsubst < $(DEFAULTS_DIR)/clusterissuer.yaml | kubectl apply -f -

ingress: ## Reinstall Ingress-NGINX
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx \
		--create-namespace \
		-f $(DEFAULTS_DIR)/ingress-nginx-values.yaml

monitoring: ## Reinstall Prometheus + Grafana
	@envsubst < $(DEFAULTS_DIR)/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		-f -

gitlab: ## Install/Reinstall Gitlab instance
	@echo "Installing GitLab via Helm..."
	@helm repo add --force-update gitlab https://charts.gitlab.io/ || true
	@helm repo update
	@envsubst < $(TOOLS_DIR)/gitlab/values.yaml | helm upgrade --install gitlab gitlab/gitlab \
	  --namespace gitlab \
	  --create-namespace \
	  --timeout 900s \
	  -f -

velero: ## Install Velero server
	@echo "Installing MinIO via Helm..."
	@helm repo add --force-update minio https://charts.min.io/ || true
	@helm repo update
	@helm upgrade --install minio minio/minio \
	  --namespace minio \
	  --create-namespace \
	  -f $(TOOLS_DIR)/minio/values.yaml

	@echo "Installing Velero via Helm..."
	@helm repo add --force-update vmware-tanzu https://vmware-tanzu.github.io/helm-charts || true
	@helm repo update
	@helm upgrade --install velero vmware-tanzu/velero \
	  --namespace velero \
	  --create-namespace \
	  -f $(TOOLS_DIR)/velero/values.yaml

velero-clean: ## Uninstall Velero and MinIO
	@helm uninstall velero -n velero || true
	@helm uninstall minio -n minio || true
	@kubectl delete pvc --all -n minio || true

opencost: ## Install Opencost (requires values file at tools/opencost/values.yaml)
	@helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
	@helm repo update
	@if [ -f $(TOOLS_DIR)/opencost/values.yaml ]; then \
	  helm upgrade --install opencost opencost-charts/opencost \
	    --namespace opencost \
	    --create-namespace \
	    -f $(TOOLS_DIR)/opencost/values.yaml; \
	else \
	  echo "[WARN] Missing $(TOOLS_DIR)/opencost/values.yaml. Create it to customize the deployment."; \
	fi

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
