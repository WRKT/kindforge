#!/bin/bash
set -euo pipefail

if [[ -f ./bootstrap.env ]]; then
  set -a
  source ./bootstrap.env
  set +a
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo "[+] Installing GitLab via Helm"
helm repo add --force-update gitlab https://charts.gitlab.io/ >/dev/null 2>&1 || true
helm repo update >/dev/null 2>&1 || true

if command -v envsubst >/dev/null 2>&1; then
  envsubst < "$REPO_ROOT/tools/gitlab/values.yaml" | helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --create-namespace \
    --timeout 900s \
    -f -
else
  helm upgrade --install gitlab gitlab/gitlab \
    --namespace gitlab \
    --create-namespace \
    --timeout 900s \
    -f "$REPO_ROOT/tools/gitlab/values.yaml"
fi
