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

ORIG_USER="null" 
CONTROL_NODE=false
NET_DRIVE=false
NFS_PATH="/mnt/shared_drive"

#Check for --control-node flag
while [[ $# -gt 0 ]]; do
  case "$1" in
    --control-node)
      CONTROL_NODE=true
      shift
      ;;
    --net-drive)
      NET_DRIVE=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

# Ensure the script is run as root with --preserve-env=PATH
if (( EUID )); then
  exec sudo --preserve-env=PATH,USER,HOME "$0" "$@"
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
  read -p "Enter Control Planes's hostname: " HCN_HOSTNAME

  if wsl2; then
    info "Detected WSL2 environment"
    if powershell.exe python --version &>/dev/null; then
      info "Python is installed on Windows"
    else
      info "Installing Python via winget on Windows..."
      powershell.exe winget install --id Python.Python.3 --source winget
    fi
    IP_ADDRESS=$(powershell.exe python setup/hostname.py $HCN_HOSTNAME | tr -d '\r')
  else
    if [[ "$HCN_HOSTNAME" != *".local" ]]; then
      IP_ADDRESS="${HCN_HOSTNAME}.local"
    else
      IP_ADDRESS="$HCN_HOSTNAME"
    fi
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
  mkdir -p /root/.ssh
  ssh-keyscan -t rsa -H "$IP_ADDRESS" >> /root/.ssh/known_hosts
  sshpass -p "$SSH_PASSWORD" scp -o StrictHostKeyChecking=no "$SSH_UNAME@$IP_ADDRESS:~/.ssh/id_rsa" /root/.ssh/id_rsa
  chmod 600 /root/.ssh/id_rsa
}

save_info(){
  info "Saving global variables..."

  # Create global env script
  ENV_FILE="/etc/profile.d/hcn-env.sh"
  cat > "$ENV_FILE" << EOF 
#!/bin/sh
export HCN_HOSTNAME="${HCN_HOSTNAME:-control-plane}"
export HCN_IP_ADDRESS="${IP_ADDRESS:-$(hostname -I | awk '{print $1}')}"
export HCN_SSH_UNAME="${SSH_UNAME:-null}"
export HCN_NFS_PATH="${NFS_PATH:-null}"
export HCN_ORIG_USER="${USER:-user}"
export HOME_DIR="${HOME:-/root}"
EOF

  info "Created global env script at $ENV_FILE."
  chmod +x /etc/profile.d/hcn-env.sh
  source /etc/profile.d/hcn-env.sh

}

# Main Script Execution
main() {

  info "Starting HCN Setup"
  # Install dependencies
  info "Updating and upgrading system packages..."
  apt-get update -qq
  apt-get upgrade -y -qq

  info "Installing dependencies..."
  apt-get install -y -qq sshpass clinfo upower

  info "Installing Python dependencies…"
  apt-get install -y -qq python3 python3-pip python3-venv python3-psutil
  #pip3 install -r requirements.txt

  # Run node setup
  info "Running node setup..."
  if $CONTROL_NODE; then
    ./setup/init-control.sh
  else
    ssh_setup
    save_info
    ./setup/init.sh

    # Join HCN
    info "Joining HCN..."
    ./setup/join-hcn.sh
  fi

  # Set up monitoring
  info "Setting up monitoring..."
  ./setup/setup-labelling.sh

  # Run benchmarks
  info "Running benchmarks..."
  ./setup/node-perf.sh

  # Init static labelling
  python3 setup/static_labelling.py

  # Init dynamic labelling
  info "Setting up dynamic labelling..."
  if wsl2; then
  ./setup/setup-wsl-labelling.sh
  else
  ./setup/setup-labelling.sh
  fi

  if $NET_DRIVE; then
    if $CONTROL_NODE; then
      info "Setting up NFS share on host..."
      ./storage/setup-storage.sh
    else
      info "Joining NFS share at $IP_ADDRESS..."
      ./storage/join-storage.sh "$IP_ADDRESS"
    fi
  fi

}

main "$@"
