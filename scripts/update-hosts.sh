#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

if [ -f "$REPO_ROOT/bootstrap.env" ]; then
    set -a
    source "$REPO_ROOT/bootstrap.env"
    set +a
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[+] $*${NC}"
}

warn() {
    echo -e "${YELLOW}[WARN] $*${NC}"
}

# DNS setup
DOMAINS=()
SUBDOMAINS_FILE="$REPO_ROOT/dns/subdomains.txt"

if [[ -f "$SUBDOMAINS_FILE" ]]; then
    while IFS= read -r subdomain || [[ -n "$subdomain" ]]; do
        # Skip empty lines and comments
        [[ "$subdomain" =~ ^#.*$ ]] && continue
        [[ -z "$subdomain" ]] && continue
        
        DOMAINS+=("${subdomain}.${DOMAIN}")
    done < "$SUBDOMAINS_FILE"
else
    warn "Subdomains file not found at $SUBDOMAINS_FILE"
    exit 1
fi

HOSTS_FILE="/etc/hosts"
MISSING_DOMAINS=()

log "Checking $HOSTS_FILE for kindforge domains..."

for domain in "${DOMAINS[@]}"; do
    if ! grep -q "127.0.0.1.*$domain" "$HOSTS_FILE"; then
        MISSING_DOMAINS+=("$domain")
    fi
done

if [[ ${#MISSING_DOMAINS[@]} -eq 0 ]]; then
    echo -e "${GREEN}[OK] All domains are correctly configured in $HOSTS_FILE.${NC}"
    exit 0
fi

log "The following domains are missing: ${MISSING_DOMAINS[*]}"

ENTRY="127.0.0.1 ${MISSING_DOMAINS[*]} # kindforge-auto"

if [ "$EUID" -ne 0 ]; then
    warn "Root privileges required to update $HOSTS_FILE."
    echo -e "Please run the following command manually:"
    echo -e "\n    echo \"$ENTRY\" | sudo tee -a $HOSTS_FILE\n"
    
    read -p "Or type 'y' to run this with sudo now? [y/N] " -r
    if [[ $REPLY =~ ^[Yy]$ ]]; then
         echo "$ENTRY" | sudo tee -a "$HOSTS_FILE" >/dev/null
         echo -e "${GREEN}[OK] Updated $HOSTS_FILE.${NC}"
    else
         echo "Skipping."
    fi
else
    echo "$ENTRY" >> "$HOSTS_FILE"
    echo -e "${GREEN}[OK] Updated $HOSTS_FILE.${NC}"
fi
