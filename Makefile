include bootstrap.env

.DEFAULT_GOAL := help

.PHONY: help gitlab velero
help:
	@echo "Usage: make <target>"
	@echo ""
	@echo "Available targets:"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  %-18s %s\n", $$1, $$2}'

prepare: ## Install binary prerequisites
	@./scripts/install-prerequisites.sh

check: prepare ## Check for required tools
	@./scripts/check-requirements.sh

bootstrap: check ## Run full bootstrap workflow (Kind, TLS, cert-manager, Ingress, Prometheus)
	@./scripts/bootstrap.sh

delete: ## Delete the cluster
	@kind delete cluster --name $(CLUSTER_NAME)

tls: ## Regenerate mkcert TLS
	@./certs/install.sh

certs: ## Reapply cert-manager CA secret + ClusterIssuer
	@kubectl create secret tls mkcert-ca-secret \
		--cert=certs/rootCA.pem \
		--key=certs/rootCA.pem \
		-n cert-manager \
		--dry-run=client -o yaml | kubectl apply -f -
	@envsubst < yamls/clusterissuer.yaml.tpl | kubectl apply -f -

ingress: ## Reinstall Ingress-NGINX
	@helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
		--namespace ingress-nginx \
		--create-namespace \
		-f defaults/ingress-nginx-values.yaml

monitoring: ## Reinstall Prometheus + Grafana
	@envsubst < defaults/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		-f -

gitlab: ## Install/Reinstall Gitlab instance
	@echo "Installing GitLab via Helm..."
	@helm repo add --force-update gitlab https://charts.gitlab.io/ || true
	@helm repo update
	@helm upgrade --install gitlab gitlab/gitlab \
	  --namespace gitlab \
	  --create-namespace \
	  --timeout 900s \
	  -f sample/gitlab/values.yaml

velero: ## Install Velero server
	@echo "Installing MinIO via Helm..."
	@helm repo add --force-update minio https://charts.min.io/ || true
	@helm repo update
	@helm upgrade --install minio minio/minio \
	  --namespace minio \
	  --create-namespace \
	  -f defaults/minio-values.yaml

	@echo "Installing Velero via Helm..."
	@helm repo add --force-update vmware-tanzu https://vmware-tanzu.github.io/helm-charts || true
	@helm repo update
	@helm upgrade --install velero vmware-tanzu/velero \
	  --namespace velero \
	  --create-namespace \
	  -f sample/velero/values.yaml

velero-clean: ## Uninstall Velero and MinIO (and delete MinIO PVCs)
	@helm uninstall velero -n velero || true
	@helm uninstall minio -n minio || true
	@kubectl delete pvc --all -n minio || true

opencost: ## Install Opencost
	@helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
	@helm repo update
	@helm upgrade --install opencost opencost-charts/opencost --namespace opencost --create-namespace -f apps/opencost/values.yaml
