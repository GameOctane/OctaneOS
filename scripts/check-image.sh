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
# Usage: scripts/check-image.sh [--release] [--no-sums]
#   --release   also fail if the developer SSH key is in the image (a release must not have it)
#   --no-sums   do not write SHA256SUMS
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
RELEASE=0
for arg in "$@"; do
    case "${arg}" in
        --no-sums) WRITE_SUMS=0 ;;
        --release) RELEASE=1 ;;
        *) echo "unknown option: ${arg}" >&2; exit 2 ;;
    esac
done

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
# Every option we ask for must exist in the built kernel (Kconfig drops options silently).
cfgcheck="$(mktemp)"
if "${REPO_ROOT}/scripts/check-kernel-config.py" "${CFG}" >"${cfgcheck}" 2>&1; then
    pass "every requested kernel option made it into the built kernel"
else
    bad "every requested kernel option made it into the built kernel"
fi
grep -E "FAIL|NOTE" "${cfgcheck}" | sed 's/^/        /'
rm -f "${cfgcheck}"
# AW_DISP2 is the legacy display driver. It builds only if AW_PWM is on, does not compile on
# 6.6, and would conflict with the DRM driver.
check "legacy display driver CONFIG_AW_DISP2 is off" bash -c "! grep -Eq '^CONFIG_AW_DISP2=(y|m)' '${CFG}'"
# The fan header needs the PWM driver and the fan driver (docs/a733-gotchas.md, fan header).
check "fan header: PWM driver and fan driver are built in (AW_PWM, SENSORS_PWM_FAN)" \
    bash -c "grep -Eq '^CONFIG_AW_PWM=y' '${CFG}' && grep -Eq '^CONFIG_SENSORS_PWM_FAN=y' '${CFG}'"

echo "== Device tree in the image"
DTB="${OUT}/images/sun60i-a733-cubie-a7s.dtb"
if [ -x "${DTC}" ] && [ -f "${DTB}" ]; then
    DTS="$("${DTC}" -I dtb -O dts "${DTB}" 2>/dev/null)"
    check "120 Hz: fps_limit_60 = <0> on the eDP node" grep -q 'fps_limit_60 = <0x00>' <<<"${DTS}"
    zones="$(grep -c 'thermal_zone' <<<"${DTS}")"
    check "thermal zones present (5 expected, found ${zones})" test "${zones}" -ge 5
    # Fan header J7: the fan's 5 V is the unswitched system rail (schematic page 16), so the node must
    # not name a fan-supply; it needs duty levels and a PWM channel, and the CPU and GPU zones must
    # each drive it in four steps (fan-map-1..4) with active trips.
    fan_node="$(awk '/pwm-fan \{/{f=1} f{print} f&&/\};/{exit}' <<<"${DTS}")"
    check "fan: pwm-fan node has cooling-levels and a pwms entry" \
        bash -c "grep -q cooling-levels <<<\"\$1\" && grep -q 'pwms =' <<<\"\$1\"" _ "${fan_node}"
    check "fan: pwm-fan node has no fan-supply (J7 pin 3 is the unswitched 5 V rail)" \
        bash -c "! grep -q fan-supply <<<\"\$1\"" _ "${fan_node}"
    fan_maps="$(grep -c 'fan-map-' <<<"${DTS}")"
    check "fan: three zones (big CPU, little CPU, GPU) x four steps = 12 fan cooling maps (found ${fan_maps})" \
        test "${fan_maps}" -ge 12
    active_trips="$(grep -c 'type = "active"' <<<"${DTS}")"
    check "fan: at least 12 active trip points (found ${active_trips})" test "${active_trips}" -ge 12
    for prop in ${OCTANE_CHECK_EXTRA_DTB_PROPS:-}; do
        check "extra property present: ${prop}" grep -q "${prop}" <<<"${DTS}"
    done
else
    bad "device tree blob and dtc available (${DTB})"
fi

# The boot line must not force one display profile on every unit (docs/a733-gotchas.md, item 6).
BOOTCONF="${OUT}/images/boot/extlinux/extlinux.conf"
[ -f "${BOOTCONF}" ] || BOOTCONF="${REPO_ROOT}/board/batocera/allwinner/a733/cubie-a7s/boot/extlinux.conf"
check "boot line does not force an EDID on every display (no drm.edid_firmware)" \
    bash -c "! grep -q 'drm.edid_firmware' '${BOOTCONF}'"

echo "== Image contents"
check "kernel Image exists" test -s "${OUT}/images/Image"
check "second filesystem layer rufomaculata exists" test -s "${OUT}/images/rufomaculata"
check "flight recorder installed and executable" test -x "${OUT}/target/usr/bin/octane-flightlog"
check "flight recorder init script installed" test -x "${OUT}/target/etc/init.d/S98octane-flightlog"
check "splash trace installed (records every start of the boot video)" \
    test -x "${OUT}/target/etc/init.d/S11splash-trace"
check "image is newer than the kernel it contains" \
    bash -c "[ \"\$(stat -c %Y '${IMG_DIR}'/*.img.gz | sort -n | tail -1)\" -ge \"\$(stat -c %Y '${OUT}/images/Image')\" ]"

# N64: the standalone emulator quits only on Esc and flickers on the ground in OoT without a
# polygon offset.  Both fixes ship in the image (see board/.../a733/fsoverlay).
# Devices must look for updates at OctaneOS, not at Batocera's server.
check "updates.url points at the OctaneOS GitHub repo in the default settings" \
    grep -qx 'updates.url=https://raw.githubusercontent.com/GameOctane/OctaneOS/main/ota' \
    "${OUT}/target/usr/share/batocera/datainit/system/batocera.conf"

