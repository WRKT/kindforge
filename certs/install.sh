#!/bin/bash

set -euo pipefail

source ./bootstrap.env

mkdir -p certs
cd certs

if ! command -v mkcert >/dev/null 2>&1; then
  echo "[!] mkcert is not installed. Install it with `apt install -y mkcert`"
  exit 1
fi

mkcert -install

cp "$(mkcert -CAROOT)/rootCA.pem" ./rootCA.pem
cp "$(mkcert -CAROOT)/rootCA-key.pem" ./rootCA-key.pem

if [[ "$OSTYPE" == "linux-gnu"* ]]; then
  echo "[+] Adding CA to system trust store"
  sudo cp rootCA.pem /usr/local/share/ca-certificates/mkcert-ca.crt
  sudo update-ca-certificates
fi

echo "[OK] Certificates are generated successfully"
