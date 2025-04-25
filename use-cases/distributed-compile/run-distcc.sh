#!/bin/bash
# --------------------------------------------------------------------------
# Author: Delane Brandy
# Script: run-distcc.sh
# Description: Builds and deploys distcc DaemonSets based on node architecture and label.
# --------------------------------------------------------------------------

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

REGISTRY=$(kubectl get svc registry -n registry -o jsonpath='{.spec.clusterIP}')
PORT=5000
REG_URL="${REGISTRY}:${PORT}"

info "Adding registry to Docker daemon..."
if ! grep -q "${REG_URL}" /etc/docker/daemon.json; then
    echo "Adding registry to Docker daemon..."
    sudo mkdir -p /etc/docker
    echo "{ \"insecure-registries\": [\"${REG_URL}\"] }" | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
else
    info "Registry already added to Docker daemon."
fi

info "Building cross platfrom native distccd image..."
docker buildx build --platform linux/amd64,linux/arm64 -t ${REG_URL}/distccd-native:latest --push -f Dockerfile.native .

info "Building amd64-cross (arm64 target) distccd image..."
docker build --platform linux/amd64 -t ${REG_URL}/distccd-amd64-cross:latest -f Dockerfile.cross .
docker push ${REG_URL}/distccd-amd64-cross:latest

info "All relevant distccd images have been built and pushed."

info "Deploying distccd DaemonSets..."

SUB_URL="$(hostname -I | awk '{print $1}'):30000"

info "Replacing placeholder 'registry' with ${SUB_URL} in all DaemonSet yamls…"
sed -i "s|registry|${SUB_URL}|g" distccd-*.yaml

kubectl apply -f distccd-arm64.yaml
kubectl apply -f distccd-cross.yaml
kubectl apply -f distccd-amd64.yaml

info "All applicable distccd daemons have been deployed."
