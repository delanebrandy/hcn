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

SSH_KEY_PASSWORD=$1

# Run node setup
./init.sh

# Join HCN
./join-hcn.sh "$SSH_KEY_PASSWORD"

# Run benchmarks
./run-benchmarks.sh
