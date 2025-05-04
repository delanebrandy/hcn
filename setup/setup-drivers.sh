#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: EDIT
# Description: EDIT
# ------------------------------------------------------------------------------

set -euo pipefail

# ------------------------------------------------------------------------------
# Logging and Root Check
# ------------------------------------------------------------------------------

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

info() { echo -e "${GREEN}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

info "Starting performance tests – expect high system load."

# ------------------------------------------------------------------------------
# Detect Environment (WSL2 or Bare Metal) and GPU Platform Support
# ------------------------------------------------------------------------------

SUPPORTED_PLATFORMS=()

is_wsl2() {
  grep -qi "microsoft" /proc/sys/kernel/osrelease
}

get_gpu_vendor() {
  if command -v nvidia-smi &>/dev/null; then
    local name
    name=$(nvidia-smi --query-gpu=name --format=csv,noheader | head -n1 | tr '[:upper:]' '[:lower:]')
    if echo "$name" | grep -q "nvidia"; then
      echo "nvidia"
      return
    fi
  fi

  if command -v clinfo &>/dev/null && clinfo | grep -qi intel; then
    echo "intel"
  else
    echo "unknown"
  fi
}

NODE_NAME=${HOSTNAME,,}

info "Detecting GPU environment..."

if is_wsl2; then
  info "WSL2 environment detected."
  GPU_VENDOR=$(get_gpu_vendor)

  if echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "NVIDIA GPU detected in WSL2. Installing CUDA + Vulkan support..."
    apt-get -yqq update > /dev/null 2>&1

    wget https://developer.download.nvidia.com/compute/cuda/repos/wsl-ubuntu/x86_64/cuda-wsl-ubuntu.pin
    mv cuda-wsl-ubuntu.pin /etc/apt/preferences.d/cuda-repository-pin-600
    wget https://developer.download.nvidia.com/compute/cuda/12.8.1/local_installers/cuda-repo-wsl-ubuntu-12-8-local_12.8.1-1_amd64.deb
    dpkg -i cuda-repo-wsl-ubuntu-12-8-local_12.8.1-1_amd64.deb
    cp /var/cuda-repo-wsl-ubuntu-12-8-local/cuda-*-keyring.gpg /usr/share/keyrings/
    apt-get -yqq update > /dev/null 2>&1
    apt-get -yqq  install cuda-toolkit-12-8 > /dev/null 2>&1

    curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg \
      && curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list | \
        sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' | \
        tee /etc/apt/sources.list.d/nvidia-container-toolkit.list

    apt-get -yqq update > /dev/null 2>&1

    apt-get -yqq install build-essential software-properties-common freeglut3-dev \
      mesa-vulkan-drivers mesa-utils vulkan-tools libgl1-mesa-glx libglu1-mesa-dev  \
      nvidia-container-toolkit libvulkan1 pocl-opencl-icd mesa-common-dev > /dev/null 2>&1

    kubectl label node "$NODE_NAME" cuda=true vulkan=true opengl=true --overwrite

    nvidia-ctk runtime configure --runtime=docker

    info "NVIDIA drivers installed. Please run: wsl --shutdown and re-run this script."

  elif echo "$GPU_VENDOR" | grep -qi "intel"; then
    info "Intel GPU detected in WSL2. Installing OpenCL + Vulkan (Dozen) support..."
    apt-get -yqq update > /dev/null 2>&1
    apt-get -yqq install gpg-agent wget > /dev/null 2>&1
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
      gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu focal-devel main' \
      > /etc/apt/sources.list.d/intel.gpu.focal.list
    apt-get -yqq update > /dev/null 2>&1
    apt-get -yqq install \
      intel-opencl-icd intel-level-zero-gpu level-zero mesa-utils libgl1-mesa-glx   \
      mesa-vulkan-drivers vulkan-tools libglu1-mesa-dev freeglut3-dev mesa-common-dev clinfo > /dev/null 2>&1

    kubectl label node "$NODE_NAME" opencl=true vulkan=true opengl=true --overwrite
    info "Intel GPU drivers installed. Please run: wsl --shutdown and re-run this script."

  else
    warn "Unsupported GPU vendor in WSL2: $GPU_VENDOR"
  fi

else
  info "Bare metal environment detected. Checking GPU platform support..."

  if command -v clinfo &>/dev/null; then
    info "OpenCL supported"
    kubectl label node "$NODE_NAME" opencl=true --overwrite
  fi
  if command -v nvidia-smi &>/dev/null; then
    info "CUDA supported"
    kubectl label node "$NODE_NAME" cuda=true --overwrite
  fi
  if command -v vulkaninfo &>/dev/null; then
    info "Vulkan supported"
    kubectl label node "$NODE_NAME" vulkan=true --overwrite
  fi
  if command -v glxinfo &>/dev/null || command -v glxgears &>/dev/null; then
    info "OpenGL supported"
    kubectl label node "$NODE_NAME" opengl=true --overwrite
  fi

  if [[ ${#SUPPORTED_PLATFORMS[@]} -eq 0 ]]; then
    warn "No GPU platforms detected - GPU benchmarks will be skipped."
  else
    info "Detected GPU platforms: ${SUPPORTED_PLATFORMS[*]}"
  fi
fi
