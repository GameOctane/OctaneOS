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
#   ./scripts/setup-kernel-66.sh [--update | --reset]
#
#   --check-upstream  Only report whether the pinned Radxa commits (board/.../kernel-sources.pin) are behind
#                     the branch tips; changes nothing.  (The old --update, which silently moved to the tip, is gone.)
#   --reset    Throw away every change in the existing clones and re-apply the patches, the
#              board device tree and the BSP fixes from scratch (no network, about a minute).
#              scripts/build.sh does this by itself when the kernel inputs have changed.
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
KERNEL_DIR="${REPO_ROOT}/linux/kernel-66"
STAMP="${KERNEL_DIR}/.octaneos_setup_done"

# The upstream sources are pinned to exact commits in kernel-sources.pin, so a build never silently picks up
# newer Radxa code.  See that file for how to move the pin.
PIN_FILE="${REPO_ROOT}/board/batocera/allwinner/a733/kernel-sources.pin"
# shellcheck source=lib-pin.sh
. "${REPO_ROOT}/scripts/lib-pin.sh"
KERNEL_REPO="$(read_pin "${PIN_FILE}" KERNEL_REPO)";   KERNEL_BRANCH="$(read_pin "${PIN_FILE}" KERNEL_BRANCH)"
KERNEL_COMMIT="$(read_pin "${PIN_FILE}" KERNEL_COMMIT)"
BSP_REPO="$(read_pin "${PIN_FILE}" BSP_REPO)";         BSP_BRANCH="$(read_pin "${PIN_FILE}" BSP_BRANCH)"
BSP_COMMIT="$(read_pin "${PIN_FILE}" BSP_COMMIT)"
for v in KERNEL_REPO KERNEL_BRANCH KERNEL_COMMIT BSP_REPO BSP_BRANCH BSP_COMMIT; do
    [ -n "${!v}" ] || { echo "ERROR: ${v} is missing in ${PIN_FILE}" >&2; exit 1; }
done

PATCHES_DIR="${REPO_ROOT}/board/batocera/allwinner/a733/linux_patches_66"

RESET=0
PIN_CHANGED=0
case "${1:-}" in
    --reset) RESET=1 ;;
    --check-upstream)
        check_one() {   # NAME URL BRANCH PINNED_COMMIT
            local tip
            tip="$(git ls-remote "$2" "refs/heads/$3" | cut -f1)"
            if [ -z "${tip}" ]; then
                echo "$1: could not reach $2 (branch $3)"
            elif [ "${tip}" = "$4" ]; then
                echo "$1: the pinned commit ${4:0:12} is still the tip of $3"
            else
                echo "$1: pinned ${4:0:12}, but the tip of $3 is now ${tip:0:12}  ($2)"
            fi
        }
        check_one kernel "${KERNEL_REPO}" "${KERNEL_BRANCH}" "${KERNEL_COMMIT}"
        check_one bsp    "${BSP_REPO}"    "${BSP_BRANCH}"    "${BSP_COMMIT}"
        exit 0 ;;
    --update)
        echo "ERROR: --update is gone: the kernel and BSP are pinned (${PIN_FILE})." >&2
        echo "       --check-upstream shows newer commits; to move the pin, edit the file and run --reset." >&2
        exit 2 ;;
    "") ;;
    *) echo "unknown option: $1" >&2; exit 2 ;;
esac

# -----------------------------------------------------------------------------
# 1. Clone or update the Radxa 6.6 kernel
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 1: kernel source (pinned ${KERNEL_COMMIT:0:12})"
pin_checkout "${KERNEL_DIR}" "${KERNEL_REPO}" "${KERNEL_BRANCH}" "${KERNEL_COMMIT}"

# -----------------------------------------------------------------------------
# 2. allwinner-bsp into bsp/
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 2: allwinner-bsp overlay (pinned ${BSP_COMMIT:0:12})"
pin_checkout "${KERNEL_DIR}/bsp" "${BSP_REPO}" "${BSP_BRANCH}" "${BSP_COMMIT}"

