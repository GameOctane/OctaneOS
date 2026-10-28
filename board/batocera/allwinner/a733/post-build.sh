#!/bin/bash
# =============================================================================
# OctaneOS A733 post-build script
# Called by Buildroot after the rootfs is assembled, before squashfs packing.
# $1 = TARGET_DIR   $2 = HOST_DIR   $3 = BINARIES_DIR
# =============================================================================
set -euo pipefail

TARGET_DIR="$1"
# HOST_DIR is passed as an environment variable by Buildroot, not as $2
HOST_DIR="${HOST_DIR:-}"

# Fall back to locating the toolchain next to the kernel-66 tree
if [ -z "${HOST_DIR}" ]; then
    HOST_DIR="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../../../batocera/output/a733-cubie-a7s/host")"
fi

CROSS="${HOST_DIR}/bin/aarch64-buildroot-linux-gnu-"

# Buildroot builds the kernel in BUILD_DIR/linux-custom/ (rsynced from source).
# auto.conf, Module.symvers, etc. live there — the module must build against it.
BUILD_DIR="${BUILD_DIR:-$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../../../batocera/output/a733-cubie-a7s/build")}"
KERNEL_BUILD="${BUILD_DIR}/linux-custom"

# GPU module source lives in the original BSP tree (not the build copy)
KERNEL_SRC="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../../../linux/kernel-66")"
# OctaneOS scripts folder (install-dev-key.sh and friends), found the same way
REPO_ROOT_FOR_SCRIPTS="$(realpath "$(dirname "${BASH_SOURCE[0]}")/../../../../scripts")"
GPU_MODULE_DIR="${KERNEL_SRC}/bsp/modules/gpu"

# =============================================================================
# Build pvrsrvkm.ko (Imagination PowerVR BXM-4-64 kernel module)
#
# The module source lives in bsp/modules/gpu/ which was prepared by
# setup-kernel-66.sh.  We build it out-of-tree using the already-built
# kernel and the Buildroot cross-compiler.
# =============================================================================
if [ ! -d "${GPU_MODULE_DIR}" ]; then
    echo "[post-build] WARNING: GPU module source not found at ${GPU_MODULE_DIR}"
    echo "[post-build] Run scripts/setup-kernel-66.sh first."
    exit 0
fi

echo "[post-build] Building pvrsrvkm.ko (PowerVR BXM-4-64)..."
echo "[post-build]   Kernel build : ${KERNEL_BUILD}"
echo "[post-build]   GPU source   : ${GPU_MODULE_DIR}"

# The GPU Makefile uses a custom build system, not Kbuild obj-m.
# Call its 'build' target directly with GPU_TYPE=bxm.
# The build target internally does:
#   $(MAKE) -C img-bxm/linux/rogue_km/build/linux/sunxi_linux BUILD=release
# That in turn calls make -Rr -C KERNELDIR M=kbuild, which uses -Rr flags
# that suppress command-line variable propagation. Export CROSS_COMPILE and
# KERNELDIR as env vars so they survive the -Rr make invocation.
# sunxi_linux/Makefile sets KERNEL_CC=$(LICHEE_TOOLCHAIN_PATH)/bin/$(LICHEE_CROSS_COMPILER)-gcc.
# With both Lichee vars empty (outside Allwinner SDK) this becomes /bin/-gcc.
# Set them so the toolchain prefix resolves correctly.
export CROSS_COMPILE="${CROSS}"
export KERNELDIR="${KERNEL_BUILD}"
export ARCH=arm64
export LICHEE_TOOLCHAIN_PATH="${HOST_DIR}"
export LICHEE_CROSS_COMPILER="aarch64-buildroot-linux-gnu"
make -C "${GPU_MODULE_DIR}" build \
    KERNEL_SRC_DIR="${KERNEL_BUILD}" \
    KERNEL_OUT_DIR="${KERNEL_BUILD}" \
    KERNELDIR="${KERNEL_BUILD}" \
    KDIR="${KERNEL_BUILD}" \
    ARCH=arm64 \
    CROSS_COMPILE="${CROSS}" \
    LICHEE_TOOLCHAIN_PATH="${HOST_DIR}" \
    LICHEE_CROSS_COMPILER="aarch64-buildroot-linux-gnu" \
    CPU_ARCH=arm64 \
    GPU_TYPE=bxm \
    CONFIG_OS_TYPE=linux \
    GPU_BUILD_TYPE=release \
    -j$(nproc)

