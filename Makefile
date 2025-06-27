include bootstrap.env

.DEFAULT_GOAL := help

.PHONY: help gitlab
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
		-f charts/ingress-nginx-values.yaml

monitoring: ## Reinstall Prometheus + Grafana
	@envsubst < charts/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
		--namespace monitoring \
		--create-namespace \
		-f -

status: ## Show current cluster state
	@kubectl get nodes
	@kubectl get pods -A | grep -E 'cert-manager|ingress|monitoring|grafana|prometheus'

logs: ## Show Ingress controller logs
	@kubectl logs -n ingress-nginx -l app.kubernetes.io/component=controller -f --tail=100

gitlab: ## Install/Reinstall Gitlab instance
	@helm repo add --force-update gitlab https://charts.gitlab.io/ || true
	@helm repo update
	@helm upgrade --install gitlab gitlab/gitlab --namespace gitlab --create-namespace \
    	--version 8.11.2 \
    	--timeout 900s \
    	-f apps/gitlab/values.yaml

opencost: ## Install Opencost
	@helm repo add opencost-charts https://opencost.github.io/opencost-helm-chart
	@helm repo update
	@helm upgrade --install opencost opencost-charts/opencost --namespace opencost --create-namespace -f apps/opencost/values.yaml

kubecost: ## Install kubecost
	@helm repo add --force-update kubecost https://kubecost.github.io/cost-analyze/
	@helm repo update
	@helm upgrade --install kubecost kubecost/cost-analyzer -n kubecost --create-namespace
