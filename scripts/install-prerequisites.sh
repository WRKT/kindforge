#!/bin/bash
set -euo pipefail

set -a
source ./bootstrap.env
set +a

echo "[*] Checking and installing prerequisites..."

# Detect OS and Architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case $ARCH in
    x86_64) ARCH="amd64" ;;
    aarch64|arm64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

echo "[*] Detected OS: $OS, Architecture: $ARCH"

install_docker() {
  if ! command -v docker &> /dev/null; then
    if [ "$OS" = "darwin" ]; then
      echo "[!] Docker is not installed. Please install Docker Desktop for Mac or OrbStack."
      echo "[!] Visit: https://www.docker.com/products/docker-desktop/"
      return 1
    else
      echo "[+] Installing Docker..."
      curl -fsSL https://get.docker.com | sh -
      sudo usermod -aG docker "$USER"
      echo "[!] Docker installed. You may need to logout/login or run 'newgrp docker'"
    fi
  else
    echo "[✓] Docker is already installed"
  fi
}

install_kind() {
  if ! command -v kind &> /dev/null; then
    if [ "$OS" = "darwin" ] && command -v brew &> /dev/null; then
      echo "[+] Installing kind via Homebrew..."
      brew install kind
    else
      echo "[+] Installing kind..."
      curl -Lo ./kind "https://kind.sigs.k8s.io/dl/v0.27.0/kind-${OS}-${ARCH}"
      chmod +x ./kind
      sudo mv ./kind /usr/local/bin/kind
    fi
  else
    echo "[✓] kind is already installed"
  fi
}

install_kubectl() {
  if ! command -v kubectl &> /dev/null; then
    if [ "$OS" = "darwin" ] && command -v brew &> /dev/null; then
      echo "[+] Installing kubectl via Homebrew..."
      brew install kubernetes-cli
    else
      echo "[+] Installing kubectl..."
      curl -LO "https://dl.k8s.io/release/${K8S_VERSION}/bin/${OS}/${ARCH}/kubectl"
      chmod +x kubectl
      sudo mv kubectl /usr/local/bin/
    fi
  else
    echo "[✓] kubectl is already installed"
  fi
}

install_helm() {
  if ! command -v helm &> /dev/null; then
    if [ "$OS" = "darwin" ] && command -v brew &> /dev/null; then
      echo "[+] Installing Helm via Homebrew..."
      brew install helm
    else
      echo "[+] Installing Helm..."
      curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    fi
  else
    echo "[✓] Helm is already installed"
  fi
}

install_mkcert() {
  if ! command -v mkcert &> /dev/null; then
    if [ "$OS" = "darwin" ] && command -v brew &> /dev/null; then
      echo "[+] Installing mkcert via Homebrew..."
      brew install mkcert
    else
      echo "[+] Installing mkcert..."
      if [ "$OS" = "linux" ]; then
        sudo apt update && sudo apt install -y libnss3-tools || echo "Warning: apt not found or failed, skipping libnss3-tools"
      fi
      curl -JLO "https://dl.filippo.io/mkcert/latest?for=${OS}/${ARCH}"
      chmod +x mkcert-v*-${OS}-${ARCH}
      sudo mv mkcert-v*-${OS}-${ARCH} /usr/local/bin/mkcert
    fi
  else
    echo "[✓] mkcert is already installed"
  fi
}

install_make() {
  if ! command -v make &> /dev/null; then
    if [ "$OS" = "darwin" ]; then
      echo "[!] 'make' is not installed. Please install Xcode Command Line Tools by running: xcode-select --install"
    else
      echo "[+] Installing make..."
      sudo apt update && sudo apt install -y build-essential
    fi
  else
    echo "[✓] make is already installed"
  fi
}

install_k9s() {
  if ! command -v k9s &> /dev/null; then
    if [ "$OS" = "darwin" ] && command -v brew &> /dev/null; then
      echo "[+] Installing k9s via Homebrew..."
      brew install derailed/k9s/k9s
    else
      echo "[+] Installing k9s..."
      K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep tag_name | cut -d '"' -f 4)
      # Map OS name for k9s download
      K9S_OS=$(echo "$OS" | sed 's/darwin/Darwin/;s/linux/Linux/')
      # Map Arch name for k9s download
      K9S_ARCH=$(echo "$ARCH" | sed 's/amd64/amd64/;s/arm64/arm64/')
      
      curl -Lo k9s.tar.gz "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_${K9S_OS}_${K9S_ARCH}.tar.gz"
      tar -xzf k9s.tar.gz k9s
      chmod +x k9s
      sudo mv k9s /usr/local/bin/
      rm k9s.tar.gz
    fi
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
