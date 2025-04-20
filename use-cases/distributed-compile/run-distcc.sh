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

IMAGE_NAME="distcc-ccache:local"

# Check if the image already exists
if docker image inspect "$IMAGE_NAME" &>/dev/null; then
  info "Image '$IMAGE_NAME' already exists - skipping build."
else
  info "Image '$IMAGE_NAME' not found - building now..."
  docker build -t "$IMAGE_NAME" .
  info "Image '$IMAGE_NAME' built successfully."
fi

info "Deploying distcc server and service..."
kubectl apply -f distcc-server-deployment.yaml

info "Waiting for distcc server pods to become ready..."
kubectl wait --for=condition=ready pod -l app=distcc --timeout=60s

info "Launching distcc client job..."
kubectl apply -f distcc-client-job.yaml

info "Build and deployment process complete."
