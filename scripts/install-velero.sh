#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[+] Installing MinIO via Helm"
helm repo add --force-update minio https://charts.min.io/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install minio minio/minio \
  --namespace minio \
  --create-namespace \
  -f "$REPO_ROOT/apps/minio/values.yaml"

echo "[+] Installing Velero via Helm"
helm repo add --force-update vmware-tanzu https://vmware-tanzu.github.io/helm-charts >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true
helm upgrade --install velero vmware-tanzu/velero \
  --namespace velero \
  --create-namespace \
  -f "$REPO_ROOT/apps/velero/values.yaml"