# Performance: the compositor must not try (and fail) direct scan-out on every frame, and the DS bezel is off on a new card.
check "compositor start: direct scan-out is disabled (WLR_SCENE_DISABLE_DIRECT_SCANOUT=1)" \
    grep -q '^WLR_SCENE_DISABLE_DIRECT_SCANOUT=1 ' "${OUT}/target/usr/bin/labwc-launch"
check "DS bezel is off by default on a new card (nds.bezel=none)" \
    grep -qx 'nds.bezel=none' "${OUT}/target/usr/share/batocera/datainit/system/batocera.conf"

# The intro must play once.  S28splash plays it; a second copy in the labwc autostart played it
# again, inside the desktop, with a mouse cursor (the cause of the "intro plays twice" report).
check "the intro is played by S28splash only (no second player in the labwc start-up files)" \
    bash -c "! grep -rIlE 'splash\.mp4|--gpu-context=wayland' '${OUT}/target/usr/share/labwc' 2>/dev/null | grep -q ."
# ...and inside rootfs.squashfs, the file the device really boots (target/ can hold stale files)
SQUASH="${OUT}/images/rootfs.squashfs"
if [ -f "${SQUASH}" ] && [ -x "${OUT}/host/bin/unsquashfs" ]; then
    check "the second intro hook is not inside the system image (rootfs.squashfs)" \
        bash -c "! '${OUT}/host/bin/unsquashfs' -ll '${SQUASH}' 2>/dev/null | grep -q 'usr/share/labwc/autostart_sun60iw2'"
else
    bad "system image rootfs.squashfs and unsquashfs available to inspect"
fi
# Network defaults (docs/security-design-phase1.md), checked inside the system image itself.
if [ -f "${SQUASH}" ] && [ -x "${OUT}/host/bin/unsquashfs" ]; then
    in_image() { "${OUT}/host/bin/unsquashfs" -cat "${SQUASH}" "$1" 2>/dev/null | grep -q -- "$2"; }
    check "file share: guests cannot see the system folder or the RetroAchievements credential files" \
        in_image etc/samba/smb.conf '^veto files = /\._\*/\.DS_Store/system/retroachievements\.conf/\.default-retroachievements\.conf/$'
    check "NFS: not started when nothing is exported" in_image etc/init.d/S60nfs 'nothing exported in /etc/exports'
    check "Syncthing page: local-only by default" in_image usr/share/batocera/services/syncthing 'system.syncthing.lan'
    check "Wi-Fi is on by default on a fresh card" in_image usr/share/batocera/datainit/system/batocera.conf '^wifi.enabled=1$'
fi
check "N64 exit: hotkey+start is mapped to Esc" \
    grep -q '"KEY_ESC"' "${OUT}/target/usr/share/evmapy/n64.keys"
check "N64 default: polygon offset on in the seeded mupen64plus.cfg" \
    grep -qx 'force_polygon_offset = True' \
    "${OUT}/target/usr/share/batocera/datainit/system/configs/mupen64/mupen64plus.cfg"

# A build started with OCTANE_DEV_KEY_FILE set gives the key's holder root SSH on every device.
DEVKEY="${OUT}/target/usr/share/octane/dev-ssh-key.pub"
if [ -e "${DEVKEY}" ]; then
    if [ "${RELEASE}" -eq 1 ]; then
        bad "no developer SSH key in a release image (rebuild without OCTANE_DEV_KEY_FILE)"
    else
        echo "  NOTE  this image contains the developer SSH key; fine for testing, never release it"
    fi
else
    pass "no developer SSH key in the image"
fi

# Update signing: the updater refuses an update unless it is signed by one of the keys in the image.
UPKEYS="${OUT}/target/usr/share/octane/update-keys"
UNSIGNED_FLAG="${OUT}/target/usr/share/octane/allow-unsigned"
shopt -s nullglob
img_keys=("${UPKEYS}"/*.pem)
repo_keys=("${REPO_ROOT}"/keys/update/*.pub.pem)
shopt -u nullglob
if [ -e "${UNSIGNED_FLAG}" ]; then
    if [ "${RELEASE}" -eq 1 ]; then
        bad "no 'accepts unsigned updates' marker in a release image (it comes from OCTANE_DEV_KEY_FILE)"
    else
        echo "  NOTE  this image accepts updates without a signature (developer image); never release it"
    fi
else
    pass "this image does not accept unsigned updates"
fi
if [ "${#img_keys[@]}" -ge 2 ]; then
    pass "update signature keys are in the image (${#img_keys[@]})"
    same=1
    for rk in "${repo_keys[@]}"; do
        cmp -s "${rk}" "${UPKEYS}/$(basename "${rk%.pub.pem}").pem" || same=0
    done
    [ "${#repo_keys[@]}" -eq "${#img_keys[@]}" ] || same=0
    check "the keys in the image are exactly the project's keys (keys/update)" test "${same}" -eq 1
elif [ "${RELEASE}" -eq 1 ]; then
    bad "a release image needs the primary and the backup update key (found ${#img_keys[@]}); see docs/update-signing.md"
else
    echo "  NOTE  this image has ${#img_keys[@]} update key(s), so it can install updates only if it is a developer image"
fi

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
