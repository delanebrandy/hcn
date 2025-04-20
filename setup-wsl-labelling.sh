#!/bin/bash
# -------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling
# Script: EDIT
# Description: EDIT
# -------------------------------------------------------------------------------
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "Usage: $0 <control-plane-IP> <ssh-username>"
  exit 1
fi
IP_ADDRESS="$1"
SSH_UNAME="$2"

info() { echo -e "\033[1;32m[INFO]\033[0m $*"; }
error() { echo -e "\033[1;31m[ERROR]\033[0m $*"; }

SERVICE_NAME="dynamic-labelling.service"
SCRIPT_NAME="dynamic_labelling.py"
SCRIPT_PATH="/usr/local/bin/$SCRIPT_NAME"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Copy script into place
info "Installing dynamic node labelling script..."
if [[ ! -f "$SCRIPT_PATH" ]]; then
  cp "$SCRIPT_NAME" "$SCRIPT_PATH"
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
ExecStart=poweshell.exe python $SCRIPT_PATH $SSH_UNAME $IP_ADDRESS
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

# Check
if systemctl is-active --quiet "$SERVICE_NAME"; then
  info "Dynamic node labelling is running and enabled on boot."
else
  error "Failed to start dynamic node labelling service."
fi
