#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

log() {
  echo -e "\n[+] $*"
}

setup_helm_repos() {
  log "Setting up Helm repositories"
  helm repo add --force-update cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
  helm repo add --force-update jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo add --force-update ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo add --force-update prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true

  log "Updating Helm repositories"
  helm repo update >/dev/null 2>&1 || true
}

create_kind_cluster() {
  log "Creating Kind cluster: $CLUSTER_NAME"
  envsubst < cluster/config.yaml | kind create cluster --config=-
}

install_cilium() {
  log "Installing Cilium CNI"
  helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    -f defaults/cilium-values.yaml

  log "Waiting for Cilium pods to be ready..."
  kubectl -n kube-system rollout status daemonset/cilium --timeout=120s
}

generate_tls_certificates() {
  log "Generating TLS with mkcert"
  ./certs/install.sh
}

install_cert_manager() {
  log "Installing cert-manager"
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
  envsubst < defaults/clusterissuer.yaml | kubectl apply -f -
}

wait_for_ingress_nginx_controller() {
  log "Waiting for Ingress-NGINX controller to be ready..."

  if kubectl -n ingress-nginx get deployment ingress-nginx-controller &>/dev/null; then
    kubectl -n ingress-nginx rollout status deployment ingress-nginx-controller --timeout=300s
  elif kubectl -n ingress-nginx get daemonset ingress-nginx-controller &>/dev/null; then
    kubectl -n ingress-nginx rollout status daemonset ingress-nginx-controller --timeout=300s
  else
    echo "[!] ingress-nginx-controller not found as Deployment or DaemonSet"
    exit 1
  fi
}

install_ingress_nginx() {
  log "Installing Ingress-NGINX"
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    -f defaults/ingress-nginx-values.yaml

  wait_for_ingress_nginx_controller
}

install_monitoring_stack() {
  log "Installing Prometheus + Grafana"
  envsubst < defaults/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    -f -
}

main() {
  log "Bootstrapping Kind cluster: $CLUSTER_NAME"

  setup_helm_repos
  create_kind_cluster
  install_cilium
  generate_tls_certificates
  install_cert_manager
  create_ca_secret
  apply_cluster_issuer
  install_ingress_nginx

  echo "[OK] Cluster '$CLUSTER_NAME' is now ready with Cilium, TLS, and Ingress."
  echo "[INFO] To install monitoring stack, run: make monitoring"
}

main

