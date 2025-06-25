#!/bin/bash
set -euo pipefail

source ./bootstrap.env

echo "Bootstrapping Kind cluster: $CLUSTER_NAME"

echo "[1/5] Creating Kind cluster"
envsubst < cluster/config.yaml | kind create cluster --config=-

echo "[2/5] Generating TLS with mkcert"
./certs/install.sh

echo "[3/5] Installing cert-manager"
helm repo add jetstack https://charts.jetstack.io
helm repo update
helm upgrade --install cert-manager jetstack/cert-manager \
  --namespace cert-manager \
  --create-namespace \
  --set installCRDs=true

echo "Waiting for cert-manager CRDs to be established..."
kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager -n cert-manager || true

echo "[4/5] Creating mkcert CA secret"
kubectl create secret tls mkcert-ca-secret \
  --cert=certs/rootCA.pem \
  --key=certs/rootCA.pem \
  -n cert-manager \
  --dry-run=client -o yaml | kubectl apply -f -

echo "[5/5] Creating ClusterIssuer"
envsubst < yamls/clusterissuer.yaml.tpl | kubectl apply -f -

echo "[OK] Your cluster '$CLUSTER_NAME' is ready with TLS and cert-manager."
