#!/bin/bash

set -e

EXCLUDE_RESOURCES_LIST="
volumesnapshots.snapshot.storage.k8s.io
orders.acme.cert-manager.io
challenges.acme.cert-manager.io
certificaterequests.cert-manager.io
certificates.cert-manager.io
backups.k8up.io
checks.k8up.io
prunes.k8up.io
restores.k8up.io
jobs
"

EXCLUDE_NAMESPACES_LIST="
adminsys
agc-cert-manager
agc-ingress-nginx
agc-isengard-remote
agc-loki-logging
agc-prometheus-stack
agc-promtail
agc-velero
isengard-remote
kube-node-lease
kube-public
kube-system
opstoprom
prometheus-fr-lyo01
sauron
sidecar-injector
storage
teleport-leaf
teleport-root
vpn-ingress-nginx
"

DEFAULT_EXCLUDE_RESOURCES=$(printf '%s,' $EXCLUDE_RESOURCES_LIST | sed 's/,$//')
DEFAULT_EXCLUDE_NAMESPACES=$(printf '%s,' $EXCLUDE_NAMESPACES_LIST | sed 's/,$//')
DEFAULT_LABEL_SELECTOR="!k8upjob,!job-name"
NAME="global-tenants-backup" # Default name of schedule backup if none specified

DRY_RUN=false
if [ "$1" = "--dry-run" ]; then
    DRY_RUN=true
fi

convert_days_to_ttl() {
    local days="$1"
    
    days=$(echo "$days" | sed 's/[a-zA-Z]*$//')

    if ! echo "$days" | grep -qE '^[0-9]+$'; then
        echo "Error: Invalid number of days: $1" >&2
        exit 1
    fi
    
    hours=$((days * 24))
    echo "${hours}h"
}

read -p "[?] Namespace to backup (default: all namespaces): " NAMESPACE
if [ -z "$NAMESPACE" ]; then
    NAMESPACE="*"
else
    NAME="${NAMESPACE}-backup"
fi

read -p "[?] Schedule (cron format: 0 5 * * * - default: @daily): " SCHEDULE
if [ -z "$SCHEDULE" ]; then
    SCHEDULE="@daily"
    echo "[!] No schedule provided, using default '@daily'."
fi

read -p "[?] Number of retention days (7, 15 or 30 - default: 7): " DAYS
if [ -z "$DAYS" ]; then
    DAYS="7"
    echo "[!] No days provided, using default 7 days."
fi

TTL=$(convert_days_to_ttl "$DAYS")

echo "[+] Creating schedule: $NAME"
echo "Summary:"
echo "  Name: $NAME"
echo "  Namespace: $NAMESPACE"
echo "  Schedule: $SCHEDULE"
echo "  TTL: $TTL"

if [ "$DRY_RUN" = true ]; then
    echo -e "\n[*] Dry run mode - YAML output:"
    velero schedule create "$NAME" \
      --schedule="$SCHEDULE" \
      --include-namespaces="$NAMESPACE" \
      --exclude-namespaces="$DEFAULT_EXCLUDE_NAMESPACES" \
      --exclude-resources="$DEFAULT_EXCLUDE_RESOURCES" \
      --selector="$DEFAULT_LABEL_SELECTOR" \
      --ttl="$TTL" \
      --output yaml
else
    velero schedule create "$NAME" \
      --schedule="$SCHEDULE" \
      --include-namespaces="$NAMESPACE" \
      --exclude-namespaces="$DEFAULT_EXCLUDE_NAMESPACES" \
      --exclude-resources="$DEFAULT_EXCLUDE_RESOURCES" \
      --selector="$DEFAULT_LABEL_SELECTOR" \
      --ttl="$TTL"
    
    echo "[✓] Schedule '$NAME' created for namespace '$NAMESPACE'."
fi
