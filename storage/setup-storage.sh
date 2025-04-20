#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: hcn-nfs-setup.sh
# Description: Sets up an NFS share from a specified block device, auto-detects
#              network range via eth0, configures exports, and starts the NFS server.
# ------------------------------------------------------------------------------

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

# Prompt for block device
read -rp "Enter the device to use (e.g., /dev/sda1): " DEVICE
if [ ! -b "$DEVICE" ]; then
  error "$DEVICE is not a valid block device."
  exit 1
fi

# Detect network range from eth0
ETH_IP=$(ip -4 addr show eth0 | grep inet | awk '{print $2}')
if [ -z "$ETH_IP" ]; then
  error "Could not detect IP address on eth0. Is the interface connected?"
  exit 1
fi


info "Installing dependencies..."
apt-get update -qq
apt-get install -y -qq ipcalc
apt-get install -y -qq nfs-kernel-server


NETWORK_RANGE=$(ipcalc -n "$ETH_IP" | grep Network | awk '{print $2}')
info "Detected network range: $NETWORK_RANGE"

# Set mount point and label
MOUNT_POINT="/mnt/shared_drive"
LABEL="shared_drive"

info "Mounting $DEVICE to $MOUNT_POINT..."
mkdir -p "$MOUNT_POINT"
mount "$DEVICE" "$MOUNT_POINT"

info "Labelling $DEVICE with $LABEL..."
e2label "$DEVICE" "$LABEL"

# Set permissions
info "Setting permissions on $MOUNT_POINT..."
chown -R nobody:nogroup "$MOUNT_POINT"
chmod -R 755 "$MOUNT_POINT"

# Configure /etc/exports
EXPORT_LINE="$MOUNT_POINT $NETWORK_RANGE(rw,sync,no_subtree_check,no_root_squash,insecure)"
if ! grep -Fxq "$EXPORT_LINE" /etc/exports; then
  info "Adding NFS export to /etc/exports..."
  echo "$EXPORT_LINE" >> /etc/exports
else
  info "Export already exists in /etc/exports"
fi

# Apply exports and restart NFS server
info "Applying export changes and restarting NFS server..."
exportfs -a
systemctl restart nfs-kernel-server

info "NFS setup complete. $DEVICE is now shared at $MOUNT_POINT to $NETWORK_RANGE"

info "Updating nfs-pv.yaml with NFS server IP..."

NFS_IP=$(hostname -I | awk '{print $1}')
info "Detected local IP: $NFS_IP"

# In-place replacement of the server line
sed -i "s/^\(\s*server:\s*\).*/\1${NFS_IP}/" nfs-pv.yaml
info "nfs-pv.yaml patched with IP: $NFS_IP"

info "Setting up PV and PVC for NFS..."
kubectl apply -f nfs-pv.yaml
kubectl apply -f nfs-pvc.yaml

info "NFS PV and PVC created successfully."
