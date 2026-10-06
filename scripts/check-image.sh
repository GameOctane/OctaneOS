#!/bin/bash
# Check a finished build before it is flashed or released.  Each check below exists because
# something went wrong without it:
#
#   - the build compiled a stale copy of the kernel (a fix was in the source but not the image)
#   - the 120 Hz device-tree property missed three releases for the same reason
#   - the second filesystem layer (rufomaculata) was never regenerated
#   - the kernel had no thermal management
#   - a config change silently switched on a second display driver
#
# It also writes standard-format SHA256SUMS next to the images.  The .sha256 files the build
# writes hold only the hash, so "sha256sum -c" cannot read them.
#
# Usage: scripts/check-image.sh [--no-sums]
#   exit status 0 = every check passed, 1 = at least one failed
#
# Environment: OCTANE_CHECK_EXTRA_DTB_PROPS="prop1 prop2" adds device-tree properties that
# must be present (used to test this script).
set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${REPO_ROOT}/batocera/output/a733-cubie-a7s"
IMG_DIR="${OUT}/images/batocera/images/cubie-a7s"
KSRC="${REPO_ROOT}/linux/kernel-66"
KBUILD="${OUT}/build/linux-custom"
DTC="${OUT}/host/bin/dtc"
WRITE_SUMS=1
[ "${1:-}" = "--no-sums" ] && WRITE_SUMS=0

fail=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
check() { # description, command...
    local d="$1"; shift
    if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi
}

echo "== Kernel build is not stale"
[ -d "${KBUILD}" ] || bad "kernel build directory exists (${KBUILD})"
# The files the patches and the board support change. If the compiled copy differs from the
# source tree, the build ran on an old copy: delete build/linux-custom and rebuild.
for f in drivers/usb/typec/tcpm/tcpm.c drivers/input/joystick/xpad.c \
         bsp/drivers/usb/typec/mux/sunxi-phy-switcher.c bsp/drivers/power/typec/tcpci_husb311.c \
         bsp/drivers/drm/sunxi_drm_edp.c bsp/drivers/drm/sunxi_drm_drv.c \
         bsp/drivers/power/mfd/axp2101.c arch/arm64/boot/dts/allwinner/sun60i-a733-cubie-a7s.dts; do
    check "compiled copy matches source: ${f}" cmp -s "${KSRC}/${f}" "${KBUILD}/${f}"
done
check "board DTS in the kernel tree matches the repo's" \
    cmp -s "${REPO_ROOT}/board/batocera/allwinner/a733/dts/sun60i-a733-cubie-a7s.dts" \
           "${KSRC}/arch/arm64/boot/dts/allwinner/sun60i-a733-cubie-a7s.dts"

echo "== Kernel configuration"
CFG="${KBUILD}/.config"
for opt in THERMAL AW_THERMAL SOFTLOCKUP_DETECTOR DETECT_HUNG_TASK; do
    check "CONFIG_${opt}=y" grep -qx "CONFIG_${opt}=y" "${CFG}"
done
# AW_DISP2 is the legacy display driver. It builds only if AW_PWM is on, does not compile on
# 6.6, and would conflict with the DRM driver.
check "legacy display driver CONFIG_AW_DISP2 is off" bash -c "! grep -Eq '^CONFIG_AW_DISP2=(y|m)' '${CFG}'"

echo "== Device tree in the image"
DTB="${OUT}/images/sun60i-a733-cubie-a7s.dtb"
if [ -x "${DTC}" ] && [ -f "${DTB}" ]; then
    DTS="$("${DTC}" -I dtb -O dts "${DTB}" 2>/dev/null)"
    check "120 Hz: fps_limit_60 = <0> on the eDP node" grep -q 'fps_limit_60 = <0x00>' <<<"${DTS}"
    zones="$(grep -c 'thermal_zone' <<<"${DTS}")"
    check "thermal zones present (5 expected, found ${zones})" test "${zones}" -ge 5
    for prop in ${OCTANE_CHECK_EXTRA_DTB_PROPS:-}; do
        check "extra property present: ${prop}" grep -q "${prop}" <<<"${DTS}"
    done
else
    bad "device tree blob and dtc available (${DTB})"
fi

echo "== Image contents"
check "kernel Image exists" test -s "${OUT}/images/Image"
check "second filesystem layer rufomaculata exists" test -s "${OUT}/images/rufomaculata"
check "flight recorder installed and executable" test -x "${OUT}/target/usr/bin/octane-flightlog"
check "flight recorder init script installed" test -x "${OUT}/target/etc/init.d/S98octane-flightlog"
check "image is newer than the kernel it contains" \
    bash -c "[ \"\$(stat -c %Y '${IMG_DIR}'/*.img.gz | sort -n | tail -1)\" -ge \"\$(stat -c %Y '${OUT}/images/Image')\" ]"

echo "== Checksums"
shopt -s nullglob
files=("${IMG_DIR}"/boot.tar.xz "${IMG_DIR}"/*.img.gz)
if [ "${#files[@]}" -eq 0 ]; then
    bad "release files found in ${IMG_DIR}"
else
    sums=""
    for f in "${files[@]}"; do
        calc="$(sha256sum "${f}" | cut -d' ' -f1)"
        rec="$(tr -d ' \n' < "${f}.sha256" 2>/dev/null | cut -c1-64)"
        if [ "${calc}" = "${rec}" ]; then pass "recorded sha256 matches: $(basename "${f}")"
        else bad "recorded sha256 matches: $(basename "${f}")"; fi
        sums+="${calc}  $(basename "${f}")"$'\n'
    done
    if [ "${WRITE_SUMS}" -eq 1 ] && [ "${fail}" -eq 0 ]; then
        printf '%s' "${sums}" > "${IMG_DIR}/SHA256SUMS"
        echo "  wrote ${IMG_DIR}/SHA256SUMS  (verify with: cd that folder && sha256sum -c SHA256SUMS)"
    fi
fi

echo
if [ "${fail}" -eq 0 ]; then echo "ALL CHECKS PASSED"; else echo "CHECKS FAILED"; fi
exit "${fail}"
