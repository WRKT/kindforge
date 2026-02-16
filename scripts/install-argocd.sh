#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[+] Installing ArgoCD via Helm"
helm repo add --force-update argo https://argoproj.github.io/argo-helm >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --create-namespace \
  -f "$REPO_ROOT/apps/argocd/values.yaml"

echo "[+] Waiting for ArgoCD server to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=300s

echo "[OK] ArgoCD installed successfully!"
echo "Access ArgoCD UI at: https://argocd.kindforge-cl01.io"
echo ""
