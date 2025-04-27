#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling
# Description: Bootstraps a system with Docker, Kubernetes, and cri-dockerd,
#              includes WSL2 detection, systemd setup, and system verification.
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

#Start Message
info "Starting HCN Setup, installing dependencies..."

wsl2() {
  if [[ -f /proc/sys/kernel/osrelease ]] && grep -q "microsoft-standard" /proc/sys/kernel/osrelease; then
    if ! pidof systemd &>/dev/null; then
      error "WSL2 detected, but systemd is not active."

      # Ensure the file exists
      if [[ ! -f /etc/wsl.conf ]]; then
        info "Creating /etc/wsl.conf..."
        touch /etc/wsl.conf
      fi

      # Only append systemd config if not already set
      if ! grep -q "^\[boot\]" /etc/wsl.conf || ! grep -q "^systemd=true" /etc/wsl.conf; then
        info "Enabling systemd in /etc/wsl.conf..."
        echo -e "\n[boot]\nsystemd=true" >> /etc/wsl.conf
      else
        info "systemd is already enabled in /etc/wsl.conf."
      fi

      echo -e "${RED}Please reboot your WSL environment to apply systemd changes.${NC}"
      echo -e "${YELLOW}Run: wsl --shutdown${NC}, then reopen your terminal and re-run this script."
      exit 1
    fi

    return 0
  else
    return 1
  fi
}

# WSL2-specific behavior
if wsl2; then
  info "Detected WSL2 environment - disabling swap..."
  swapoff -a || true
  sed -i '/ swap / s/^/#/' /etc/fstab || true
  info "Opening Kubernetes ports for WSL2..."
  for port in 6443 2379 2380 10250 10259 10257; do
    iptables -A INPUT -p tcp --dport "$port" -j ACCEPT || true
    iptables -A OUTPUT -p tcp --sport "$port" -j ACCEPT || true
  done

else
  info "Non-WSL2 environment - opening Kubernetes control plane ports..."
  for port in 6443 2379 2380 10250 10259 10257; do
    ufw allow "$port"/tcp || true
  done
fi


info "Installing prerequisites..."
apt-get install -y -qq apt-transport-https ca-certificates curl gnupg lsb-release openssh-client

################################################################################
# Docker Installation
################################################################################
if ! $WSL; then
  info "Setting up Docker repository and GPG key..."

  # Create the keyrings directory if it doesn't exist
  install -m 0755 -d /etc/apt/keyrings

  # Download Docker's official GPG key and save it
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | \
    gpg --dearmor -o /etc/apt/keyrings/docker.gpg

  # Ensure the GPG key has the correct permissions
  chmod a+r /etc/apt/keyrings/docker.gpg

  # Determine the Ubuntu codename
  UBUNTU_CODENAME="$(lsb_release -cs)"

  # Docker may not officially support 'noble' yet; fallback to 'jammy' if necessary
  if [[ "$UBUNTU_CODENAME" == "noble" ]]; then
    info "Detected Ubuntu 24.04 (Noble). Falling back to Docker's 'jammy' repository."
    DOCKER_CODENAME="jammy"
  else
    DOCKER_CODENAME="$UBUNTU_CODENAME"
  fi

  # Add Docker's repository
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $DOCKER_CODENAME stable" | \
    tee /etc/apt/sources.list.d/docker.list > /dev/null

  # Update package lists to include Docker packages
  apt-get -qq update

  info "Installing Docker Engine and related components..."
  apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin

  info "Enabling and starting Docker service..."
  systemctl enable --now docker
fi 
################################################################################
# Kubernetes Installation
################################################################################

info "Setting up Kubernetes repository and GPG key..."

# Download Kubernetes GPG key and save it
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | \
  gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg

# Add Kubernetes repository
echo \
  "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" | \
  tee /etc/apt/sources.list.d/kubernetes.list

# Update package lists to include Kubernetes packages
apt-get -qq update

info "Installing kubelet, kubeadm, and kubectl..."
apt-get install -y -qq kubelet kubeadm kubectl
apt-mark hold kubelet kubeadm kubectl

info "Enabling kubelet service..."
systemctl enable --now kubelet

################################################################################
# cri-dockerd Installation
################################################################################

CRI_VERSION="0.3.16"
ARCH="$(dpkg --print-architecture)"  # Automatically detect architecture
CRI_TAR="cri-dockerd-${CRI_VERSION}.${ARCH}.tgz"
CRI_URL="https://github.com/Mirantis/cri-dockerd/releases/download/v${CRI_VERSION}/${CRI_TAR}"

info "Detected system architecture: ${ARCH}"
info "Downloading cri-dockerd version $CRI_VERSION for $ARCH..."
wget -q "$CRI_URL"

if [[ -f "$CRI_TAR" ]]; then
  tar xf "$CRI_TAR"
  mv ./cri-dockerd/cri-dockerd /usr/local/bin/
else
  error "Failed to download cri-dockerd archive."
  exit 1
fi

info "Downloading cri-dockerd systemd service files..."
wget -q https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.service
wget -q https://raw.githubusercontent.com/Mirantis/cri-dockerd/master/packaging/systemd/cri-docker.socket

# Move service files to systemd directory
mv cri-docker.service cri-docker.socket /etc/systemd/system/

# Update the service file to point to the correct binary location
sed -i -e 's,/usr/bin/cri-dockerd,/usr/local/bin/cri-dockerd,' /etc/systemd/system/cri-docker.service

info "Enabling and starting cri-dockerd services..."

if $WSL; then
  UNIT_FILE="/etc/systemd/system/cri-docker.service"
sed -i -E \
  's|^ExecStart=.*|ExecStart=/usr/local/bin/cri-dockerd --container-runtime-endpoint fd:// --docker-root /mnt/wsl/docker-desktop-data/data/docker|' \
  "$UNIT_FILE"
fi
systemctl daemon-reload
systemctl enable cri-docker.service
systemctl enable --now cri-docker.socket

################################################################################
# Verification
################################################################################

info "Verifying installations..."

command_exists() {
  command -v "$1" &> /dev/null
}

check_service_status() {
  if systemctl is-active --quiet "$1"; then
    info "$1 is active."
  else
    error "$1 is NOT running!"
  fi
}

# Verify Docker installation
if command_exists docker; then
  docker --version
  check_service_status docker
else
  error "Docker command not found!"
fi

# Verify Kubernetes components
if command_exists kubelet; then
  kubelet --version
else
  error "kubelet command not found!"
fi

if command_exists kubeadm; then
  kubeadm version
else
  error "kubeadm command not found!"
fi

if command_exists kubectl; then
  kubectl version --client
else
  error "kubectl command not found!"
fi

# Verify cri-dockerd service
check_service_status cri-docker.service

info "Initialization complete! All components should be installed and running."
