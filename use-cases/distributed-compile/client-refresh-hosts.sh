#!/bin/bash
# --------------------------------------------------------------
# Script: client-refresh-hosts.sh
# Purpose: Refresh ~/.distcc/hosts using kubectl to discover
#          all distcc DaemonSet pods in the cluster.
# --------------------------------------------------------------

set -eo pipefail

# CONFIGURATION
NAMESPACE="devtools"
LABEL_SELECTOR="app=distcc"
CONNECTIONS_PER_NODE=4
HOSTS_FILE="$HOME_DIR/.distcc/hosts"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

info "Resolving distcc pod IPs via headless service..."

# Ensure ~/.distcc exists
mkdir -p "$(dirname "$HOSTS_FILE")"

# Fetch pod IPs
kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' \
  | sort -u \
  | awk -v conns="$CONNECTIONS_PER_NODE" '{ print $1 "/" conns }' \
  > "$HOSTS_FILE"

info "Updated $HOSTS_FILE:"
cat "$HOSTS_FILE"
