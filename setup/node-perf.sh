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

UPDATE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --update)
      UPDATE=true
      shift
      ;;
    *)
      break
      ;;
  esac
done

DIR="$HOME_DIR"

has_label() {
  kubectl get node "${HOSTNAME,,}" \
    -o jsonpath="{.metadata.labels.$1}" 2>/dev/null | grep -qx true
}

info "Starting performance tests - expect high system load."

# ------------------------------------------------------------------------------
# Configure Phoronix Batch Mode
# ------------------------------------------------------------------------------

# Initialise Phoronix Test Suite
phoronix-test-suite > /dev/null 2>&1

info "Configuring Phoronix batch mode..."
printf 'y\nn\nn\nn\nn\nn\nn\n' | phoronix-test-suite batch-setup

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
  printf "11\n1\n" | phoronix-test-suite batch-benchmark unigine-heaven
fi
if has_label opencl; then
  phoronix-test-suite batch-benchmark juliagpu
fi
if has_label vulkan; then
  phoronix-test-suite batch-benchmark vkpeak
fi
if has_label cuda; then
  phoronix-test-suite batch-benchmark octanebench
fi

info "Benchmarking complete!"

if $UPDATE; then
  ./static_labelling.py --node $(uname -n | tr '[:upper:]' '[:lower:]')
fi
