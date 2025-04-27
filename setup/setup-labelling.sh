#!/bin/bash
# -------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: setup-dynamic-labelling.sh
# Description: Installs and enables dynamic labelling as a systemd service.
# -------------------------------------------------------------------------------

set -euo pipefail

# Colors for log messages
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Validate required environment variables
if [[ -z "${HCN_IP_ADDRESS:-}" || -z "${HCN_SSH_UNAME:-}" ]]; then
  error "Missing environment variables: HCN_IP_ADDRESS or HCN_SSH_UNAME"
  exit 1
fi

IP_ADDRESS="$HCN_IP_ADDRESS"
SSH_UNAME="$HCN_SSH_UNAME"

SERVICE_NAME="dynamic-labelling.service"
SCRIPT_NAME="dynamic_labelling.py"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Copy script into place
info "Installing dynamic node labelling script..."
if [[ ! -f "$SCRIPT_PATH" ]]; then
  cp "./$SCRIPT_NAME" "$SCRIPT_PATH"
  chmod +x "$SCRIPT_PATH"
else
  info "Script already exists at $SCRIPT_PATH"
fi

# Write systemd service file
info "Configuring systemd service..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Dynamic Node Labelling Service
After=network.target

[Service]
ExecStart=/usr/bin/python3 $SCRIPT_PATH $SSH_UNAME $IP_ADDRESS
Restart=on-failure
User=root
Environment=PATH=/usr/bin:/usr/local/bin
WorkingDirectory=/usr/local/bin

[Install]
WantedBy=multi-user.target
EOF

# Reload and enable
info "Enabling and starting the service..."
systemctl daemon-reload
systemctl enable --now "$SERVICE_NAME"

# Check service status
if systemctl is-active --quiet "$SERVICE_NAME"; then
  info "Dynamic node labelling is running and enabled on boot."
else
  error "Failed to start dynamic node labelling service."
fi
