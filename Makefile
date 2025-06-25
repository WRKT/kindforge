include bootstrap.env

.DEFAULT_GOAL := help

.PHONY: help
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

