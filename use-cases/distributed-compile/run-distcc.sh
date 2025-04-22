#!/bin/bash
# --------------------------------------------------------------------------
# Author: Delane Brandy
# Script: run-distcc.sh
# Description: Builds and deploys distcc DaemonSet using local registry.
# --------------------------------------------------------------------------

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

info "Fetching registry IP..."
REGISTRY_IP=$(kubectl get svc registry -n registry -o jsonpath='{.spec.clusterIP}')
IMAGE="$REGISTRY_IP:5000/distcc:latest"

info "Building distcc server image..."
docker build -t "$IMAGE" .

info "Pushing image to local registry..."
docker push "$IMAGE"

info "Deploying distcc DaemonSet..."
kubectl apply -f distcc-daemonset.yaml

info "✅ distcc DaemonSet is deployed to all nodes."
info "📡 Headless Service has been removed — dynamic hosts will be resolved via kubectl."
