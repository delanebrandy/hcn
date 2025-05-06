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

info "Adding registry to Docker daemon..."
if ! grep -q "${SUB_URL}" /etc/docker/daemon.json; then
    echo "Adding registry to Docker daemon..."
    sudo mkdir -p /etc/docker
    echo "{ \"insecure-registries\": [\"${SUB_URL}\", \"${SUB_URL}\"] }" | sudo tee /etc/docker/daemon.json
    sudo systemctl restart docker
else
    info "Registry already added to Docker daemon."
fi

info "Configuring buildx"

docker run --rm --privileged tonistiigi/binfmt --install all

info "Setting registry credentials..."

cat > buildkitd.toml <<EOF
[registry."${SUB_URL}"]
http = true
insecure = true
EOF

echo "Generated buildkitd.toml"

info "Creating new buildx builder..."
docker buildx create --name multiarch --config ./buildkitd.toml --use
docker buildx use multiarch
docker buildx inspect --bootstrap


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
