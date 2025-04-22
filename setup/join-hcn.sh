#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: EDIT
# Description: EDIT
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

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <control-plane-IP> <ssh-username>"
  exit 1
fi
IP_ADDRESS="$1"
SSH_UNAME="$2"

# Copy join script and key from control node using scp sshkey 
info "Fetching join script..."

scp "$SSH_UNAME@$IP_ADDRESS:~/join-command.sh" /tmp/join.sh  
chmod +x /tmp/join.sh

# Run join script
info "Running join script..."
/tmp/join.sh

# Check if the join command was successful
if [[ $? -eq 0 ]]; then
  info "Successfully joined the HCN."
else
  error "Failed to join the HCN."
  exit 1
fi

# Check if the node is ready
if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
  info "Node is ready."
else
  error "Node is not ready."
  exit 1
fi

mkdir -p ~/.kube
scp "$SSH_UNAME@$IP_ADDRESS:~/.kube/config ~/.kube/config"

info "Node joined the HCN and is ready."
