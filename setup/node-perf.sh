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

if [[ -z "${HOME_DIR:-}" ]]; then
  error "Required environment variable(s) not set: HOME_DIR"
  exit 1
fi

DIR="$HOME_DIR"

has_label() {
  kubectl get node $(hostname) \
    -o jsonpath="{.metadata.labels.$1}" 2>/dev/null | grep -qx true
}

info "Starting performance tests - expect high system load."

# ------------------------------------------------------------------------------
# Install Phoronix Test Suite
# ------------------------------------------------------------------------------
apt-get -yqq install php-cli php-xml unzip libelf-dev
if ! command -v phoronix-test-suite &> /dev/null; then
  info "Installing Phoronix Test Suite..."
  apt-get -yqq install wget
  wget https://github.com/phoronix-test-suite/phoronix-test-suite/releases/download/v10.8.4/phoronix-test-suite-10.8.4.tar.gz
  tar -xf phoronix-test-suite-10.8.4.tar.gz
  cd phoronix-test-suite
  ./install-sh
  cd ..
  rm -rf phoronix-test-suite*
else
  info "Phoronix Test Suite already installed."
fi

# ------------------------------------------------------------------------------
# Configure Phoronix Batch Mode
# ------------------------------------------------------------------------------

# Initialise Phoronix Test Suite
phoronix-test-suite > /dev/null 2>&1

if [[ ! -f $DIR/.phoronix-test-suite/user-config.xml ]]; then
  info "Configuring Phoronix batch mode..."
  printf 'y\nn\nn\nn\nn\nn\nn\n' | phoronix-test-suite batch-setup
fi

sed -i 's|<DynamicRunCount>TRUE</DynamicRunCount>|<DynamicRunCount>FALSE</DynamicRunCount>|' $DIR/.phoronix-test-suite/user-config.xml

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

if has_label opengl; then
  phoronix-test-suite batch-benchmark unigine-heaven
fi
if has_label opencl; then
  phoronix-test-suite batch-benchmark juliagpu  ##blender inteloptic
fi
if has_label vulkan; then
  phoronix-test-suite batch-benchmark vkmark 
fi
if has_label cuda; then
  phoronix-test-suite batch-benchmark octanebench
fi

info "Benchmarking complete!"
