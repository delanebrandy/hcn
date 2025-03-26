#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling
# Description: Bootstraps a system with Docker, Kubernetes, and cri-dockerd,
#              includes WSL2 detection, systemd setup, and system verification.
# ------------------------------------------------------------------------------
set -e

# Run node setup
./init.sh

# Run benchmarks
./run-benchmarks.sh

# Join HCN
./join-hcn.sh
