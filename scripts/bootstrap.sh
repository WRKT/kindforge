#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  echo -e "\n${BLUE}[+] $*${NC}"
}

warn() {
  echo -e "${YELLOW}[WARN] $*${NC}"
}

error() {
  echo -e "${RED}[ERROR] $*${NC}"
  exit 1
}

setup_helm_repos() {
  log "Setting up Helm repositories"
  helm repo add cilium https://helm.cilium.io/ >/dev/null 2>&1 || true
  helm repo add jetstack https://charts.jetstack.io >/dev/null 2>&1 || true
  helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx >/dev/null 2>&1 || true
  helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true

  if [[ "${1:-}" == "--update" ]]; then
      log "Updating Helm repositories"
      helm repo update >/dev/null 2>&1
  fi
}

create_kind_cluster() {
  if kind get clusters | grep -q "^${CLUSTER_NAME}$"; then
    log "Kind cluster '${CLUSTER_NAME}' already exists. Skipping creation."
    return
  fi

  log "Creating Kind cluster: $CLUSTER_NAME"
  envsubst < cluster/config.yaml | kind create cluster --config=-
}

install_cilium() {
  log "Installing/Upgrading Cilium CNI"
  
  # Ensure env vars are substituted in values file
  envsubst < defaults/cilium-values.yaml | helm upgrade --install cilium cilium/cilium \
    --namespace kube-system \
    -f -

  log "Waiting for Cilium to be ready..."
  kubectl -n kube-system rollout status daemonset/cilium --timeout=300s
}

generate_tls_certificates() {
  log "Checking TLS certificates"
  if [[ ! -f "certs/rootCA.pem" || ! -f "certs/rootCA-key.pem" ]]; then
      log "Generating TLS with mkcert"
      ./certs/install.sh
  else
      log "TLS certificates already exist in certs/. Skipping generation."
  fi
}

install_cert_manager() {
  log "Installing/Upgrading cert-manager"
  helm upgrade --install cert-manager jetstack/cert-manager \
    --namespace cert-manager \
    --create-namespace \
    --set installCRDs=true \
    --wait

  log "Waiting for cert-manager webhook to be ready..."
  kubectl wait --for=condition=Available --timeout=60s deployment/cert-manager-webhook -n cert-manager || true
}

create_ca_secret() {
  log "Ensuring mkcert CA secret exists"
  if kubectl get secret mkcert-ca-secret -n cert-manager >/dev/null 2>&1; then
      log "Secret 'mkcert-ca-secret' already exists. Skipping."
  else
      if [[ ! -f "certs/rootCA.pem" ]]; then
          error "certs/rootCA.pem not found! Cannot create CA secret."
      fi
      kubectl create secret tls mkcert-ca-secret \
        --cert=certs/rootCA.pem \
        --key=certs/rootCA-key.pem \
        -n cert-manager
  fi
}

apply_cluster_issuer() {
  log "Applying ClusterIssuer"
  envsubst < defaults/clusterissuer.yaml | kubectl apply -f -
}

wait_for_ingress_nginx_controller() {
  log "Waiting for Ingress-NGINX controller..."
  
  # Retry loop to wait for resource to exist before waiting for condition
  for _ in {1..10}; do
    if kubectl -n ingress-nginx get deployment ingress-nginx-controller >/dev/null 2>&1; then
        kubectl -n ingress-nginx wait --for=condition=Available deployment/ingress-nginx-controller --timeout=300s
        return
    fi
     if kubectl -n ingress-nginx get daemonset ingress-nginx-controller >/dev/null 2>&1; then
        kubectl -n ingress-nginx rollout status daemonset ingress-nginx-controller --timeout=300s
        return
    fi
    sleep 2
  done
  
  warn "Ingress controller deployment/daemonset not found yet."
}

install_ingress_nginx() {
  log "Installing/Upgrading Ingress-NGINX"
  helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
    --namespace ingress-nginx \
    --create-namespace \
    -f defaults/ingress-nginx-values.yaml

  wait_for_ingress_nginx_controller
}

update_hosts_file() {
  ./scripts/update-hosts.sh || true
}

main() {
  log "Bootstrapping Kind cluster: $CLUSTER_NAME"
  
  # Pass --update to force helm repo update if needed, e.g. defined in env or arg
  setup_helm_repos "${1:-}" 
  create_kind_cluster
  update_hosts_file
  install_cilium
  generate_tls_certificates
  install_cert_manager
  create_ca_secret
  apply_cluster_issuer
  install_ingress_nginx


  echo -e "\n${GREEN}[OK] Cluster '$CLUSTER_NAME' is ready!${NC}"
  echo -e "    - Cilium (eBPF mode + Hubble)"
  echo -e "    - Ingress NGINX"
  echo -e "    - Cert Manager (Local CA)"
  echo -e "\n${BLUE}[INFO] To install monitoring stack, run: make monitoring${NC}"
}

main "$@"

