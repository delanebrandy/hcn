#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: join-hcn.sh
# Description: Adds a node to the Home Computing Network.
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

# Ensure required environment variables are set
if [[ -z "${HCN_IP_ADDRESS:-}" || -z "${HCN_SSH_UNAME:-}" ]]; then
  error "Required environment variables not set: HCN_IP_ADDRESS and HCN_SSH_UNAME"
  exit 1
fi

IP_ADDRESS="$HCN_IP_ADDRESS"
SSH_UNAME="$HCN_SSH_UNAME"

info "Connecting to control node at $IP_ADDRESS as $SSH_UNAME..."
info "Fetching join script..."
scp -i $KEY_FILE "$SSH_UNAME@$IP_ADDRESS:~/join-command.sh" /tmp/join.sh
chmod +x /tmp/join.sh

info "Running join script..."
/tmp/join.sh

if [[ $? -eq 0 ]]; then
  info "Successfully joined the HCN."
else
  error "Failed to join the HCN."
  exit 1
fi

mkdir -p /root/.kube
scp -i $HOME/.ssh/id_rsa "$SSH_UNAME@$IP_ADDRESS:/home/${SSH_UNAME}/.kube/config" /root/.kube/config
chown root:root /root/.kube/config
chmod 600 /root/.kube/config

mkdir -p "$HOME_DIR/.kube"
cp /root/.kube/config "$HOME_DIR/.kube/config"
chown "$HCN_ORIG_USER:$HCN_ORIG_USER" "$HOME_DIR/.kube/config"
chmod 600 "$HOME_DIR/.kube/config"

info "Checking node readiness..."
if kubectl get nodes 2>/dev/null | grep -q "Ready"; then
  info "Node is ready."
else
  error "Node is not ready."
  exit 1
fi

#give worker role to the node
kubectl label node "$HOSTNAME" node-role.kubernetes.io/worker=true --overwrite

info "Node joined the HCN and is ready."
