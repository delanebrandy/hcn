#!/bin/bash
# --------------------------------------------------------------------------
# Author: Delane Brandy
# Email: d.brandy@se21.qmul.ac.uk
# Script: run-ai.sh
# Description: Builds and deploys Real-ESRGAN AI Compute to the Home Compute Network.
# --------------------------------------------------------------------------

set -euo pipefail

# --- Logging ---
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# --- Variables ---
IMAGE_NAME="real-esrgan"
NAMESPACE="ai"
PORT=5000

# --- Find Registry ---
info "Locating local Kubernetes registry..."
REGISTRY=$(kubectl get svc registry -n registry -o jsonpath='{.spec.clusterIP}')
if [[ -z "$REGISTRY" ]]; then
  error "Could not find local registry service."
  exit 1
fi
REG_URL="${REGISTRY}:${PORT}"
SUB_URL="$(hostname -I | awk '{print $1}'):30000"

info "Registry found at $REG_URL"

# --- Configure Docker ---
info "Configuring Docker to trust the local registry..."
if ! grep -q "${REG_URL}" /etc/docker/daemon.json; then
    sudo mkdir -p /etc/docker
    echo "{ \"insecure-registries\": [\"${REG_URL}\", \"${SUB_URL}\"] }" | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
else
    info "Docker already configured."
fi

# --- Build and Push Docker Image ---
info "Building Real-ESRGAN Docker image..."
docker buildx build --platform linux/amd64 -t "${REG_URL}/${IMAGE_NAME}:latest" --output type=registry .

# --- Prepare YAML ---
info "Preparing Kubernetes manifests..."
cp real-esrgan-deployment.yaml real-esrgan-deployment-final.yaml
sed -i "s|registry/real-esrgan:latest|${SUB_URL}/${IMAGE_NAME}:latest|g" real-esrgan-deployment-final.yaml

# --- Create Namespace if Needed ---
if ! kubectl get ns "${NAMESPACE}" >/dev/null 2>&1; then
  info "Creating namespace ${NAMESPACE}..."
  kubectl create namespace "${NAMESPACE}"
fi

# --- Deploy to Kubernetes ---
info "Deploying Real-ESRGAN services to Kubernetes..."
kubectl apply -f real-esrgan-deployment-final.yaml

info "Real-ESRGAN deployment complete!"
