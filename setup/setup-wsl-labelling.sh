#!/bin/bash
# -------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: setup-wsl-labelling.sh
# Description: WSL2-specific setup for dynamic labelling via PowerShell
# -------------------------------------------------------------------------------

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'
info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

SERVICE_NAME="dynamic-labelling.service"
PWS_PATH="/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe"
SCRIPT0_NAME="monitor_status.py"
SCRIPT0_PATH="/usr/local/bin/$SCRIPT0_NAME"
SCRIPT1_NAME="wsl_dynamic_labelling.py"
SCRIPT1_PATH="/usr/local/bin/$SCRIPT1_NAME"
SERVICE_PATH="/etc/systemd/system/$SERVICE_NAME"

# Copy script into place
info "Installing dynamic node labelling script..."
if [[ ! -f "$SCRIPT0_PATH" || ! -f "$SCRIPT1_PATH" ]]; then
  cp "./setup/$SCRIPT0_NAME" "$SCRIPT0_PATH"
  cp "./setup/$SCRIPT1_NAME" "$SCRIPT1_PATH"
  chmod +x "$SCRIPT0_PATH"
  chmod +x "$SCRIPT1_PATH"
else
  info "Scripts already exist at $SCRIPT0_PATH and $SCRIPT1_PATH"
fi

info "Creating dynamic‐labelling wrapper script..."
cat <<EOF > /usr/local/bin/dynamic-labelling.sh
#!/bin/bash
"\$PWS_PATH" python "\$SCRIPT0_PATH" | python3 "\$SCRIPT1_PATH"
EOF
chmod +x /usr/local/bin/dynamic-labelling.sh

# Write systemd service file
info "Configuring systemd service..."
cat <<EOF > "$SERVICE_PATH"
[Unit]
Description=Dynamic Node Labelling Service (WSL2)
After=network.target

[Service]
ExecStart=/usr/local/bin/dynamic-labelling.sh
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


if systemctl is-active --quiet "$SERVICE_NAME"; then
  info "Dynamic node labelling is running and enabled on boot."
else
  error "Failed to start dynamic node labelling service."
fi
