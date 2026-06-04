#!/bin/bash
# =============================================================================
# OctaneOS — Radxa 6.6 kernel + allwinner-bsp integration script
#
# This script clones the Radxa 6.6 kernel and the allwinner-bsp overlay,
# merges them into a single source tree, then applies OctaneOS patches.
# The resulting tree is used via LINUX_OVERRIDE_SRCDIR in local.mk.
#
# Run this ONCE before ./scripts/build.sh.  Re-run to update (it is idempotent).
#
# Usage:
#   ./scripts/setup-kernel-66.sh [--update]
#
#   --update   Force a git pull on existing clones (slow, rarely needed)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${REPO_ROOT}/linux/kernel-66"
STAMP="${KERNEL_DIR}/.octaneos_setup_done"

KERNEL_REPO="https://github.com/radxa/kernel"
KERNEL_BRANCH="allwinner-aiot-linux-6.6"

BSP_REPO="https://github.com/radxa/allwinner-bsp"
BSP_BRANCH="cubie-aiot-v1.4.8"

PATCHES_DIR="${REPO_ROOT}/board/batocera/allwinner/a733/linux_patches_66"

UPDATE=0
if [[ "${1:-}" == "--update" ]]; then
    UPDATE=1
fi

# -----------------------------------------------------------------------------
# 1. Clone or update the Radxa 6.6 kernel
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 1: kernel source"
if [ ! -d "${KERNEL_DIR}/.git" ]; then
    echo "  Cloning ${KERNEL_REPO} (${KERNEL_BRANCH}) ..."
    mkdir -p "$(dirname "${KERNEL_DIR}")"
    git clone --depth=1 -b "${KERNEL_BRANCH}" "${KERNEL_REPO}" "${KERNEL_DIR}"
else
    echo "  Kernel already cloned."
    if [ "${UPDATE}" -eq 1 ]; then
        echo "  Pulling updates..."
        git -C "${KERNEL_DIR}" fetch --depth=1 origin "${KERNEL_BRANCH}"
        git -C "${KERNEL_DIR}" reset --hard "origin/${KERNEL_BRANCH}"
        rm -f "${STAMP}"
    fi
fi

# -----------------------------------------------------------------------------
# 2. Clone or update allwinner-bsp into bsp/
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 2: allwinner-bsp overlay"
if [ ! -d "${KERNEL_DIR}/bsp/.git" ]; then
    echo "  Cloning ${BSP_REPO} (${BSP_BRANCH}) into bsp/ ..."
    git clone --depth=1 -b "${BSP_BRANCH}" "${BSP_REPO}" "${KERNEL_DIR}/bsp"
else
    echo "  BSP already cloned."
    if [ "${UPDATE}" -eq 1 ]; then
        echo "  Pulling updates..."
        git -C "${KERNEL_DIR}/bsp" fetch --depth=1 origin "${BSP_BRANCH}"
        git -C "${KERNEL_DIR}/bsp" reset --hard "origin/${BSP_BRANCH}"
        rm -f "${STAMP}"
    fi
fi

# Skip remaining steps if already done and not forced
if [ -f "${STAMP}" ]; then
    echo "[kernel-66] Already set up (stamp exists). Use --update to refresh."
    exit 0
fi

# -----------------------------------------------------------------------------
# 3. Fix BSP Kconfig $(BSP_TOP) references for Buildroot compatibility
#
# The BSP's bsp/Kconfig sources sub-Kconfigs using "$(BSP_TOP)platform/Kconfig"
# etc.  BSP_TOP is a Makefile variable passed as BSP_TOP=bsp/ when building
# directly.  Buildroot's kernel configure step does NOT pass BSP_TOP, so
# $(BSP_TOP) expands to empty and Kconfig fails with "can't open file".
# Replace $(BSP_TOP) with the literal "bsp/" path, which is always correct
# since the BSP is always cloned into bsp/ inside the kernel tree.
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 3: fix BSP Kconfig for Buildroot (BSP_TOP → bsp/)"
# The BSP has ~39 Kconfig files that use $(BSP_TOP) for sourcing sub-configs.
# Fix all of them in one pass.
COUNT=$(find "${KERNEL_DIR}/bsp" -name 'Kconfig*' -exec grep -l '\$(BSP_TOP)' {} \; | wc -l)
find "${KERNEL_DIR}/bsp" -name 'Kconfig*' -exec grep -l '\$(BSP_TOP)' {} \; \
    | xargs sed -i 's|\$(BSP_TOP)|bsp/|g'
echo "  Fixed ${COUNT} Kconfig files (BSP_TOP → bsp/)"

# -----------------------------------------------------------------------------
# 4. Copy A733 SoC DTSI files from BSP into the kernel DTS tree
#
# The Radxa 6.6 kernel has no A733 DTS in-tree.  The SoC-level DTSI files
# live in bsp/configs/linux-6.6/ and must be available in arch/arm64/boot/
# dts/allwinner/ before the board DTS can be compiled.
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 4: copy A733 DTSI files"
ALLWINNER_DTS="${KERNEL_DIR}/arch/arm64/boot/dts/allwinner"
BSP_DTS_SRC="${KERNEL_DIR}/bsp/configs/linux-6.6"

for f in sun60iw2p1.dtsi sun60iw2p1-cpu-vf.dtsi; do
    if [ -f "${BSP_DTS_SRC}/${f}" ]; then
        cp "${BSP_DTS_SRC}/${f}" "${ALLWINNER_DTS}/${f}"
        echo "  Copied ${f}"
    else
        echo "  WARNING: ${BSP_DTS_SRC}/${f} not found — BSP may have changed."
    fi
