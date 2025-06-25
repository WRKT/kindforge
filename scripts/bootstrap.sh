#!/bin/bash
set -euo pipefail

source ./bootstrap.env

echo "Bootstrapping Kind cluster: $CLUSTER_NAME"

echo "[!] Check system requirements"
./scripts/check-requirements.sh

echo "[1/8] Creating Kind cluster"
envsubst < cluster/config.yaml | kind create cluster --config=-

echo "[2/8] Installing Cilium CNI"
helm repo add cilium https://helm.cilium.io/
helm repo update
helm upgrade --install cilium cilium/cilium \
  --namespace kube-system \
  -f charts/cilium-values.yaml

echo "Waiting for Cilium pods to be ready..."
kubectl -n kube-system rollout status daemonset/cilium --timeout=120s

echo "[3/8] Generating TLS with mkcert"
./certs/install.sh

echo "[4/8] Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

echo "Waiting for cert-manager CRDs to be established..."
kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager -n cert-manager || true

echo "[5/8] Creating mkcert CA secret"
kubectl create secret tls mkcert-ca-secret \
  --cert=certs/rootCA.pem \
  --key=certs/rootCA.pem \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[6/8] Creating ClusterIssuer"
envsubst < yamls/clusterissuer.yaml.tpl | kubectl apply -f -

echo "[7/8] Installing Ingress-NGINX"
helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
helm repo update
helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
  --namespace ingress-nginx \
  --create-namespace \
  -f charts/ingress-nginx-values.yaml

echo "[8/8] Installing Prometheus + Grafana"
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --create-namespace \
  -f charts/prometheus-stack-values.yaml

echo "[OK] Cluster '$CLUSTER_NAME' is now ready with Cilium, TLS, Ingress, and monitoring stack."

