#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

log() {
  echo -e "\n[+] $*"
}

install_monitoring_stack() {
  log "Installing Prometheus + Grafana"

  # Add repo if not already added
  if ! helm repo list | grep -q prometheus-community; then
    helm repo add prometheus-community https://prometheus-community.github.io/helm-charts >/dev/null 2>&1 || true
    helm repo update >/dev/null 2>&1 || true
  fi

  envsubst < defaults/prometheus-stack-values.yaml | helm upgrade --install monitoring prometheus-community/kube-prometheus-stack \
    --namespace monitoring \
    --create-namespace \
    -f -

  log "Waiting for Prometheus operator to be ready..."
  kubectl -n monitoring wait --for=condition=Available --timeout=120s deployment/monitoring-kube-prometheus-operator || true

  echo "[OK] Monitoring stack installed successfully"
  echo "[INFO] Access Grafana at: https://grafana.$DOMAIN (if ingress is configured)"
}

install_monitoring_stack
