#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: Node Performance Benchmarking Script with GPU Support (WSL2 & Bare Metal)
# Description: Installs Phoronix Test Suite, detects environment (WSL2/bare metal),
#              installs appropriate GPU drivers, runs CPU/GPU benchmarks, and exports results.
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
    echo "nvidia"
  elif command -v clinfo &>/dev/null && clinfo | grep -qi intel; then
    echo "intel"
  else
    echo "unknown"
  fi
}

info "Detecting GPU environment..."

if is_wsl2; then
  info "WSL2 environment detected."
  GPU_VENDOR=$(get_gpu_vendor)

  if echo "$GPU_VENDOR" | grep -qi "nvidia"; then
    info "NVIDIA GPU detected in WSL2. Installing CUDA + Vulkan support..."
    apt-get update
    apt-get install -y build-essential software-properties-common \
      mesa-vulkan-drivers mesa-utils vulkan-tools \
      cuda-toolkit-12-3 libvulkan1

    SUPPORTED_PLATFORMS=("cuda" "vulkan" "opengl")
    info "NVIDIA drivers installed. Please run: wsl --shutdown and re-run this script."
    exit 0

  elif echo "$GPU_VENDOR" | grep -qi "intel"; then
    info "Intel GPU detected in WSL2. Installing OpenCL + Vulkan (Dozen) support..."
    apt-get update
    apt-get install -y gpg-agent wget
    wget -qO - https://repositories.intel.com/graphics/intel-graphics.key | \
      gpg --dearmor -o /usr/share/keyrings/intel-graphics.gpg
    echo 'deb [arch=amd64 signed-by=/usr/share/keyrings/intel-graphics.gpg] https://repositories.intel.com/graphics/ubuntu focal-devel main' \
      > /etc/apt/sources.list.d/intel.gpu.focal.list
    apt-get update
    apt-get install -y \
      intel-opencl-icd intel-level-zero-gpu level-zero \
      mesa-vulkan-drivers vulkan-tools clinfo

    SUPPORTED_PLATFORMS=("opencl" "vulkan" "opengl")
    info "Intel GPU drivers installed. Please run: wsl --shutdown and re-run this script."
    exit 0
  else
    warn "Unsupported GPU vendor in WSL2: $GPU_VENDOR"
    exit 1
  fi

else
  info "Bare metal environment detected. Checking GPU platform support..."

  if command -v clinfo &>/dev/null; then
    info "✔ OpenCL supported"
    SUPPORTED_PLATFORMS+=("opencl")
  fi
  if command -v nvidia-smi &>/dev/null; then
    info "✔ CUDA supported"
    SUPPORTED_PLATFORMS+=("cuda")
  fi
  if command -v vulkaninfo &>/dev/null; then
    info "✔ Vulkan supported"
    SUPPORTED_PLATFORMS+=("vulkan")
  fi
  if command -v glxinfo &>/dev/null || command -v glxgears &>/dev/null; then
    info "✔ OpenGL supported"
    SUPPORTED_PLATFORMS+=("opengl")
  fi

  if [[ ${#SUPPORTED_PLATFORMS[@]} -eq 0 ]]; then
    warn "No GPU platforms detected – GPU benchmarks will be skipped."
  else
    info "Detected GPU platforms: ${SUPPORTED_PLATFORMS[*]}"
  fi
fi

# ------------------------------------------------------------------------------
# Install Phoronix Test Suite
# ------------------------------------------------------------------------------

if ! command -v phoronix-test-suite &> /dev/null; then
  info "Installing Phoronix Test Suite..."
  apt-get install -y wget
  wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite-10.8.4.tar.gz
  tar -xvf phoronix-test-suite-10.8.4.tar.gz
  cd phoronix-test-suite-10.8.4
  ./install-sh
  cd ..
  rm -rf phoronix-test-suite-10.8.4*
else
  info "Phoronix Test Suite already installed."
fi

# ------------------------------------------------------------------------------
# Configure Phoronix Batch Mode
# ------------------------------------------------------------------------------

if [[ ! -f ~/.phoronix-test-suite/user-config.xml ]]; then
  info "Configuring Phoronix batch mode..."
  printf 'y\nn\nn\nn\nn\nn\nn\n' | phoronix-test-suite batch-setup
fi

# ------------------------------------------------------------------------------
# Run CPU Benchmarks
# ------------------------------------------------------------------------------

info "Running CPU benchmarks..."
phoronix-test-suite batch-benchmark build-linux-kernel <<< 1
#phoronix-test-suite batch-benchmark ffmpeg <<< 1

# ------------------------------------------------------------------------------
# Run GPU Benchmarks (Conditional)
# ------------------------------------------------------------------------------

info "Running GPU benchmarks (if supported)..."

if [[ " ${SUPPORTED_PLATFORMS[*]} " =~ "opengl" ]]; then
  phoronix-test-suite batch-benchmark unigine-heaven
fi
if [[ " ${SUPPORTED_PLATFORMS[*]} " =~ "opencl" ]]; then
  phoronix-test-suite batch-benchmark juliagpu  ##blender inteloptic
fi
if [[ " ${SUPPORTED_PLATFORMS[*]} " =~ "vulkan" ]]; then
  phoronix-test-suite batch-benchmark vkmark 
fi
if [[ " ${SUPPORTED_PLATFORMS[*]} " =~ "cuda" ]]; then
  phoronix-test-suite batch-benchmark octanebench
fi

# ------------------------------------------------------------------------------
# Export Results to JSON
# ------------------------------------------------------------------------------

mkdir -p ./results
info "Exporting all benchmark results to JSON..."

for result in $(phoronix-test-suite list-results | awk '{print $1}'); do
  if [[ -n "$result" ]]; then
    phoronix-test-suite result-file-to-json "$result" > "./results/${result}.json"
    info "→ Exported $result to ./results/${result}.json"
  fi
done

info "All results exported to ./results/"

#send results to control node
info "Sending results to control node..."

scp -r ./results/* "$user@$IP_ADDRESS:~/benchmarks/"
if [[ $? -ne 0 ]]; then
  error "Failed to send results to control node."
  exit 1
fi

info "Cleaning up temporary files..."
rm -rf ~/.phoronix-test-suite/test-results/*
rm -rf ~/.phoronix-test-suite/installed-tests/*
rm -rf ~/.phoronix-test-suite/installed-packages/*
rm -rf ~/.phoronix-test-suite/installed-tests-*

info "Benchmarking complete!"