# The pin moved an existing checkout: the old patched tree is stale, redo everything from clean.
if [ "${PIN_CHANGED}" -eq 1 ]; then
    echo "[kernel-66] A pinned commit changed; redoing the setup from clean"
    RESET=1
fi

# --reset: back to the clean checkouts, then fall through and redo every step below.
if [ "${RESET}" -eq 1 ]; then
    echo "[kernel-66] Resetting the kernel and BSP trees to their clean checkouts"
    git -C "${KERNEL_DIR}" reset -q --hard HEAD
    git -C "${KERNEL_DIR}" clean -qfd -e bsp
    git -C "${KERNEL_DIR}/bsp" reset -q --hard HEAD
    git -C "${KERNEL_DIR}/bsp" clean -qfd
    rm -f "${STAMP}"
fi

# Skip remaining steps if already done and not forced
if [ -f "${STAMP}" ]; then
    echo "[kernel-66] Already set up (stamp exists). Use --reset to redo it."
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
echo "[kernel-66] Step 3: generate sunxi-autogen.h"
# The BSP CCU driver (#include <sunxi-autogen.h>) needs AW_BSP_VERSION defined.
# The Allwinner/Radxa SDK generates this from git log at build time; since we build
# outside the SDK, we generate a stub using the BSP git short hash.
BSP_HASH=$(git -C "${KERNEL_DIR}/bsp" rev-parse --short HEAD 2>/dev/null || echo "unknown")
cat > "${KERNEL_DIR}/bsp/include/sunxi-autogen.h" << AUTOGEN_EOF
/* SPDX-License-Identifier: GPL-2.0 */
/* Generated by OctaneOS setup-kernel-66.sh — AW_BSP_VERSION from BSP git hash */
#ifndef __SUNXI_AUTOGEN_H__
#define __SUNXI_AUTOGEN_H__
#define AW_BSP_VERSION "${BSP_BRANCH}-${BSP_HASH}"
#endif /* __SUNXI_AUTOGEN_H__ */
AUTOGEN_EOF
echo "  Generated sunxi-autogen.h (version: ${BSP_BRANCH}-${BSP_HASH})"

echo "[kernel-66] Step 4: fix BSP Kconfig for Buildroot (BSP_TOP → bsp/)"
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
echo "[kernel-66] Step 5: patch BSP Makefile + create bridge symlinks"
# Remove NAND and GPU modules from in-tree BSP build.
# Both bsp/modules/nand/ and bsp/modules/gpu/ use out-of-tree build
# conventions (they check for KERNEL_SRC_DIR) and cannot be built as
# part of the in-tree kernel make.  NAND is not used on A7S (MMC-only).
# pvrsrvkm.ko (GPU) is built separately via package/pvrsrvkm after the
# kernel is done and KERNEL_SRC_DIR can be set to the built kernel tree.
sed -i '/obj-y += modules\/nand\//d' "${KERNEL_DIR}/bsp/Makefile"
sed -i '/obj-y += modules\/gpu\//d'  "${KERNEL_DIR}/bsp/Makefile"
echo "  Removed modules/nand/ and modules/gpu/ from bsp/Makefile"

# The rogue_km build system has a compiler allowlist in config/compilers/.
# The Buildroot cross-compiler is aarch64-buildroot-linux-gnu- which isn't
# listed.  Symlink it to the standard aarch64-linux-gnu.mk (identical settings).
ROGUE_COMPILERS="${KERNEL_DIR}/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/config/compilers"
ln -sf aarch64-linux-gnu.mk "${ROGUE_COMPILERS}/aarch64-buildroot-linux-gnu.mk"
echo "  Added aarch64-buildroot-linux-gnu.mk compiler config for rogue_km"

