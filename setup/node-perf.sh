#!/bin/bash
# ------------------------------------------------------------------------------
# Author: Delane Brandy
# Email:  d.brandy@se21.qmul.ac.uk
# Script: node-perf.sh
# Description: Run performance tests on a node using Phoronix Test Suite
# Usage: ./node-perf.sh [--update]
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

sed -i 's|<DynamicRunCount>TRUE</DynamicRunCount>|<DynamicRunCount>FALSE</DynamicRunCount>|' $HOME/.phoronix-test-suite/user-config.xml

# ------------------------------------------------------------------------------
# Run CPU Benchmarks
# ------------------------------------------------------------------------------

info "Running CPU benchmarks..."
timeout 1h phoronix-test-suite batch-benchmark build-linux-kernel <<< 1
if [ $STATUS -eq 124 ]; then
  kubectl label node "${HOSTNAME,,}" cpu=low --overwrite
fi

# ------------------------------------------------------------------------------
# Run GPU Benchmarks (Conditional)
# ------------------------------------------------------------------------------

info "Running GPU benchmarks (if supported)..."

if has_label opengl; then
  timeout 1h printf "11\n1\n" | phoronix-test-suite batch-benchmark unigine-heaven
  STATUS=$?
  if [ $STATUS -eq 124 ]; then
  kubectl label node "${HOSTNAME,,}" opengl-perf=low --overwrite
  fi
fi
if has_label opencl; then
  timeout 1h phoronix-test-suite batch-benchmark juliagpu
  STATUS=$?
  if [ $STATUS -eq 124 ]; then
  kubectl label node "${HOSTNAME,,}" opencl-perf=low --overwrite
  fi
fi
if has_label vulkan; then
  timeout 1h phoronix-test-suite batch-benchmark vkpeak
  STATUS=$?
  if [ $STATUS -eq 124 ]; then
  kubectl label node "${HOSTNAME,,}" vulkan-perf=low --overwrite
  fi
fi
if has_label cuda; then
  timeout 1h phoronix-test-suite batch-benchmark octanebench
  STATUS=$?
  if [ $STATUS -eq 124 ]; then
  kubectl label node "${HOSTNAME,,}" cuda-perf=low --overwrite
  fi
fi

info "Benchmarking complete!"

if $UPDATE; then
  ./static_labelling.py --node $(uname -n | tr '[:upper:]' '[:lower:]')
fi
