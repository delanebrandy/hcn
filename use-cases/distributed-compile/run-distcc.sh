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

SUB_URL="$(kubectl get nodes -o wide | grep 'control-plane' | awk '{print $6}'):30000"
PORT=5000

info "Building arm64 native distccd image..."
docker buildx build --platform linux/arm64 -t ${SUB_URL}/distccd-arm64-native:latest -f Dockerfile.native --output type=registry .

info "Building amd64 native distccd image..."
docker buildx build --platform linux/amd64 -t ${SUB_URL}/distccd-amd64-native:latest -f Dockerfile.native --output type=registry .

info "Building amd64-cross (amd64 target) distccd image..."
docker build --platform linux/amd64 -t ${SUB_URL}/distccd-amd64-cross:latest -f Dockerfile.cross .
docker push ${SUB_URL}/distccd-amd64-cross:latest

info "All relevant distccd images have been built and pushed."

info "Deploying distccd DaemonSets..."

info "Replacing placeholder 'registry' with ${SUB_URL} in all DaemonSet yamls…"
sed -i "s|registry|${SUB_URL}|g" distccd-*.yaml

kubectl apply -f distccd-arm64.yaml
kubectl apply -f distccd-amd64.yaml
kubectl apply -f distccd-cross.yaml

info "All applicable distccd daemons have been deployed."
