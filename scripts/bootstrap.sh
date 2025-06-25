#!/bin/bash
set -euo pipefail

source ./bootstrap.env

echo "Bootstrapping Kind cluster: $CLUSTER_NAME"

echo "[!] Check system requirements"
./scripts/check-requirements.sh

echo "[1/7] Creating Kind cluster"
envsubst < cluster/config.yaml | kind create cluster --config=-

echo "[2/7] Generating TLS with mkcert"
./certs/install.sh

echo "[3/7] Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

echo "Waiting for cert-manager CRDs to be established..."
kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager -n cert-manager || true

echo "[4/7] Creating mkcert CA secret"
kubectl create secret tls mkcert-ca-secret \
  --cert=certs/rootCA.pem \
  --key=certs/rootCA.pem \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[5/7] Creating ClusterIssuer"
envsubst < yamls/clusterissuer.yaml.tpl | kubectl apply -f -

echo "[6/7] Installing Ingress-NGINX"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f charts/ingress-nginx-values.yaml

echo "[7/7] Installing Prometheus + Grafana"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f charts/prometheus-stack-values.yaml

echo "[OK] Cluster '$CLUSTER_NAME' is now ready with TLS, Ingress, and monitoring stack."

