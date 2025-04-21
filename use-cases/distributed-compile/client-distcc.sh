#!/usr/bin/env bash
set -euo pipefail

#----------------------------------------------------------------
# Script: setup-distcc-client.sh
# Description: Installs and configures ccache and distcc wrapper,
#              sets up CMake launcher, dynamically generates ~/.distcc/hosts,
#              and runs CMake.
# Usage: sudo ./setup-distcc-client.sh [<path-to-source>]
#----------------------------------------------------------------

# Colors for log messages
green='\033[0;32m'
red='\033[0;31m'
nc='\033[0m'
info() { echo -e "${green}[INFO]${nc} $*"; }
error() { echo -e "${red}[ERROR]${nc} $*"; }

# Ensure the script is run as root
if [[ "$EUID" -ne 0 ]]; then
  error "Please run as root (e.g., sudo $0)"
  exit 1
fi

info "Installing prerequisites: ccache, distcc, cmake..."
apt-get update -qq
apt-get install -y -qq ccache distcc cmake

info "Configuring ccache..."
CCACHE_CONF="$HOME/.ccache/ccache.conf"
mkdir -p "$(dirname "$CCACHE_CONF")"
cat > "$CCACHE_CONF" << 'EOF'
max_size    = 25.0G
compression = true
prefix_command = /usr/local/bin/distcc-wrap.sh
EOF

info "Installing distcc wrapper script..."
WRAPPER="/usr/local/bin/distcc-wrap.sh"
cat > "$WRAPPER" << 'EOF'
#!/usr/bin/env sh
compiler=$(basename "$1"); shift
exec distcc "/usr/bin/${compiler}" "$@"
EOF
chmod +x "$WRAPPER"

info "Generating ~/.distcc/hosts from headless Service DNS..."
mkdir -p "$HOME/.distcc"
host_entries=$(getent ahosts distcc-headless.devtools.svc.cluster.local \  
  | awk '{print $1"/4"}' \  
  | sort -u \  
  | xargs)
echo "$host_entries" > "$HOME/.distcc/hosts"
info "Populated ~/.distcc/hosts: $host_entries"

# Export CC and CXX to use distcc by default
export CC=distcc
export CXX=distcc
info "Environment variables set: CC=$CC, CXX=$CXX"

# Run CMake
SOURCE_DIR="${1:-.}"
info "Running CMake with ccache launcher on $SOURCE_DIR"
cmake \
  -DCMAKE_C_COMPILER_LAUNCHER=ccache \
  -DCMAKE_CXX_COMPILER_LAUNCHER=ccache \
  "$SOURCE_DIR"
info "CMake configuration complete."

info "You can now build with: make -j$(nproc)"
info "Or compile single files directly via: gcc -c foo.c"
