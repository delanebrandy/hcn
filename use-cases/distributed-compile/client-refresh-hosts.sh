#!/bin/bash
set -euo pipefail

#---------------------------------------------------------------
# Script: client-refresh-hosts.sh
# Description: Populates ~/.distcc/hosts using Kubernetes DNS
#              to resolve distcc pod IPs via headless service.
#---------------------------------------------------------------

GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

USERNAME="${SUDO_USER:-$USER}"
USER_HOME=$(eval echo "~$USERNAME")
HOSTS_FILE="$USER_HOME/.distcc/hosts"

# Resolve headless service to pod IPs
info "Resolving distcc pod IPs via headless service..."
HOSTS_FILE=$(kubectl get pods -l app=distcc -n devtools -o wide \
  --no-headers | awk '{print $6"/4"}' | sort -u)

mkdir -p "$(dirname "$HOSTS_FILE")"
echo "$IPS" > "$HOSTS_FILE"

# Write to ~/.distcc/hosts
mkdir -p "$(dirname "$HOSTS_FILE")"
> "$HOSTS_FILE"
echo "$IPS" >> "$HOSTS_FILE"

info "Updated $HOSTS_FILE:"
cat "$HOSTS_FILE"
