#!/bin/bash
# =============================================================================
# OctaneOS build environment setup
# Supports: Ubuntu/Debian (GitHub Actions, WSL2), Arch/SteamOS (Steam Deck)
#
# Usage:
#   chmod +x scripts/setup-build-env.sh
#   ./scripts/setup-build-env.sh
#
# SteamOS note: run  sudo steamos-readonly disable  before this script,
# then  sudo steamos-readonly enable  after if desired.
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
# 3. Install build dependencies — detects Ubuntu/Debian vs Arch/SteamOS
#    Skipped inside Flatpak (e.g. VS Code on SteamOS) — sudo doesn't work there
#    because libsudo_util.so.0 is absent from the Flatpak runtime. Install deps
#    from Konsole (the native host terminal) before running the build.
# -----------------------------------------------------------------------------
if [ -n "${FLATPAK_ID}" ]; then
    echo "[INFO] Flatpak environment detected — skipping package install."
    echo "       If build deps are missing, install them from Konsole (not VS Code terminal):"
    echo "         sudo steamos-readonly disable"
    echo "         sudo pacman -Sy --noconfirm --needed bc bison base-devel cpio dosfstools \\"
    echo "           file flex gawk git ncurses openssl mtools python rsync unzip wget libnewt"
    echo "         sudo steamos-readonly enable"
else
    echo "[INFO] Installing build dependencies..."
    if command -v apt-get &>/dev/null; then
        sudo apt-get update -qq
        sudo apt-get install -y \
            bc \
            bison \
            build-essential \
            cpio \
            dosfstools \
            file \
            flex \
            gawk \
            git \
            libncurses-dev \
            libssl-dev \
            mtools \
            python3 \
            python3-dev \
            rsync \
            unzip \
            wget \
            whiptail
    elif command -v pacman &>/dev/null; then
        # Arch Linux / SteamOS
        # Requires: sudo steamos-readonly disable  (SteamOS only, before running this script)
        sudo pacman -Sy --noconfirm --needed \
            bc \
            bison \
            base-devel \
            cpio \
            dosfstools \
            file \
            flex \
            gawk \
            git \
            ncurses \
            openssl \
            mtools \
            python \
            rsync \
            unzip \
            wget \
            libnewt
    else
        echo "[WARNING] No supported package manager found (apt-get or pacman)."
        echo "          Install manually: bc bison build-essential cpio dosfstools"
        echo "                           file flex gawk git libncurses-dev libssl-dev"
        echo "                           mtools python3 rsync unzip wget whiptail"
    fi
fi

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

# -----------------------------------------------------------------------------
# 6. Create output directories and seed local.mk
#    Matches what CI does before invoking make.
# -----------------------------------------------------------------------------
echo "[INFO] Preparing output directories..."

OUTPUT_DIR="${REPO_ROOT}/batocera/output/a733-cubie-a7s"
BR_OUTPUT_DIR="${REPO_ROOT}/batocera/buildroot/batocera/output/a733-cubie-a7s/a733-cubie-a7s"
LOCAL_MK_SRC="${REPO_ROOT}/board/batocera/allwinner/a733/local.mk"

mkdir -p "${OUTPUT_DIR}"
mkdir -p "${BR_OUTPUT_DIR}"

if [ -f "${LOCAL_MK_SRC}" ]; then
    cp "${LOCAL_MK_SRC}" "${OUTPUT_DIR}/local.mk"
    cp "${LOCAL_MK_SRC}" "${BR_OUTPUT_DIR}/local.mk"
    echo "[INFO] local.mk seeded to both output dirs."
fi

# -----------------------------------------------------------------------------
# 7. Pre-seed download cache for packages not on standard mirrors
#    ecwolf source is hosted externally — fetch it now so the build doesn't
#    stall waiting for a non-standard URL.
# -----------------------------------------------------------------------------
echo "[INFO] Pre-seeding download cache..."
mkdir -p "${REPO_ROOT}/batocera/dl"

LIBTOOL_URL="https://ftp.gnu.org/pub/gnu/libtool/libtool-2.4.7.tar.xz"
LIBTOOL_DEST="${REPO_ROOT}/batocera/dl/libtool-2.4.7.tar.xz"
if [ ! -f "${LIBTOOL_DEST}" ]; then
    echo "[INFO] Downloading libtool-2.4.7..."
    wget -q -O "${LIBTOOL_DEST}" "${LIBTOOL_URL}" || echo "[WARNING] libtool download failed — will retry during build."
fi

ECWOLF_URL="https://github.com/suckbluefrog/Batocera-Multilib/releases/download/7-4-2026/ecwolf-source.tar.gz"
ECWOLF_TMP="/tmp/ecwolf-source.tar.gz"
if ! ls "${REPO_ROOT}/batocera/dl/ecwolf"* &>/dev/null 2>&1; then
    echo "[INFO] Downloading ecwolf source..."
    wget -q -O "${ECWOLF_TMP}" "${ECWOLF_URL}" && \
        tar xzf "${ECWOLF_TMP}" -C "${REPO_ROOT}/batocera/dl/" && \
        rm -f "${ECWOLF_TMP}" || \
        echo "[WARNING] ecwolf download failed — build will attempt it later."
fi

echo ""
echo "=== Setup complete ==="
echo ""
echo "Next steps:"
echo "  ./scripts/build.sh"
echo ""
echo "First build will take several hours (cross-compiling everything from source)."
