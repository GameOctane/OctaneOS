#!/bin/bash
# =============================================================================
# OctaneOS build environment setup
# Run this INSIDE WSL2 (Ubuntu 22.04 recommended), NOT on Windows directly.
# The Batocera build system requires a Linux host.
#
# Usage:
#   chmod +x scripts/setup-build-env.sh
#   ./scripts/setup-build-env.sh
# =============================================================================

set -e

echo "=== OctaneOS build environment setup ==="

# -----------------------------------------------------------------------------
# 1. Check we are running in WSL2 or Linux (not native Windows)
# -----------------------------------------------------------------------------
if grep -qi microsoft /proc/version 2>/dev/null; then
    echo "[INFO] Running in WSL2 — good."
elif [[ "$(uname)" == "Linux" ]]; then
    echo "[INFO] Running on Linux — good."
else
    echo "[ERROR] This script must be run inside WSL2 or a Linux machine."
    echo "        Open WSL2, navigate to your repo, and re-run."
    exit 1
fi

# -----------------------------------------------------------------------------
# 2. Warn if running from /mnt/c/ (Windows filesystem — slow builds)
# -----------------------------------------------------------------------------
if [[ "$(pwd)" == /mnt/* ]]; then
    echo ""
    echo "[WARNING] You are building from the Windows filesystem (/mnt/...)."
    echo "          WSL2 I/O to Windows paths is very slow for large builds."
    echo "          Recommended: clone the repo inside WSL2 filesystem instead:"
    echo "              cd ~"
    echo "              git clone <your-repo-url> OctaneOS"
    echo "              cd OctaneOS && ./scripts/setup-build-env.sh"
    echo ""
    read -rp "Continue anyway? [y/N] " confirm
    [[ "${confirm,,}" == "y" ]] || exit 0
fi

# -----------------------------------------------------------------------------
# 3. Install build dependencies (Ubuntu/Debian)
# -----------------------------------------------------------------------------
echo "[INFO] Installing build dependencies..."
sudo apt-get update
sudo apt-get install -y \
    bc \
    bison \
    build-essential \
    cpio \
    file \
    flex \
    gawk \
    git \
    libncurses-dev \
    libssl-dev \
    python3 \
    python3-dev \
    rsync \
    unzip \
    wget \
    whiptail

# -----------------------------------------------------------------------------
# 4. Initialize Batocera submodule
# -----------------------------------------------------------------------------
echo "[INFO] Initializing Batocera submodule..."
git submodule update --init --recursive batocera

# -----------------------------------------------------------------------------
# 5. Symlink OctaneOS board configs into the Batocera tree
#    This makes our configs visible to Batocera's build system without
#    modifying the Batocera submodule itself.
# -----------------------------------------------------------------------------
echo "[INFO] Linking OctaneOS board configs into Batocera tree..."

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BATOCERA_DIR="${REPO_ROOT}/batocera"

# Board files
BOARD_SRC="${REPO_ROOT}/board/batocera/allwinner/a733"
BOARD_DST="${BATOCERA_DIR}/board/batocera/allwinner/a733"
if [ ! -e "${BOARD_DST}" ]; then
    ln -s "${BOARD_SRC}" "${BOARD_DST}"
    echo "[INFO] Linked: board/batocera/allwinner/a733"
else
    echo "[INFO] Board symlink already exists — skipping."
fi

# .board config file
CONFIG_SRC="${REPO_ROOT}/configs/batocera-a733-cubie-a7s.board"
CONFIG_DST="${BATOCERA_DIR}/configs/batocera-a733-cubie-a7s.board"
if [ ! -e "${CONFIG_DST}" ]; then
    ln -s "${CONFIG_SRC}" "${CONFIG_DST}"
    echo "[INFO] Linked: configs/batocera-a733-cubie-a7s.board"
else
    echo "[INFO] Config symlink already exists — skipping."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  1. Run the build:  ./scripts/build.sh"
echo "  OR"
echo "  1. cd batocera"
echo "  2. make batocera-a733-cubie-a7s_defconfig"
echo "  3. make"
echo ""
echo "First build will take several hours (cross-compiling everything from source)."
