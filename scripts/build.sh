#!/bin/bash
# =============================================================================
# OctaneOS build runner
# Run this INSIDE WSL2 after setup-build-env.sh has been run.
#
# Usage:
#   ./scripts/build.sh [CMD=<buildroot-target>] [make-opts...]
#
# Examples:
#   ./scripts/build.sh                        # full image build
#   ./scripts/build.sh CMD=linux-rebuild      # rebuild kernel only
#   ./scripts/build.sh CMD=linux-menuconfig   # open kernel config menu
#   ./scripts/build.sh CMD=mesa3d-rebuild     # rebuild a single package
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

# -----------------------------------------------------------------------------
# Batocera's top-level Makefile sets MAKEFLAGS += --no-builtin-rules (stored
# as the flag letter 'r').  GNU Make propagates MAKEFLAGS to every sub-make,
# so every package build inherits --no-builtin-rules.  Packages that use
# hand-written Makefiles (squashfs-tools, lz4, xxhash, zlib, ...) rely on
# the implicit %.o: %.c rule and fail with "No rule to make target '*.o'".
#
# Fix: place a thin make shim at the front of PATH that strips the 'r' flag
# from MAKEFLAGS before forwarding to the real make.  The shim calls the real
# make by absolute path so it cannot recurse into itself.
# -----------------------------------------------------------------------------
REAL_MAKE="$(command -v make)"
SHIM_DIR="$(mktemp -d)"
cat > "${SHIM_DIR}/make" << SHIM_EOF
#!/bin/bash
# Strip --no-builtin-rules / -r from inherited MAKEFLAGS.
# GNU Make stores the flag as 'r'; strip it from the leading flags word.
_mf="\${MAKEFLAGS}"
# Remove standalone -r or r at the start of the flags cluster
_mf="\$(echo "\$_mf" | sed 's/^\\(-*\\)\\([A-QS-Za-qs-z]*\\)r\\([A-Za-z]*\\)/\\1\\2\\3/')"
export MAKEFLAGS="\$_mf"
exec ${REAL_MAKE} "\$@"
SHIM_EOF
chmod +x "${SHIM_DIR}/make"
export PATH="${SHIM_DIR}:${PATH}"
trap 'rm -rf "${SHIM_DIR}"' EXIT

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# Add the Buildroot host/bin to PATH so host tools (mkimage, etc.) installed
# by Buildroot packages are available to post-install scripts that call them
# as bare commands without a full path.
# -----------------------------------------------------------------------------
HOST_BIN="${REPO_ROOT}/batocera/output/a733-cubie-a7s/host/bin"
if [ -d "${HOST_BIN}" ]; then
    export PATH="${HOST_BIN}:${PATH}"
fi
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

# %-build already depends on %-config in the Batocera Makefile, so no
# explicit pre-config step is needed — it runs automatically.

echo "[INFO] Starting build..."
make a733-cubie-a7s-build DIRECT_BUILD=1 "$@"
