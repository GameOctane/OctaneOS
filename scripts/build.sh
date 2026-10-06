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
#   ./scripts/build.sh --sync-kernel-only      # only re-sync the kernel tree if its inputs changed
#   OCTANE_DEV_KEY=1 ./scripts/build.sh --nohup  # test image that also installs the developer SSH key
#                                              # (never release such an image; see board/.../a733/dev/README.md)
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
# Fix: write a thin make shim to $HOME/bin/make (persistent across exit) that
# strips the 'r' flag from MAKEFLAGS before forwarding to the real make.  All
# shims live in $HOME/bin — no temp dir is needed, so there is no race between
# the foreground script's EXIT trap and the background --nohup make process.
# -----------------------------------------------------------------------------
# Find the real system make, skipping $HOME/bin to avoid picking up a stale
# shim written by a previous build run.
REAL_MAKE="$(PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin command -v make || true)"
if [ -z "${REAL_MAKE}" ]; then
    echo "[ERROR] 'make' not found in PATH. Install build tools first:"
    echo "        sudo pacman -Sy --noconfirm --needed base-devel"
    exit 1
fi
mkdir -p "$HOME/bin"
cat > "$HOME/bin/make" << SHIM_EOF
#!/bin/bash
# Strip --no-builtin-rules / -r from inherited MAKEFLAGS.
# GNU Make stores the flag as 'r'; strip it from the leading flags cluster.
_mf="\${MAKEFLAGS}"
_mf="\$(echo "\$_mf" | sed 's/^\\(-*\\)\\([A-QS-Za-qs-z]*\\)r\\([A-Za-z]*\\)/\\1\\2\\3/')"
export MAKEFLAGS="\$_mf"
exec ${REAL_MAKE} "\$@"
SHIM_EOF
chmod +x "$HOME/bin/make"

# When running inside Flatpak, /run/host/usr/bin/x86_64-pc-linux-gnu-gcc is the
# SteamOS host GCC 14.2.1. Its cc1 depends on libisl.so.23 which is absent from
# the Flatpak runtime, causing autoconf C89/C99 conformance probes to fail with
# "error while loading shared libraries: libisl.so.23". Mask the broken triplet-
# prefixed compilers with symlinks to the working Flatpak GCC in $HOME/bin.
if [ -n "${FLATPAK_ID}" ]; then
    ln -sf /usr/bin/gcc  "$HOME/bin/x86_64-pc-linux-gnu-gcc"
    ln -sf /usr/bin/g++  "$HOME/bin/x86_64-pc-linux-gnu-g++"
    ln -sf /usr/bin/gcc  "$HOME/bin/x86_64-unknown-linux-gnu-gcc"
    ln -sf /usr/bin/g++  "$HOME/bin/x86_64-unknown-linux-gnu-g++"

    # /run/host/usr/bin/rsync segfaults in the Flatpak due to glibc/ABI mismatch.
    # Use flatpak-spawn --host to run rsync on the host side.
    if [ -x "/usr/bin/flatpak-spawn" ] && [ -f "/run/host/usr/bin/rsync" ]; then
        cat > "$HOME/bin/rsync" << 'RSYNC_EOF'
#!/bin/bash
exec /usr/bin/flatpak-spawn --host rsync "$@"
RSYNC_EOF
        chmod +x "$HOME/bin/rsync"
    fi
fi

export PATH="$HOME/bin:${PATH}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# -----------------------------------------------------------------------------
# When running inside a Flatpak (e.g. VS Code on SteamOS), the Flatpak has a
# working host-native GCC but is missing tools installed on the host via
# pacman (rsync, mtools, bc, etc.). The host filesystem is bind-mounted at
# /run/host — prepend its bin dirs so those tools are visible to the build.
# -----------------------------------------------------------------------------
if [ -d "/run/host/usr/bin" ]; then
    # Append host paths so Flatpak-provided tools (/usr/bin/gcc, etc.) take
    # precedence. Flatpak GCC 15.x has working headers; host GCC on SteamOS
    # does not. rsync/bc/mtools from the host are still found via this suffix.
    export PATH="${PATH}:/run/host/usr/bin:/run/host/usr/local/bin"
fi

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

# When running inside Flatpak (e.g. VS Code on SteamOS), the GCC at
# /usr/bin/gcc is the Flatpak runtime GCC (15.x) which has working C headers.
# The SteamOS host GCC has no headers. Buildroot's Makefile uses HOSTCC :=
# (not ?=), so it cannot be overridden by environment — it must be passed as
# a make command-line variable, which GNU Make propagates to all sub-makes
# via MAKEFLAGS.
MAKE_EXTRA_ARGS=()
if [ -n "${FLATPAK_ID}" ]; then
    MAKE_EXTRA_ARGS+=(HOSTCC=/usr/bin/gcc HOSTCXX=/usr/bin/g++)
