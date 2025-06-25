#!/bin/bash
set -euo pipefail

echo "Verifying prerequisites..."

REQUIRED_TOOLS=(docker kind kubectl helm mkcert make)

for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "[!] Missing: $tool"
    MISSING=1
  else
    echo "[+] Found: $tool"
  fi
done

if command -v k9s >/dev/null 2>&1; then
  echo "[+] Found: k9s (optional)"
else
  echo "[WARN] Optional tool missing: k9s"
fi

if [[ "${MISSING:-0}" -eq 1 ]]; then
  echo "[ERROR] One or more required tools are missing. Aborting bootstrap."
  exit 1
fi

echo "[OK] All required tools are installed."