# rogue_km's kbuild/Makefile.template uses .SECONDARY to prevent deletion of
# intermediate build artifacts. Linux kernel 6.6 Kbuild uses .NOTINTERMEDIATE
# for the same purpose. GNU Make 4.4+ treats them as mutually exclusive.
# Replace .SECONDARY with .NOTINTERMEDIATE so the kbuild step succeeds.
ROGUE_TEMPLATE="${KERNEL_DIR}/bsp/modules/gpu/img-bxm/linux/rogue_km/build/linux/kbuild/Makefile.template"
sed -i 's/^\.SECONDARY:$/.NOTINTERMEDIATE:/' "${ROGUE_TEMPLATE}"
echo "  Replaced .SECONDARY with .NOTINTERMEDIATE in rogue_km Makefile.template"

# BSP USB host Makefile uses -I$(srctree)/drivers/usb/host so that
# #include <../sunxi_usb/include/...> resolves from drivers/usb/.
# Symlink the BSP sunxi_usb dir into mainline so the path resolves.
ln -sfn "${KERNEL_DIR}/bsp/drivers/usb/sunxi_usb" \
        "${KERNEL_DIR}/drivers/usb/sunxi_usb"
echo "  Linked drivers/usb/sunxi_usb → bsp/drivers/usb/sunxi_usb"

echo "[kernel-66] Step 6: copy A733 DTSI files"
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
echo "[kernel-66] Step 7: install dt-bindings headers"
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
echo "[kernel-66] Step 8: install A7S board DTS"
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
# 6. Apply OctaneOS kernel patches
#
# Two series, applied in this order (the order the original, non-override flow
# used, where Buildroot applied them itself):
#   1. linux_patches_66/   the 6.6 bring-up series (BR2_LINUX_KERNEL_PATCH)
#   2. patches/linux/      global patches for the "linux" package, added later
# Buildroot applies neither once LINUX_OVERRIDE_SRCDIR is set, so it is done here.
#
# Any patch that fails aborts the script: a failed patch must never silently drop
# a fix.  Patches that became redundant (e.g. already shipped in the BSP) live in an
# obsolete/ subdirectory, which is not applied.
# -----------------------------------------------------------------------------
GLOBAL_PATCHES_DIR="${REPO_ROOT}/board/batocera/allwinner/a733/patches/linux"

apply_patch_dir() {
    local dir="$1" patch pname
    if [ ! -d "${dir}" ]; then
        echo "  No patches dir at ${dir} — skipping."
        return 0
    fi
    for patch in $(find "${dir}" -maxdepth 1 -name '*.patch' | sort); do
        pname="$(basename "${patch}")"
        echo "  Applying ${pname} ..."
        if ! patch -d "${KERNEL_DIR}" -p1 --forward --no-backup-if-mismatch \
                --reject-file=/dev/null < "${patch}"; then
            echo "  ERROR: ${pname} failed to apply to ${KERNEL_DIR}." >&2
            echo "         Fix the patch, or move it to obsolete/ if the tree already has it." >&2
            exit 1
        fi
    done
}

echo "[kernel-66] Step 9: apply OctaneOS patches (linux_patches_66)"
apply_patch_dir "${PATCHES_DIR}"
echo "[kernel-66] Step 9b: apply OctaneOS global linux patches (patches/linux)"
apply_patch_dir "${GLOBAL_PATCHES_DIR}"

# -----------------------------------------------------------------------------
# 7. Write a bsp_defconfig into arch/arm64/configs/ so Buildroot (or make
#    directly) can use:  make ARCH=arm64 BSP_TOP=bsp/ bsp_defconfig
#
# The file is a minimal stub that points Kconfig at the A733 platform.
# OctaneOS's main config logic comes from linux-defconfig.config (the full
# Radxa generic defconfig) plus linux-defconfig-fragment.config (AW_* overrides).
# This stub is only needed if building without Buildroot's custom config path.
# -----------------------------------------------------------------------------
echo "[kernel-66] Step 10: write arch/arm64/configs/bsp_defconfig"
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
