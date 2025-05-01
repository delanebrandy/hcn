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
apt-get -yqq install nfs-common > /dev/null 2>&1

info "Creating mount point..."
mkdir -p $MOUNT_POINT
mount -t nfs4 $SERVER_IP:$MOUNT_POINT $MOUNT_POINT

info "Done! Mounted NFS share at $LOCAL_PATH"

info "Joining Registry..."

if grep -q '"insecure-registries"' /etc/docker/daemon.json; then
  sed -i "/\"insecure-registries\"/c\    \"insecure-registries\": [\"$SERVER_IP:30000\"]," /etc/docker/daemon.json
else
  sed -i '1i\    "insecure-registries": ["'"$SERVER_IP:30000"'"],' /etc/docker/daemon.json
fi

systemctl restart docker
info "Docker restarted with new insecure registry."