fi

# The batocera-emulationstation recipe in the Batocera fork hardcodes
# OVERRIDE_SRCDIR to a path on the original Steam Deck (/home/deck/...).  A plain
# assignment in the recipe beats local.mk, but a make command-line variable beats
# both, so point it at a checkout under this tree.  Expected contents:
# GameOctane/batocera-emulationstation @ feat/multi-user-profiles, cloned with
# --recurse-submodules into batocera/dl/batocera-emulationstation/git.
ES_SRCDIR="${REPO_ROOT}/batocera/dl/batocera-emulationstation/git"
if [ -d "${ES_SRCDIR}" ]; then
    MAKE_EXTRA_ARGS+=(BATOCERA_EMULATIONSTATION_OVERRIDE_SRCDIR="${ES_SRCDIR}")
fi

# -----------------------------------------------------------------------------
# Keep the kernel source tree, and Buildroot's compiled copy of it, in step with their inputs.
#
# LINUX_OVERRIDE_SRCDIR makes Buildroot copy linux/kernel-66 into build/linux-custom ONCE and
# never again, and setup-kernel-66.sh applies the patches and installs the board device tree
# ONCE.  So an edit to a patch, the kernel config or the board DTS silently did nothing: the
# 120 Hz fix missed three releases that way, and a stale copy compiled unpatched code.
#
# Hash every input.  If it differs from the hash recorded at the last build, redo the setup
# from clean checkouts and delete the compiled copy so Buildroot copies and rebuilds it.
# -----------------------------------------------------------------------------
sync_kernel_inputs() {
    local ksrc="${REPO_ROOT}/linux/kernel-66"
    local out="${BATOCERA_DIR}/output/a733-cubie-a7s"
    local stamp="${out}/.octane-kernel-inputs"
    local a733="${REPO_ROOT}/board/batocera/allwinner/a733"

    # Not set up yet (first build): setup-kernel-66.sh has to run first, by hand.
    [ -d "${ksrc}/.git" ] || return 0

    local now last=""
    now="$(
        {
            cat "${a733}/dts/sun60i-a733-cubie-a7s.dts" \
                "${a733}/linux-defconfig.config" \
                "${a733}/linux-defconfig-fragment.config" \
                "${REPO_ROOT}/scripts/setup-kernel-66.sh"
            # names as well as contents, so a rename or a move into obsolete/ counts
            find "${a733}/linux_patches_66" "${a733}/patches/linux" -maxdepth 1 -name '*.patch' | sort
            find "${a733}/linux_patches_66" "${a733}/patches/linux" -maxdepth 1 -name '*.patch' | sort | xargs cat
        } | sha256sum | cut -d' ' -f1
    )"
    [ -f "${stamp}" ] && last="$(cat "${stamp}")"

    if [ "${now}" = "${last}" ]; then
        echo "[INFO] Kernel inputs unchanged since the last build."
        return 0
    fi

    echo "[INFO] Kernel inputs changed since the last build; redoing the kernel setup from clean."
    "${REPO_ROOT}/scripts/setup-kernel-66.sh" --reset || {
        echo "[ERROR] Kernel setup failed (a patch probably no longer applies). Fix it and rerun." >&2
        return 1
    }
    rm -rf "${out}/build/linux-custom"
    mkdir -p "${out}"
    echo "${now}" > "${stamp}"
    echo "[INFO] Kernel tree rebuilt; Buildroot will copy and rebuild the kernel."
}

# --sync-kernel-only: do just that and stop (also handy to test the guard without a build)
if [[ "${1:-}" == "--sync-kernel-only" ]]; then
    sync_kernel_inputs
    exit $?
fi
sync_kernel_inputs || exit 1

echo "[INFO] Starting build..."

# --nohup: detach from the terminal so VS Code / Claude crashes don't kill the build.
# Output goes to build.log in the repo root; tail -f build.log to follow it.
if [[ "${1:-}" == "--nohup" ]]; then
    shift
    LOG="${REPO_ROOT}/build.log"
    echo "[INFO] Running detached via nohup — follow with: tail -f ${LOG}"
    nohup make a733-cubie-a7s-build DIRECT_BUILD=1 "${MAKE_EXTRA_ARGS[@]}" "$@" \
        > "${LOG}" 2>&1 &
    echo "[INFO] Build PID: $!"
    exit 0
fi

make a733-cubie-a7s-build DIRECT_BUILD=1 "${MAKE_EXTRA_ARGS[@]}" "$@"
