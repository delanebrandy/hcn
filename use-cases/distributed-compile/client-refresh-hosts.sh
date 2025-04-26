#!/bin/bash
# --------------------------------------------------------------
# Script: client-refresh-hosts.sh
# Purpose: Refresh ~/.distcc/hosts using kubectl to discover
#          all distcc DaemonSet pods in the cluster.
# --------------------------------------------------------------

set -eo pipefail

# CONFIGURATION
NAMESPACE="devtools"
ARM64_LABEL_SELECTOR="app=distcc,role in (arm64-native,arm64-cross)"
AMD64_LABEL_SELECTOR="app=distcc,role=amd64-native"
CONNECTIONS_PER_NODE=4
HOSTS_FILE="$HOME_DIR/.distcc/hosts"

# Colors
GREEN='\033[0;32m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }

ARCH=$(uname -m)
info "Detected client arch: $ARCH"
info "Resolving distcc pod IPs for $NAMESPACE namespace..."

# Ensure ~/.distcc exists
mkdir -p "$(dirname "$HOSTS_FILE")"

if [[ "$ARCH" == "aarch64" ]]; then
  LABEL_SELECTOR="$ARM64_LABEL_SELECTOR"
  info "Using ARM64 label selector: $LABEL_SELECTOR"
elif [[ "$ARCH" == "x86_64" ]]; then
  LABEL_SELECTOR="$AMD64_LABEL_SELECTOR"
  info "Using AMD64 label selector: $LABEL_SELECTOR"
else
  error "Unsupported architecture: $ARCH"
  exit 1
fi

kubectl get pods -n "$NAMESPACE" -l "$LABEL_SELECTOR" -o jsonpath='{range .items[*]}{.status.podIP}{"\n"}{end}' \
  | sort -u \
  | awk -v conns="$CONNECTIONS_PER_NODE" '{ print $1 "/" conns }' \
  > "$HOSTS_FILE"

info "Updated $HOSTS_FILE:"
cat "$HOSTS_FILE"
