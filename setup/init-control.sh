#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: init-control.sh
# Description: Initializes the control plane for the Home Computing Network (HCN).
# ------------------------------------------------------------------------------

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
force=false
#set --force flag
if [[ "$1" == "--force" ]]; then
  info "Force flag detected, skipping WSL2 check."
  force=true
fi

# Start Message
info "Starting HCN Setup for control plane"

wsl2() {
  if [[ -f /proc/sys/kernel/osrelease ]] && grep -q "microsoft-standard" /proc/sys/kernel/osrelease; then
    return 0
  else
    return 1
  fi
}

if wsl2 || $force; then
  error "WSL2 is unsupported for the control plane,
  please run this script on a native Linux system.
  or override the check by running the script with the --force flag."
  exit 1
fi

## Common init steps
info "Installing dependencies..."
apt-get -yqq install openssh-server > /dev/null 2>&1

./setup/init.sh

## Generate SSH key
#ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa

## Set up kubeadm cluster
info "Setting up kubeadm cluster..."
kubeadm init --cri-socket unix:///var/run/cri-dockerd.sock

## Set up kubeconfig
info "Setting up kubeconfig..."
export KUBECONFIG=/etc/kubernetes/admin.conf

## Set up cluster networking
info "Setting up cluster networking..."
kubectl apply -f https://docs.projectcalico.org/manifests/calico.yaml

## Generate Join Command
kubeadm token create --ttl 0 --print-join-command > ~/join-command.sh
echo " --cri-socket unix:///var/run/cri-dockerd.sock" >> ~/join-command.sh
chmod +x ~/join-command.sh

kubectl label node "$HOSTNAME" node-role.kubernetes.io/control-plane=true --overwrite
## Create NFS share if available
../storage/setup-storage.sh
