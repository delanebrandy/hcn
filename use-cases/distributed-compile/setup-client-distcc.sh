#!/usr/bin/env bash
set -eo pipefail

#---------------------------------------------------------------
# Script: client-distcc.sh
# Description: Sets up distcc + ccache and installs systemd
#              service + timer to refresh ~/.distcc/hosts.
#---------------------------------------------------------------

# Logging
GREEN='\033[0;32m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if (( EUID )); then
  exec sudo --preserve-env=PATH,USER,HOME "$0" "$@"
fi

# --- 1. Install dependencies ---
info "Installing distcc and ccache..."
apt-get update -qq
apt-get install -y -qq ccache distcc

if [ ! -e "/.distcc/hosts" ]; then
  info "File /.distcc/hosts does not exist. Creating it..."
  mkdir -p "/.distcc"
  touch "/.distcc/hosts"
fi
chmod 777 "/.distcc/hosts"

# --- 2. Configure ccache ---
info "Configuring ccache..."
CCACHE_CONF="$HOME/.ccache/ccache.conf"
mkdir -p "$(dirname "$CCACHE_CONF")"
cat > "$CCACHE_CONF" <<EOF
max_size    = 25.0G
compression = true
prefix_command = /usr/local/bin/distcc-wrap.sh
EOF


# Create global ccache config
info "Creating global cc config..."
ENV_FILE="/etc/profile.d/distcc-env.sh"
cat > "$ENV_FILE" <<EOF
#!/bin/sh
export CC=distcc
export CXX=distcc
export PATH="/usr/lib/ccache:\$PATH"
EOF
chmod +x "$ENV_FILE"
info "Created global env script at $ENV_FILE."
source "$ENV_FILE"

# Create symlinks for ccache
info "Creating symlinks for ccache..."
if command -v update-ccache-symlinks >/dev/null 2>&1; then
  update-ccache-symlinks
else
  ln -sf /usr/bin/ccache /usr/lib/ccache/gcc
  ln -sf /usr/bin/ccache /usr/lib/ccache/g++
  ln -sf /usr/bin/ccache /usr/lib/ccache/clang
  ln -sf /usr/bin/ccache /usr/lib/ccache/clang++
fi
info "Linked ccache compiler wrappers."

# --- 3. Create wrapper ---
info "Creating distcc wrapper..."
WRAPPER="/usr/local/bin/distcc-wrap.sh"
cat > "$WRAPPER" <<'EOF'
#!/bin/bash
compiler=$(basename "$1"); shift
exec distcc "/usr/bin/${compiler}" "$@"
EOF
chmod +x "$WRAPPER"


# --- 4. Create systemd service ---
install -m 777 ./client-refresh-hosts.sh /usr/local/bin/

info "Creating systemd service..."
SERVICE_PATH="/etc/systemd/system/update-distcc-hosts.service"
cat > "$SERVICE_PATH" <<EOF
[Unit]
Description=Update distcc hosts from Kubernetes
After=network-online.target
Wants=network-online.target

[Service]
Type=oneshot
User=${USER}
ExecStart=/usr/local/bin/client-refresh-hosts.sh
EOF

# --- 5. Create systemd timer ---
info "Creating systemd timer..."
TIMER_PATH="/etc/systemd/system/update-distcc-hosts.timer"
cat > "$TIMER_PATH" <<EOF
[Unit]
Description=Run distcc host update periodically

[Timer]
OnBootSec=2min
OnUnitActiveSec=5min
Unit=update-distcc-hosts.service

[Install]
WantedBy=timers.target
EOF

# --- 6. Reload + enable ---
info "Enabling systemd timer..."
systemctl daemon-reexec
systemctl daemon-reload
systemctl enable --now update-distcc-hosts.timer

# --- 7. Output ---
info "Setup complete!"
