#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[+] Installing DokuWiki"

helm repo add area-42 https://area-42.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

if command -v envsubst >/dev/null 2>&1; then
    kubectl create namespace dokuwiki --dry-run=client -o yaml | kubectl apply -f -
    
    set -a
    if [ -f "$REPO_ROOT/bootstrap.env" ]; then
        source "$REPO_ROOT/bootstrap.env"
    fi
    set +a

    envsubst < "$REPO_ROOT/apps/dokuwiki/values.yaml" | helm upgrade --install dokuwiki area-42/dokuwiki \
        --namespace dokuwiki \
        --create-namespace \
        -f -
else
    echo "[!] envsubst not found. Please install gettext-base."
    exit 1
fi

echo "[+] Waiting for DokuWiki to be ready..."
kubectl rollout status deployment/dokuwiki -n dokuwiki --timeout=300s

echo "[OK] DokuWiki installed."