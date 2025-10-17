#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

echo "[*] Checking and installing prerequisites..."

install_docker() {
  if ! command -v docker &> /dev/null; then
    echo "[+] Installing Docker..."
    curl -fsSL https://get.docker.com | sh -
    sudo usermod -aG docker "$USER"
    echo "[!] Docker installed. You may need to logout/login or run 'newgrp docker'"
  else
    echo "[✓] Docker is already installed"
  fi
}

install_kind() {
  if ! command -v kind &> /dev/null; then
    echo "[+] Installing kind..."
    curl -Lo ./kind https://kind.sigs.k8s.io/dl/latest/kind-linux-amd64
    chmod +x ./kind
    sudo mv ./kind /usr/local/bin/kind
  else
    echo "[✓] kind is already installed"
  fi
}

install_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    echo "[+] Installing kubectl..."
    curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/linux/amd64/kubectl"
    chmod +x kubectl
    sudo mv kubectl /usr/local/bin/
  else
    echo "[✓] kubectl is already installed"
  fi
}

install_helm() {
  if ! command -v helm &> /dev/null; then
    echo "[+] Installing Helm..."
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  else
    echo "[✓] Helm is already installed"
  fi
}

install_mkcert() {
  if ! command -v mkcert &> /dev/null; then
    echo "[+] Installing mkcert..."
    sudo apt install -y libnss3-tools
    curl -JLO "https://dl.filippo.io/mkcert/latest?for=linux/amd64"
    chmod +x mkcert-v*-linux-amd64
    sudo mv mkcert-v*-linux-amd64 /usr/local/bin/mkcert
  else
    echo "[✓] mkcert is already installed"
  fi
}

install_make() {
  if ! command -v make &> /dev/null; then
    echo "[+] Installing make..."
    sudo apt update && sudo apt install -y build-essential
  else
    echo "[✓] make is already installed"
  fi
}

install_k9s() {
  if ! command -v k9s &> /dev/null; then
    echo "[+] Installing k9s..."
    K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
    curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz"
    tar -xzf k9s.tar.gz k9s
    chmod +x k9s
    sudo mv k9s /usr/local/bin/
    rm k9s.tar.gz
  else
    echo "[✓] k9s is already installed"
  fi
}

main() {
  install_docker
  install_kind
  install_kubectl
  install_helm
  install_mkcert
  install_make
  install_k9s
  echo "[OK] All prerequisites are installed"
}

main
