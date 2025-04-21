#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: build-and-deploy.sh
# Description: Builds the distcc Docker image and deploys all manifests.
# ------------------------------------------------------------------------------

set -euo pipefail

# Colors for log messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

IMAGE="registry.registry.svc.cluster.local:5000/distcc:latest"

info "Building distcc server image..."
docker build -t "$IMAGE" .

info "Pushing to registry..."
docker push "$IMAGE"

info "Deploying DaemonSet..."
kubectl apply -f distcc-daemonset.yaml
kubectl apply -f distcc-headless.yaml

info "All distcc daemons should now be running on each node."
