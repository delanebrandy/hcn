#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Kubernetes + Docker Init with WSL2 Handling + Real-ESRGAN Video Client Setup
# Description: Bootstraps a system with Docker, Kubernetes, cri-dockerd, and client env,
#              includes WSL2 detection, systemd setup, system verification, and
#              Python virtual environment for video_upscale_client.py.
# ------------------------------------------------------------------------------
set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

info "Starting HCN Setup, installing dependencies..."

info "Creating Python virtual environment for video_upscale_client..."
python3 -m venv /opt/video_client_venv
source /opt/video_client_venv/bin/activate

info "Upgrading pip in client venv..."
pip install --upgrade pip

info "Installing Python dependencies: requests, tqdm..."
pip install requests tqdm

info "Verifying ffmpeg installation for client..."
if ! command -v ffmpeg &> /dev/null; then
  error "ffmpeg not found. Please install ffmpeg via your package manager."
  error "For Ubuntu/Debian: apt update && apt install ffmpeg"
  exit 1
else
  info "ffmpeg found: $(ffmpeg -version | head -n1)"
fi

info "Client setup complete. Activate with: source /opt/video_client_venv/bin/activate"
info "Then run: python video_upscale_client.py --input input.mp4 --output out.mp4 --server http://localhost:5000"
