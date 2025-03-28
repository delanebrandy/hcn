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

# Check password argument
if [[ $# -lt 1 ]]; then
  error "Usage: $0 <SSH_PASSWORD>"
  exit 1
fi
SSH_PASSWORD="$1"

# Detect if running in WSL2
wsl2() {
  if [[ -f /proc/sys/kernel/osrelease ]] && grep -q "microsoft-standard" /proc/sys/kernel/osrelease; then
    return 0
  else
    return 1
  fi
}

# Get IP address of control node
get_ip() {
  if wsl2; then
    info "Detected WSL2 environment"
    if powershell.exe python --version &>/dev/null; then
      info "Python is installed on Windows"
    else
      info "Installing Python via winget on Windows..."
      powershell.exe winget install --id Python.Python.3 --source winget
    fi
    IP_ADDRESS=$(powershell.exe python hostname.py raspberrypi | tr -d '\r')
  else
    IP_ADDRESS="control-node.local"
  fi
}

# Main Script Execution
info "Connecting to HCN, communicating with control node..."

# Get control node IP
get_ip
info "Control node IP: $IP_ADDRESS"

# Install sshpass if not installed
info "Installing sshpass..."
apt-get update -qq
apt-get install -y sshpass

# Copy join script and key from control node
info "Fetching join script and SSH key..."
sshpass -p "$SSH_PASSWORD" scp user@"$IP_ADDRESS":~/join-command.sh /tmp/join.sh
sshpass -p "$SSH_PASSWORD" scp user@"$IP_ADDRESS":~/join-key /tmp/join-key
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
