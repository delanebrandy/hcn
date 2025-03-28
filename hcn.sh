#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling
# Description: Bootstraps a system with Docker, Kubernetes, and cri-dockerd,
#              includes WSL2 detection, systemd setup, and system verification.
# ------------------------------------------------------------------------------
set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <control-node-ssh-key-password>"
    exit 1
fi

SSH_PASSWORD=$1

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
  export IP_ADDRESS
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

# Copy sshkey from control node

info "Copying SSH key from control node..."
sshpass -p "$SSH_PASSWORD" scp "user@$IP_ADDRESS:~/.ssh/id_rsa" /root/.ssh/id_rsa

chmod 600 /root/.ssh/id_rsa
ssh-keyscan -H "$IP_ADDRESS" >> /root/.ssh/known_hosts

# Run node setup
./init.sh

# Join HCN
./join-hcn.sh

# Run benchmarks
./run-benchmarks.sh
