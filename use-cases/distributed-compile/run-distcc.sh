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


if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

REGISTRY=$(kubectl get svc registry -n registry -o jsonpath='{.spec.clusterIP}')
PORT=5000
REG_URL="${REGISTRY}:${PORT}"

info "Building arm64-native distccd image..."
docker build -t ${REG_URL}/distccd-arm64-native:latest -f Dockerfile.arm64 .
docker push ${REG_URL}/distccd-arm64-native:latest

info "Building amd64-native distccd image..."
docker build -t ${REG_URL}/distccd-amd64-native:latest -f Dockerfile.amd64 .
docker push ${REG_URL}/distccd-amd64-native:latest

info "Building amd64-cross (arm64 target) distccd image..."
docker build -t ${REG_URL}/distccd-amd64-cross:latest -f Dockerfile.cross .
docker push ${REG_URL}/distccd-amd64-cross:latest

info "All relevant distccd images have been built and pushed."

info "Deploying distccd DaemonSets..."

kubectl apply -f distccd-arm64.yaml
kubectl apply -f distccd-cross.yaml
kubectl apply -f distccd-amd64.yaml

info "All applicable distccd daemons have been deployed."
