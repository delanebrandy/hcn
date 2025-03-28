#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling
# Description: Bootstraps a system with Docker, Kubernetes, and cri-dockerd,
#              includes WSL2 detection, systemd setup, and system verification.
# ------------------------------------------------------------------------------

##kubeadm token create --ttl 0 --print-join-command > ~/join-command.sh
##chmod +x ~/join-command.sh

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
# Start Message

info "Connecting to HCN, communicating with control node..."  

apt install sshpass
sshpass -p "$1" scp user@control-node.local:/home/user/join-command.sh /tmp/join.sh
/tmp/join.sh
# Check if the join command was successful
if [ $? -eq 0 ]; then
    info "Successfully joined the HCN."
else
    error "Failed to join the HCN."
    exit 1
fi
# Check if the node is ready
if kubectl get nodes | grep -q "Ready"; then
    info "Node is ready."
else
    error "Node is not ready."
    exit 1
fi