# Find built .ko files and install them
KVER=$(cat "${KERNEL_BUILD}/include/config/kernel.release" 2>/dev/null || \
       awk -F\" '/UTS_RELEASE/{print $2}' "${KERNEL_BUILD}/include/generated/utsrelease.h" 2>/dev/null || \
       echo "unknown")

KO_DEST="${TARGET_DIR}/lib/modules/${KVER}/extra"
mkdir -p "${KO_DEST}"

# Output lands in binary_sunxi_linux_nulldrmws_release/target_aarch64/kbuild/
KO_SRC=$(find "${GPU_MODULE_DIR}/img-bxm" -name "pvrsrvkm.ko" 2>/dev/null | head -1)
if [ -z "${KO_SRC}" ]; then
    echo "[post-build] ERROR: pvrsrvkm.ko not found after build"
    exit 1
fi
"${CROSS}strip" --strip-debug "${KO_SRC}" -o "${KO_DEST}/pvrsrvkm.ko"
echo "[post-build] Installed: ${KO_DEST}/pvrsrvkm.ko  (from ${KO_SRC})"

echo "[post-build] pvrsrvkm.ko done."

# =============================================================================
# Stamp OctaneOS build version into batocera.version and octaneos.version.
# Bump OCTANE_BUILD_NUMBER and OCTANE_RELEASE_TAG on each release.
# batocera.version: compared against ota/cubie-a7s/stable/last/batocera.version
# octaneos.version: compared against GitHub latest release tag by ES swissknife
# =============================================================================
OCTANE_BUILD_NUMBER=71
OCTANE_RELEASE_TAG="v0.7.0"
OCTANE_VERSION_STRING="0.7.0"
# Write version files WITHOUT the leading 'v' — ES prepends " V" in the menu
# label, so keeping "v0.6.9" would display as "OctaneOS V v0.6.9".
echo "${OCTANE_VERSION_STRING}" \
    > "${TARGET_DIR}/usr/share/batocera/batocera.version"
echo "${OCTANE_VERSION_STRING}" \
    > "${TARGET_DIR}/usr/share/batocera/octaneos.version"
echo "[post-build] batocera.version: ${OCTANE_VERSION_STRING}"
echo "[post-build] octaneos.version: ${OCTANE_VERSION_STRING}"

# =============================================================================
# Developer SSH key: NOT part of a normal image.
# With OCTANE_DEV_KEY_FILE=/absolute/path/to/key.pub in the environment of the build, that
# public key is added so S13octane-init installs it on boot.  That gives the key's holder root
# SSH on every device running the image, so such an image must never be released
# (check-image.sh --release fails if the key is present).  No key is stored in the repo.
# =============================================================================
if [ -n "${OCTANE_DEV_KEY_FILE:-}" ]; then
    "${REPO_ROOT_FOR_SCRIPTS}/install-dev-key.sh" "${OCTANE_DEV_KEY_FILE}" "${TARGET_DIR}" || exit 1
    echo "[post-build] WARNING: developer SSH key INCLUDED (OCTANE_DEV_KEY_FILE). Do not release this image."
else
    rm -f "${TARGET_DIR}/usr/share/octane/dev-ssh-key.pub"
    echo "[post-build] Developer SSH key not included."
fi

# =============================================================================
# Update signature keys (docs/update-signing.md).  The updater installs an update only if its
# manifest is signed by one of the public keys in /usr/share/octane/update-keys: the primary key
# and the backup key, kept in keys/update/*.pub.pem in the repo.  The folder is rebuilt from the
# repo on every build, so a key that was removed does not linger in target/.
# A DEVELOPER image (built with OCTANE_DEV_KEY_FILE) also gets /usr/share/octane/allow-unsigned,
# which lets that test image install an update that has no signature at all (a wrong signature
# is still refused).  The marker is deleted on every other build, and check-image.sh --release
# fails if it is present.
# =============================================================================
UPDATE_KEYS_SRC="${REPO_ROOT_FOR_SCRIPTS}/../keys/update"
rm -rf "${TARGET_DIR}/usr/share/octane/update-keys"
mkdir -p "${TARGET_DIR}/usr/share/octane/update-keys"
update_keys=0
for k in "${UPDATE_KEYS_SRC}"/*.pub.pem; do
    [ -f "${k}" ] || continue
    install -m 0644 "${k}" "${TARGET_DIR}/usr/share/octane/update-keys/$(basename "${k%.pub.pem}").pem"
    update_keys=$((update_keys + 1))
done
echo "[post-build] update signature keys installed: ${update_keys}"
if [ "${update_keys}" -lt 2 ]; then
    echo "[post-build] WARNING: fewer than two update keys in keys/update, so this image cannot install signed updates (see docs/update-signing.md)"
fi
if [ -n "${OCTANE_DEV_KEY_FILE:-}" ]; then
    : > "${TARGET_DIR}/usr/share/octane/allow-unsigned"
    echo "[post-build] WARNING: developer image: it may install unsigned updates. Do not release it."
else
    rm -f "${TARGET_DIR}/usr/share/octane/allow-unsigned"
fi

# =============================================================================
# OctaneOS defaults — injected into datainit batocera.conf
# Layers on top of the upstream file without maintaining a full copy.
# =============================================================================
DATAINIT_CONF="${TARGET_DIR}/usr/share/batocera/datainit/system/batocera.conf"
if [ -f "${DATAINIT_CONF}" ] && ! grep -q "^system.services=" "${DATAINIT_CONF}"; then
    printf '\n## OctaneOS defaults\nsystem.services=syncthing\n' >> "${DATAINIT_CONF}"
    echo "[post-build] Enabled syncthing in datainit batocera.conf"
fi

# Where the device looks for new versions.  EmulationStation's update check
# (batocera-config canupdate) reads <updates.url>/<board>/<channel>/last/batocera.version, and
# without this setting both it and EmulationStation fall back to Batocera's own server
# (updates.batocera.org), which knows nothing about this board.  S13octane-init adds the same
# line on a card that does not have it yet, so existing devices are covered too.
if [ -f "${DATAINIT_CONF}" ] && ! grep -q "^updates.url=" "${DATAINIT_CONF}"; then
    printf 'updates.url=https://raw.githubusercontent.com/GameOctane/OctaneOS/main/ota\n' >> "${DATAINIT_CONF}"
    echo "[post-build] Set updates.url in datainit batocera.conf"
fi

# Nintendo DS on a 120 Hz screen: with RetroArch's vsync ON, a frame that is slightly late waits for the next slot, so the
# game hovers at about 50 of 60 fps and the audio has gaps about 14% of the time (the "warble").  With vsync OFF it runs at
# 58-60 fps with 0.1-0.5% gaps, and the bezel then costs nothing (docs/a733-gotchas.md, item 20).  batocera.conf lines of the
# form <system>.retroarch.<key> are copied straight into retroarch.cfg.  New cards get this here; an existing card keeps what
# it has (this only seeds the default file that a new card is made from).
# An earlier build of this script also forced nds.bezel=none; that is removed again, because the target folder keeps old files.
if [ -f "${DATAINIT_CONF}" ]; then
    sed -i -e '/^# OctaneOS: the DS bezel costs about 3 fps/d' -e '/^nds\.bezel=none$/d' "${DATAINIT_CONF}"
    if ! grep -q "^nds\.retroarch\.video_vsync=" "${DATAINIT_CONF}"; then
        printf '# OctaneOS: DS audio and frame pacing on a 120 Hz screen (docs/a733-gotchas.md, item 20).\nnds.retroarch.video_vsync=false\n' >> "${DATAINIT_CONF}"
        echo "[post-build] Set nds.retroarch.video_vsync=false in datainit batocera.conf"
    fi
fi

# Network defaults (phase 1 of docs/security-design-phase1.md): hide the system folder and the
# credential files from guests of the file share, no NFS server unless something is exported,
# Syncthing's page local-only by default, Wi-Fi on by default.  Fails the build if the upstream
# text it patches has changed.
"${REPO_ROOT_FOR_SCRIPTS}/harden-network-defaults.py" "${TARGET_DIR}" || exit 1

# The flight recorder (usr/bin/octane-flightlog, see docs/) is OFF by default: it reads the power
# chip's registers every 30 s, which is fine for a tester but not something to run on every device.
# Enable it for an investigation with octane.flightlog=1 in /userdata/system/batocera.conf.
# Its logs are capped (20 MB per file, one rotated copy each).  Nothing is sent anywhere.
