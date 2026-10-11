#!/bin/bash
# Test the device updater (fsoverlay/usr/bin/batocera-upgrade) against a fake /boot.
#
# It runs the real script with a fake curl (serves local files), a fake mount (records its
# calls) and a throw-away /boot, and checks the cases that matter: a normal update, and every
# way an update must be refused WITHOUT touching /boot.  Nothing here touches a device.
#
# Usage: scripts/test-upgrade.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-upgrade"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }

mkdir -p "${T}/bin" "${T}/serve"

# fake curl: serves $FAKE_SERVE_DIR/<basename of the url>, records its calls in $FAKE_LOG
cat > "${T}/bin/fakecurl" <<'FAKE'
#!/bin/bash
out=""; head=0; url=""; cont=0
echo "curl $*" >> "${FAKE_LOG:-/dev/null}"
while [ $# -gt 0 ]; do
    case "$1" in
        -C) cont=1; shift 2 ;;
        -A|--connect-timeout|--retry|--retry-delay|--proto|--proto-redir) shift 2 ;;
        --tlsv1.2) shift ;;
        -o) out="$2"; shift 2 ;;
        -*I*) head=1; shift ;;
        -*) shift ;;
        *) url="$1"; shift ;;
    esac
done
src="${FAKE_SERVE_DIR}/$(basename "${url}")"
[ -f "${src}" ] || exit 22
if [ "${head}" = 1 ]; then
    size=$(( $(stat -c %s "${src}") + ${FAKE_HEAD_EXTRA:-0} ))
    printf 'HTTP/2 200\r\ncontent-length: %s\r\n\r\n' "${size}"
    exit 0
fi
if [ "${cont}" = 1 ] && [ -f "${out}" ]; then
    have=$(stat -c %s "${out}"); tail -c +$((have + 1)) "${src}" >> "${out}"
else
    cp "${src}" "${out}"
fi
FAKE
# fake mount: only records what it was asked to do
cat > "${T}/bin/fakemount" <<'FAKE'
#!/bin/bash
echo "$*" >> "${FAKE_MOUNT_LOG}"
FAKE
chmod +x "${T}/bin/fakecurl" "${T}/bin/fakemount"

# build an update archive:  make_update <name> <board> [file-to-leave-out]
make_update() {
    local name="$1" board="$2" omit="${3:-}"
    local d="${T:?}/pkg-${name:?}"
    rm -rf "${d:?}"
    mkdir -p "${d}/boot" "${d}/extlinux" "${d}/tools"
    echo "NEW-KERNEL" > "${d}/boot/Image"; echo "NEW-INITRD" > "${d}/boot/initrd.lz4"
    echo "NEW-UINITRD" > "${d}/boot/uInitrd"; echo "NEW-UIMAGE" > "${d}/boot/uImage"
    echo "NEW-DTB" > "${d}/boot/sun60i-test.dtb"; printf '%s' "${board}" > "${d}/boot/batocera.board"
    head -c 300000 /dev/urandom > "${d}/boot/batocera.update"
    head -c 100000 /dev/urandom > "${d}/boot/rufomaculata.update"
    echo "NEW-EXTLINUX" > "${d}/extlinux/extlinux.conf"
    echo "new conf" > "${d}/batocera-boot.conf"; echo "x" > "${d}/tools/readme.txt"
    if [ -n "${omit}" ]; then rm -f "${d:?}/${omit:?}"; fi
    tar -C "${d}" -cf - . | xz -c > "${T}/serve/${name}.tar.xz"
}
# write <archive>.md5 and <archive>.sha256 (hash only, like the build does)
sums() { md5sum "$1" | awk '{print $1}' > "$1.md5"; sha256sum "$1" | awk '{print $1}' > "$1.sha256"; }

reset_device() {
    rm -rf "${T:?}/boot" "${T:?}/upg" "${T:?}/mount.log" "${T:?}/curl.log" "${T:?}/lock"
    mkdir -p "${T}/boot/boot" "${T}/boot/extlinux" "${T}/upg"
    echo "OLD-KERNEL" > "${T}/boot/boot/Image"; echo "OLD-INITRD" > "${T}/boot/boot/initrd.lz4"
    echo "cubie-a7s" > "${T}/boot/boot/batocera.board"; echo "OLD-LAYER" > "${T}/boot/boot/batocera"
    echo "OLD-EXTLINUX" > "${T}/boot/extlinux/extlinux.conf"
    echo "user conf" > "${T}/boot/batocera-boot.conf"
    echo "gone" > "${T}/boot/boot/obsolete-file"; echo "hook" > "${T}/boot/boot-custom.sh"
    : > "${T}/mount.log"; : > "${T}/curl.log"
}

