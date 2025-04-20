#!/bin/bash
# -------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: EDIT
# Description: EDIT
# -------------------------------------------------------------------------------

# Colors for log messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

ORIG_USER="${SUDO_USER:-$USER}" 
CONTROL_NODE=false

#Check for --control-node flag
if [[ "$1" == "--control-node" ]]; then
  CONTROL_NODE=true
  shift
fi

# Ensure the script is run as root with --preserve-env=PATH
if (( EUID )); then
  exec sudo --preserve-env=PATH "$0" "$@"
fi

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

  if [[ -z "$IP_ADDRESS" ]]; then
    error "Failed to retrieve IP address"
    exit 1
  fi

  export IP_ADDRESS
}

get_control_info() {
  if [[ -z "${SSH_UNAME:-}" ]]; then
    read -p "Control Node's Username: " SSH_UNAME
  fi

  # Prompt for SSH password if not already set
  if [[ -z "${SSH_PASSWORD:-}" ]]; then
    read -s -p "Enter password for $SSH_UNAME: " SSH_PASSWORD
    echo
  fi
}

ssh_setup() {
  info "Connecting to HCN, communicating with control node..."

  # Get control node IP
  get_ip
  info "Control node IP: $IP_ADDRESS"

  # Securely retrieve SSH password
  get_control_info

  # Copy sshkey from control node
  info "Copying SSH key from control node..."
  sshpass -p "$SSH_PASSWORD" scp "$SSH_UNAME@$IP_ADDRESS:~/.ssh/id_rsa" /root/.ssh/id_rsa

  # Restrict permissions for the SSH key
  chmod 600 /root/.ssh/id_rsa
  ssh-keyscan -H "$IP_ADDRESS" >> /root/.ssh/known_hosts
}

# Main Script Execution
main() {

  info "Starting HCN Setup"
  # Install dependencies
  info "Updating and upgrading system packages..."
  apt-get update -qq
  apt-get upgrade -y -qq

  info "Installing dependencies..."
  apt-get install -y -qq sshpass clinfo upower openssh-client openssh-server

  info "Installing Python dependencies…"
  apt-get install -y -qq python3 python3-pip python3-venv python3-psutil
  #pip3 install -r requirements.txt


  # Run node setup
  info "Running node setup..."
  if $CONTROL_NODE; then
    ./init-control.sh
  else
    ssh_setup
    ./init.sh

    # Join HCN
    info "Joining HCN..."
    ./join-hcn.sh "$IP_ADDRESS" "$SSH_UNAME"
  fi

  # Set up monitoring
  info "Setting up monitoring..."
  ./setup-labelling.sh

  # Run benchmarks
  info "Running benchmarks..."
  ./node-perf.sh

  # Init static labelling
  python3 static_labelling.py

  # Init dynamic labelling
  info "Setting up dynamic labelling..."
  if wsl2; then
  ./setup-wsl-labelling.sh $ORIG_USER $IP_ADDRESS $SSH_UNAME 
  else
  ./setup-labelling.sh $ORIG_USER $IP_ADDRESS $SSH_UNAME 
  fi
}

main "$@"
