#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

log() {
  echo -e "\n[+] $*"
}

create_kind_cluster() {
  log "Creating Kind cluster: $CLUSTER_NAME"
  envsubst < cluster/config.yaml | kind create cluster --config=-
}

install_cilium() {
  log "Installing Cilium CNI"
  helm repo add --force-update cilium https://helm.cilium.io/
  helm repo update
  helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    -f charts/cilium-values.yaml

  log "Waiting for Cilium pods to be ready..."
  kubectl -n kube-system rollout status daemonset/cilium --timeout=120s
}

generate_tls_certificates() {
  log "Generating TLS with mkcert"
  ./certs/install.sh
}

install_cert_manager() {
  log "Installing cert-manager"
  helm repo add --force-update jetstack https://charts.jetstack.io
  helm repo update
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true

  log "Waiting for cert-manager CRDs to be established..."
  kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager -n cert-manager || true
}

create_ca_secret() {
  log "Creating mkcert CA secret"
  kubectl create secret tls mkcert-ca-secret \
    --cert=certs/rootCA.pem \
    --key=certs/rootCA-key.pem \
    -n cert-manager \
    --dry-run=client -o yaml | kubectl apply -f -
}

apply_cluster_issuer() {
  log "Creating ClusterIssuer"
  envsubst < yamls/clusterissuer.yaml.tpl | kubectl apply -f -
}

install_ingress_nginx() {
  log "Installing Ingress-NGINX"
  helm repo add --force-update ingress-nginx https://kubernetes.github.io/ingress-nginx
  helm repo update
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    -f charts/ingress-nginx-values.yaml

  log "Waiting for Ingress-NGINX to be ready..."
  kubectl -n ingress-nginx rollout status daemonset ingress-nginx-controller --timeout=300s
}

install_monitoring_stack() {
  log "Installing Prometheus + Grafana"
  envsubst < charts/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    -f -
}

main() {
  log "Bootstrapping Kind cluster: $CLUSTER_NAME"

  create_kind_cluster
  install_cilium
  generate_tls_certificates
  install_cert_manager
  create_ca_secret
  apply_cluster_issuer
  install_ingress_nginx
  install_monitoring_stack

  echo "[OK] Cluster '$CLUSTER_NAME' is now ready with Cilium, TLS, Ingress, and monitoring stack."
}

main