# run the updater; sets RC and OUT.     run_upgrade [args...]
run_upgrade() {
    OUT=$(OCTANE_BOOT_DIR="${T}/boot" OCTANE_UPGRADE_DIR="${T}/upg" OCTANE_CURL="${T}/bin/fakecurl" \
          OCTANE_MOUNT="${T}/bin/fakemount" OCTANE_LOCK="${T}/lock" OCTANE_TERMINAL="${TERM_MODE:-1}" \
          OCTANE_RELEASE_URL="https://example.invalid/dl" FAKE_SERVE_DIR="${T}/serve" FAKE_LOG="${T}/curl.log" \
          FAKE_MOUNT_LOG="${T}/mount.log" FAKE_HEAD_EXTRA="${FAKE_HEAD_EXTRA:-0}" PATH="${EXTRA_PATH:-}:${PATH}" \
          bash "${UPGRADE}" "$@" 2>&1)
    RC=$?
}
# /boot still holds exactly the old files and was never made writable
boot_untouched() {
    [ "$(cat "${T}/boot/boot/Image")" = "OLD-KERNEL" ] && [ "$(cat "${T}/boot/extlinux/extlinux.conf")" = "OLD-EXTLINUX" ] \
      && [ ! -e "${T}/boot/boot/batocera.update" ] && ! grep -q rw "${T}/mount.log"
}
relocked() { [ "$(grep -c 'remount,rw' "${T}/mount.log")" = "$(grep -c 'remount,ro' "${T}/mount.log")" ]; }
# publish an archive as boot.tar.xz with both checksums
set_serve() { rm -f "${T:?}"/serve/boot.tar.xz*; cp "${T}/serve/$1.tar.xz" "${T}/serve/boot.tar.xz"; sums "${T}/serve/boot.tar.xz"; }

make_update good cubie-a7s
make_update wrongboard rpi5
make_update noimage cubie-a7s boot/Image

echo "== normal update"
reset_device; set_serve good; run_upgrade
check "exit status 0" '[ "${RC}" = 0 ]'
check "new kernel, initrd, dtb and boot menu installed" '[ "$(cat ${T}/boot/boot/Image)" = NEW-KERNEL ] && [ "$(cat ${T}/boot/boot/initrd.lz4)" = NEW-INITRD ] && [ -f ${T}/boot/boot/sun60i-test.dtb ] && [ "$(cat ${T}/boot/extlinux/extlinux.conf)" = NEW-EXTLINUX ]'
check "system layers installed intact" 'cmp -s ${T}/pkg-good/boot/batocera.update ${T}/boot/boot/batocera.update && cmp -s ${T}/pkg-good/boot/rufomaculata.update ${T}/boot/boot/rufomaculata.update'
check "the user's batocera-boot.conf was kept" '[ "$(cat ${T}/boot/batocera-boot.conf)" = "user conf" ]'
check "no leftover .new files" '[ -z "$(find ${T}/boot -name "*.new")" ]'
check "stale list names the removed file, not the user hook" 'grep -qx boot/obsolete-file ${T}/boot/boot.stale && ! grep -q boot-custom ${T}/boot/boot.stale'
check "/boot made writable once and locked again" '[ "$(cat ${T}/mount.log | tr "\n" ";")" = "-o remount,rw ${T}/boot;-o remount,ro ${T}/boot;" ]'
check "download and staging folder cleaned up" '[ ! -e ${T}/upg/boot.tar.xz ] && [ ! -d ${T}/upg/stage ]'

