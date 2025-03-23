#!/bin/bash

# Exit immediately if a command exits with a non-zero status.
# -e: exit on error
# -u: treat unset variables as errors
# -o pipefail: catch errors in piped commands
set -euo pipefail

# Colors for status messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m' # No Color

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

info "Updating package list..."
apt-get update

info "Installing required dependencies..."
apt-get install -y apt-transport-https ca-certificates curl gpg lsb-release wget

## DOCKER INSTALLATION ##
info "Setting up Docker repository..."
install -d -m 0755 /etc/apt/keyrings

curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
chmod a+r /etc/apt/keyrings/docker.asc

DOCKER_REPO="deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu $(. /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable"
echo "$DOCKER_REPO" > /etc/apt/sources.list.d/docker.list

info "Installing Docker packages..."
apt-get update
apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

info "Enabling and starting Docker service..."
systemctl enable --now docker

## KUBERNETES INSTALLATION ##
info "Setting up Kubernetes repository..."
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

K8S_REPO="deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /"
echo "$K8S_REPO" > /etc/apt/sources.list.d/kubernetes.list

info "Installing Kubernetes components..."
apt-get update
apt-get install -y kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

info "Enabling kubelet service..."
systemctl enable --now kubelet

## CRI-DOCKERD INSTALLATION ##
CRI_VERSION="0.3.16"
ARCH="arm64"
CRI_TAR="cri-dockerd-${CRI_VERSION}.${ARCH}.tgz"

info "Downloading cri-dockerd $CRI_VERSION..."
wget -q "https://github.com/Mirantis/cri-dockerd/releases/download/v${CRI_VERSION}/${CRI_TAR}"

if [[ ! -f "$CRI_TAR" ]]; then
  error "cri-dockerd archive not downloaded!"
  exit 1
fi

tar xvf "$CRI_TAR"
mv ./cri-dockerd/cri-dockerd /usr/local/bin/

info "Downloading cri-dockerd systemd service files..."
wget -q https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget -q https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket

mv cri-docker.service cri-docker.socket /etc/systemd/system/
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

info "Enabling cri-dockerd services..."
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

## INSTALLATION VERIFICATION ##
info "Verifying installations..."

command_exists() {
  command -v "$1" &> /dev/null
}

check_service_status() {
  systemctl is-active --quiet "$1" && info "$1 is active" || error "$1 is NOT running"
}

if command_exists docker; then
  docker --version
  check_service_status docker
else
  error "Docker installation failed!"
fi

if command_exists kubelet; then
  kubelet --version
  check_service_status kubelet
else
  error "Kubelet installation failed!"
fi

if command_exists kubeadm; then
  kubeadm version
else
  error "Kubeadm installation failed!"
fi

if command_exists kubectl; then
  kubectl version --client
else
  error "Kubectl installation failed!"
fi

check_service_status cri-docker.service

info "Setup completed successfully!"
