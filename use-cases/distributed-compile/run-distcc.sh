#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: run-distcc.sh
# Description: Builds and pushes the distcc Docker image to an insecure registry,
#              then deploys DistCC manifests.
# ------------------------------------------------------------------------------

set -euo pipefail

# Colors for log messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

REGISTRY_HOST="${REGISTRY_HOST:-$(hostname -I | awk '{print $1}')}"
REGISTRY_PORT="${REGISTRY_PORT:-30000}"
REGISTRY_ADDR="${REGISTRY_HOST}:${REGISTRY_PORT}"

info "Joining Docker registry at ${REGISTRY_ADDR} as an insecure registry..."

cat > "/etc/docker/daemon.json" <<EOF
{
  "insecure-registries": [
    "${REGISTRY_ADDR}"
  ]
}
EOF

info "Restarting Docker service..."
systemctl restart docker
info "Docker now trusts ${REGISTRY_ADDR} as an insecure registry."

IMAGE="${REGISTRY_ADDR}/distcc:latest"
info "Building distcc server image..."
docker build -t "$IMAGE" .

info "Pushing to registry..."
docker push "$IMAGE"

info "Deploying DaemonSet and Headless Service..."
kubectl apply -n devtools -f distcc-daemonset.yaml
kubectl apply -n devtools -f distcc-headless.yaml

info "All distcc daemons should now be running on each node."