echo "== refused without touching /boot"
reset_device; set_serve good; rm -f "${T:?}/serve/boot.tar.xz.md5" "${T:?}/serve/boot.tar.xz.sha256"; run_upgrade
check "no checksum published -> refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "no checksum is published" && boot_untouched'
reset_device; set_serve good; echo 00000000000000000000000000000000 > "${T}/serve/boot.tar.xz.md5"; run_upgrade
check "wrong md5 -> refused, download removed" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "md5 checksum does not match" && boot_untouched && [ ! -e ${T}/upg/boot.tar.xz ]'
reset_device; set_serve good; echo 0000000000000000000000000000000000000000000000000000000000000000 > "${T}/serve/boot.tar.xz.sha256"; run_upgrade
check "wrong sha256 -> refused even when the md5 is right" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "sha256 checksum does not match" && boot_untouched'
reset_device; set_serve good; echo "not a hash" > "${T}/serve/boot.tar.xz.md5"; rm -f "${T:?}/serve/boot.tar.xz.sha256"; run_upgrade
check "malformed checksum file -> refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q malformed && boot_untouched'
reset_device; set_serve wrongboard; run_upgrade
check "archive for another board -> refused before /boot is touched" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "for .rpi5. but this device is .cubie-a7s." && boot_untouched'
reset_device; set_serve noimage; run_upgrade
check "archive missing boot/Image -> refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "missing boot/Image" && boot_untouched'
reset_device; head -c 150000 "${T}/serve/good.tar.xz" > "${T}/serve/boot.tar.xz"; rm -f "${T:?}/serve/boot.tar.xz.md5" "${T:?}/serve/boot.tar.xz.sha256"; sums "${T}/serve/boot.tar.xz"; run_upgrade
check "truncated archive with matching checksums -> refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "damaged" && boot_untouched'
reset_device; set_serve good; FAKE_HEAD_EXTRA=17 run_upgrade; FAKE_HEAD_EXTRA=0
check "download shorter than announced -> refused" '[ "${RC}" = 1 ] && boot_untouched'
reset_device; set_serve good; run_upgrade "http://example.invalid/boot.tar.xz"
check "plain http URL -> refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "only https" && boot_untouched'

echo "== failure half-way through the install"
reset_device; set_serve good
mkdir -p "${T}/failbin"
printf '#!/bin/bash\ncase "$*" in *initrd.lz4.new*) exit 1;; esac\nexec /bin/cp "$@"\n' > "${T}/failbin/cp"; chmod +x "${T}/failbin/cp"
EXTRA_PATH="${T}/failbin" run_upgrade
check "install failure -> non-zero exit and says to run again" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "run the update again"'
check "/boot locked again after the failure" 'relocked'
check "boot menu (extlinux.conf) is the LAST file and was not reached" '[ "$(cat ${T}/boot/extlinux/extlinux.conf)" = OLD-EXTLINUX ]'
check "no half-written .new file left behind" '[ -z "$(find ${T}/boot -name "*.new")" ]'

echo "== other behaviour"
reset_device; set_serve good; ( flock 9; sleep 4 ) 9> "${T}/lock" & sleep 0.5; run_upgrade; wait
check "a second update while one is running is refused" '[ "${RC}" = 1 ] && echo "${OUT}" | grep -q "already running"'
reset_device; set_serve good; head -c 120000 "${T}/serve/boot.tar.xz" > "${T}/upg/boot.tar.xz"; run_upgrade
check "a partial download is resumed, not restarted" '[ "${RC}" = 0 ] && grep -q -- "-C -" ${T}/curl.log && [ "$(cat ${T}/boot/boot/Image)" = NEW-KERNEL ]'
reset_device; set_serve good; rm -f "${T:?}/serve/boot.tar.xz.md5"; run_upgrade
check "only a sha256 published -> accepted" '[ "${RC}" = 0 ] && [ "$(cat ${T}/boot/boot/Image)" = NEW-KERNEL ]'
reset_device; cp "${T}/serve/good.tar.xz" "${T}/upg/boot.tar.xz"; sums "${T}/upg/boot.tar.xz"; run_upgrade manual
check "manual mode with checksum files: installs, then removes the archive and the checksum files" '[ "${RC}" = 0 ] && [ ! -e ${T}/upg/boot.tar.xz ] && [ ! -e ${T}/upg/boot.tar.xz.md5 ] && [ ! -e ${T}/upg/boot.tar.xz.sha256 ]'
reset_device; cp "${T}/serve/good.tar.xz" "${T}/upg/boot.tar.xz"; run_upgrade manual
check "manual mode, no checksum file -> installs with a warning" '[ "${RC}" = 0 ] && echo "${OUT}" | grep -q "WARNING: no checksum" && [ "$(cat ${T}/boot/boot/Image)" = NEW-KERNEL ]'
reset_device; cp "${T}/serve/good.tar.xz" "${T}/upg/boot.tar.xz"; echo 00000000000000000000000000000000 > "${T}/upg/boot.tar.xz.md5"; run_upgrade manual
check "manual mode, wrong md5 -> refused" '[ "${RC}" = 1 ] && boot_untouched'
reset_device; set_serve good; TERM_MODE=0 run_upgrade
check "EmulationStation mode (no terminal) installs and exits 0" '[ "${RC}" = 0 ] && [ "$(cat ${T}/boot/boot/Image)" = NEW-KERNEL ] && relocked'
check "EmulationStation mode: no stray shell job messages ('Killed') in the output" '! echo "${OUT}" | grep -q "Killed"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
