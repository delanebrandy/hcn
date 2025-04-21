#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: generate-nfs-join.sh
# Description: Generates a client-side NFS mount command given the server IP.
# ------------------------------------------------------------------------------

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }

# Check for IP argument
if [[ -z "$1" ]]; then
  echo "Usage: $0 <NFS_SERVER_IP>"
  exit 1
fi

SERVER_IP="$1"
MOUNT_POINT="/mnt/shared_drive"

info "Installing NFS client..."
apt-get -y -qq install nfs-common

info "Creating mount point..."
mkdir -p $MOUNT_POINT 
mount -t nfs4 $SERVER_IP:$MOUNT_POINT $MOUNT_POINT 

info "Done! Mounted NFS share at $LOCAL_PATH"
