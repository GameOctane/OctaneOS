#!/bin/bash
# =============================================================================
# OctaneOS build runner
# Run this INSIDE WSL2 after setup-build-env.sh has been run.
#
# Usage:
#   ./scripts/build.sh [make-args]
#
# Examples:
#   ./scripts/build.sh                        # full build
#   ./scripts/build.sh linux-rebuild          # rebuild kernel only
#   ./scripts/build.sh linux-menuconfig       # open kernel config menu
# =============================================================================

set -e

# -----------------------------------------------------------------------------
# WSL2 injects Windows paths (e.g. /mnt/c/Program Files/...) into PATH.
# Buildroot rejects any PATH entry containing spaces, tabs, or newlines.
# Strip them out before invoking make.
# -----------------------------------------------------------------------------
CLEAN_PATH=""
IFS=: read -ra _PATH_ENTRIES <<< "$PATH"
for _entry in "${_PATH_ENTRIES[@]}"; do
    case "$_entry" in
        *\ * | *$'\t'* | *$'\n'*) ;;   # skip entries with whitespace
        *) CLEAN_PATH="${CLEAN_PATH:+${CLEAN_PATH}:}${_entry}" ;;
    esac
done
export PATH="$CLEAN_PATH"
unset CLEAN_PATH _PATH_ENTRIES _entry

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BATOCERA_DIR="${REPO_ROOT}/batocera"

if [ ! -d "${BATOCERA_DIR}/.git" ] && [ ! -f "${BATOCERA_DIR}/.git" ]; then
    echo "[ERROR] Batocera submodule not initialized."
    echo "        Run: ./scripts/setup-build-env.sh"
    exit 1
fi

# Ensure symlinks are in place
BOARD_DST="${BATOCERA_DIR}/board/batocera/allwinner/a733"
CONFIG_DST="${BATOCERA_DIR}/configs/batocera-a733-cubie-a7s.board"

if [ ! -e "${BOARD_DST}" ] || [ ! -e "${CONFIG_DST}" ]; then
    echo "[INFO] Symlinks missing — running setup..."
    "${REPO_ROOT}/scripts/setup-build-env.sh"
fi

cd "${BATOCERA_DIR}"

# If no defconfig has been applied yet, apply it first
if [ ! -f ".config" ]; then
    echo "[INFO] Configuring Buildroot for a733-cubie-a7s..."
    make a733-cubie-a7s-config DIRECT_BUILD=1
fi

echo "[INFO] Starting build..."
make DIRECT_BUILD=1 "$@"