done

# -----------------------------------------------------------------------------
# 4. Copy dt-bindings headers from BSP into the kernel include tree
#
# The board DTS and BSP drivers reference Allwinner-specific dt-bindings
# (clocks, resets, power domains, etc.) that live in bsp/include/dt-bindings/.
# Copy them into include/dt-bindings/, skipping any file already present
# (mainline headers take precedence).
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 5: install dt-bindings headers"
BSP_INCLUDE="${KERNEL_DIR}/bsp/include"
if [ -d "${BSP_INCLUDE}/dt-bindings" ]; then
    # cp -rn skips existing files (--no-clobber)
    cp -rn "${BSP_INCLUDE}/dt-bindings/." \
           "${KERNEL_DIR}/include/dt-bindings/" 2>/dev/null || true
    echo "  dt-bindings merged."
else
    echo "  WARNING: bsp/include/dt-bindings not found."
fi

# -----------------------------------------------------------------------------
# 5. Install board DTS + update allwinner DTS Makefile
#
# The Radxa 6.6 kernel has no A733 DTS in-tree.  Copy our board DTS directly
# from the OctaneOS repo and append the DTB target to the allwinner Makefile.
# This avoids a 2000-line patch file and keeps the DTS source of truth in one
# place (board/batocera/allwinner/a733/dts/).
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 6: install A7S board DTS"
BOARD_DTS_SRC="${REPO_ROOT}/board/batocera/allwinner/a733/dts/sun60i-a733-cubie-a7s.dts"
BOARD_DTS_DST="${ALLWINNER_DTS}/sun60i-a733-cubie-a7s.dts"

if [ -f "${BOARD_DTS_SRC}" ]; then
    cp "${BOARD_DTS_SRC}" "${BOARD_DTS_DST}"
    echo "  Copied sun60i-a733-cubie-a7s.dts"
else
    echo "  ERROR: board DTS not found at ${BOARD_DTS_SRC}"
    exit 1
fi

# Add DTB target to the allwinner DTS Makefile if not already present
ALLWINNER_MK="${ALLWINNER_DTS}/Makefile"
DTB_ENTRY="dtb-\$(CONFIG_ARCH_SUNXI) += sun60i-a733-cubie-a7s.dtb"
if ! grep -q "sun60i-a733-cubie-a7s.dtb" "${ALLWINNER_MK}"; then
    echo "${DTB_ENTRY}" >> "${ALLWINNER_MK}"
    echo "  Added DTB entry to allwinner Makefile"
fi

# -----------------------------------------------------------------------------
# 6. Apply small OctaneOS patches
#
# Patches in linux_patches_66/ are applied in order.  Each patch is
# idempotent: --forward means already-applied patches are skipped silently.
# Currently: cpufreq sun50i A733 match (adds one line to match list).
# The BSP may already include this — if so, the patch fails harmlessly.
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 7: apply OctaneOS patches"
if [ -d "${PATCHES_DIR}" ]; then
    for patch in $(find "${PATCHES_DIR}" -name '*.patch' | sort); do
        pname="$(basename "${patch}")"
        echo "  Applying ${pname} ..."
        patch -d "${KERNEL_DIR}" -p1 --forward --reject-file=/tmp/octaneos-reject.rej \
            < "${patch}" \
            || { echo "  WARN: ${pname} may already be applied or context mismatch — check manually."; \
                 rm -f /tmp/octaneos-reject.rej; }
    done
else
    echo "  No patches dir at ${PATCHES_DIR} — skipping."
fi

# -----------------------------------------------------------------------------
# 7. Write a bsp_defconfig into arch/arm64/configs/ so Buildroot (or make
#    directly) can use:  make ARCH=arm64 BSP_TOP=bsp/ bsp_defconfig
#
# The file is a minimal stub that points Kconfig at the A733 platform.
# OctaneOS's main config logic comes from linux-defconfig.config (the full
# Radxa generic defconfig) plus linux-defconfig-fragment.config (AW_* overrides).
# This stub is only needed if building without Buildroot's custom config path.
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 8: write arch/arm64/configs/bsp_defconfig"
BSPDEF="${KERNEL_DIR}/arch/arm64/configs/bsp_defconfig"
if [ ! -f "${BSPDEF}" ]; then
    # Minimal platform selection — Buildroot uses USE_CUSTOM_CONFIG anyway
    cat > "${BSPDEF}" << 'EOF'
# OctaneOS A733 platform seed — used only for direct make invocations.
# Buildroot uses BR2_LINUX_KERNEL_USE_CUSTOM_CONFIG instead.
CONFIG_AW_BSP=y
CONFIG_AW_KERNEL_ORIGIN=y
CONFIG_ARCH_SUN60I=y
CONFIG_ARCH_SUN60IW2=y
CONFIG_ARCH_SUN60IW2P1=y
CONFIG_AW_IC_BOARD=y
CONFIG_AW_SOC_NAME="A733"
EOF
    echo "  Written."
fi

# -----------------------------------------------------------------------------
touch "${STAMP}"
echo "[kernel-66] Done. Kernel tree ready at: ${KERNEL_DIR}"
echo "  Build with Buildroot via: ./scripts/build.sh"
echo "  Or directly: make -C ${KERNEL_DIR} ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- BSP_TOP=bsp/ bsp_defconfig"
