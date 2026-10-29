#!/bin/bash
# Test the update signature checks: the manifest/signature scripts and the device updater
# (fsoverlay/usr/bin/batocera-upgrade) against a fake /boot, a fake network and throw-away keys.
#
# Every refusal must happen BEFORE /boot is touched; every acceptance must leave /boot read-only
# again.  Nothing here touches a device or uses a real key.
#
# Usage: scripts/test-update-signing.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPGRADE="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-upgrade"
S="${REPO_ROOT}/scripts"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

# The signing scripts look for the project's public keys next to themselves (../keys/update). Run them from a copy with an EMPTY keys
# folder, so these tests do not change behaviour when the real keys are committed to keys/update.
SB="${T}/sandbox"; mkdir -p "${SB}/scripts" "${SB}/keys/update"
cp "${S}/make-manifest.sh" "${S}/sign-release.sh" "${S}/verify-signature.sh" "${SB}/scripts/"
command -v openssl >/dev/null || { echo "openssl is needed for these tests" >&2; exit 2; }

PASS=0; FAIL=0
ok()   { PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; }
bad()  { FAIL=$((FAIL+1)); printf '  FAIL  %s\n' "$1"; [ -n "${2:-}" ] && printf '        %s\n' "$2"; }
check() { if eval "$2"; then ok "$1"; else bad "$1" "$2"; fi; }

mkdir -p "${T}/bin" "${T}/serve" "${T}/keys" "${T}/priv"

# ---- throw-away keys: two the image trusts, one it does not ----
for k in primary backup rogue; do
    openssl genpkey -algorithm ED25519 -out "${T}/priv/${k}.pem" 2>/dev/null
    openssl pkey -in "${T}/priv/${k}.pem" -pubout -out "${T}/priv/${k}.pub.pem" 2>/dev/null
done
cp "${T}/priv/primary.pub.pem" "${T}/keys/primary.pem"; cp "${T}/priv/backup.pub.pem" "${T}/keys/backup.pem"

# ---- fake curl and mount (same idea as scripts/test-upgrade.sh) ----
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
cat > "${T}/bin/fakemount" <<'FAKE'
#!/bin/bash
echo "$*" >> "${FAKE_MOUNT_LOG}"
FAKE
chmod +x "${T}/bin/fakecurl" "${T}/bin/fakemount"

# an update archive:  make_update <name> <board>
make_update() {
    local name="$1" board="$2" d="${T:?}/pkg-${1:?}"
    rm -rf "${d:?}"; mkdir -p "${d}/boot" "${d}/extlinux"
    echo "NEW-KERNEL" > "${d}/boot/Image"; echo "NEW-INITRD" > "${d}/boot/initrd.lz4"
    echo "NEW-DTB" > "${d}/boot/sun60i-test.dtb"; printf '%s' "${board}" > "${d}/boot/batocera.board"
    head -c 200000 /dev/urandom > "${d}/boot/batocera.update"; head -c 80000 /dev/urandom > "${d}/boot/rufomaculata.update"
    echo "NEW-EXTLINUX" > "${d}/extlinux/extlinux.conf"
    tar -C "${d}" -cf - . | xz -c > "${T}/serve/${name}.tar.xz"
}
make_update good cubie-a7s

# a signed release on the fake server:  publish <version> <board> <key> [with-legacy-sums]
publish() {
    local version="$1" board="$2" key="$3" sums="${4:-yes}"
    rm -f "${T:?}"/serve/boot.tar.xz*
    cp "${T}/serve/good.tar.xz" "${T}/serve/boot.tar.xz"
    if [ "${sums}" = yes ]; then
        md5sum "${T}/serve/boot.tar.xz" | awk '{print $1}' > "${T}/serve/boot.tar.xz.md5"
        sha256sum "${T}/serve/boot.tar.xz" | awk '{print $1}' > "${T}/serve/boot.tar.xz.sha256"
    fi
    bash "${SB}/scripts/make-manifest.sh" "${board}" "${version}" "${T}/serve/boot.tar.xz" "${T}/serve/boot.tar.xz.manifest" >/dev/null
    bash "${SB}/scripts/sign-release.sh" "${T}/serve/boot.tar.xz.manifest" "${T}/priv/${key}.pem" "${T}/serve/boot.tar.xz.manifest.sig" >/dev/null 2>&1
}
# re-sign the (edited) manifest with <key>
resign() { bash "${SB}/scripts/sign-release.sh" "${T}/serve/boot.tar.xz.manifest" "${T}/priv/$1.pem" "${T}/serve/boot.tar.xz.manifest.sig" >/dev/null 2>&1; }

reset_device() {
    rm -rf "${T:?}/boot" "${T:?}/upg" "${T:?}/mount.log" "${T:?}/curl.log" "${T:?}/lock" "${T:?}/allow-unsigned"
    mkdir -p "${T}/boot/boot" "${T}/boot/extlinux" "${T}/upg"
    echo "OLD-KERNEL" > "${T}/boot/boot/Image"; echo "OLD-INITRD" > "${T}/boot/boot/initrd.lz4"
    echo "cubie-a7s" > "${T}/boot/boot/batocera.board"; echo "OLD-LAYER" > "${T}/boot/boot/batocera"
    echo "OLD-EXTLINUX" > "${T}/boot/extlinux/extlinux.conf"
    echo "0.7.0" > "${T}/installed.version"; KEYS="${T}/keys"; DEV=0
    : > "${T}/mount.log"; : > "${T}/curl.log"
}
developer_image() { : > "${T}/allow-unsigned"; DEV=1; }

# run the updater; sets RC and OUT.     run_upgrade [args...]
run_upgrade() {
    OUT=$(OCTANE_BOOT_DIR="${T}/boot" OCTANE_UPGRADE_DIR="${T}/upg" OCTANE_CURL="${T}/bin/fakecurl" \
          OCTANE_MOUNT="${T}/bin/fakemount" OCTANE_LOCK="${T}/lock" OCTANE_TERMINAL=1 \
          OCTANE_RELEASE_URL="https://example.invalid/dl" FAKE_SERVE_DIR="${T}/serve" FAKE_LOG="${T}/curl.log" \
          FAKE_MOUNT_LOG="${T}/mount.log" FAKE_HEAD_EXTRA="${FAKE_HEAD_EXTRA:-0}" \
          OCTANE_KEYS_DIR="${KEYS}" OCTANE_ALLOW_UNSIGNED_FLAG="${T}/allow-unsigned" \
          OCTANE_VERSION_FILE="${T}/installed.version" bash "${UPGRADE}" "$@" 2>&1)
    RC=$?
}
boot_untouched() {
    [ "$(cat "${T}/boot/boot/Image")" = "OLD-KERNEL" ] && [ "$(cat "${T}/boot/extlinux/extlinux.conf")" = "OLD-EXTLINUX" ] \
      && [ ! -e "${T}/boot/boot/batocera.update" ] && ! grep -q rw "${T}/mount.log"
}
installed() { [ "$(cat "${T}/boot/boot/Image")" = "NEW-KERNEL" ] && [ "$(cat "${T}/boot/extlinux/extlinux.conf")" = "NEW-EXTLINUX" ]; }
relocked() { [ "$(grep -c 'remount,rw' "${T}/mount.log")" = "$(grep -c 'remount,ro' "${T}/mount.log")" ]; }
no_archive_fetched() { [ ! -f "${T}/upg/boot.tar.xz" ] && ! grep -qE -- '-C - ' "${T}/curl.log"; }
# a refusal: non-zero exit, the message names the reason, /boot untouched
refused() { [ "${RC}" -ne 0 ] && grep -q -- "$1" <<<"${OUT}" && boot_untouched && relocked; }

echo "== manifest, signing and verification scripts"
echo "payload" > "${T}/blob.bin"
bash "${SB}/scripts/make-manifest.sh" cubie-a7s 0.8.0 "${T}/blob.bin" >/dev/null 2>&1
check "make-manifest writes the five fields" \
    '[ "$(cut -d= -f1 "${T}/blob.bin.manifest" | tr "\n" " ")" = "octaneos-manifest board version file size sha256 " ]'
check "make-manifest records the real size and sha256" \
    'grep -qx "size=8" "${T}/blob.bin.manifest" && grep -qx "sha256=$(sha256sum "${T}/blob.bin" | cut -d" " -f1)" "${T}/blob.bin.manifest"'
check "make-manifest refuses a bad version" '! bash "${SB}/scripts/make-manifest.sh" cubie-a7s 0.8.x "${T}/blob.bin" "${T}/m1" >/dev/null 2>&1'
check "make-manifest refuses a bad board name" '! bash "${SB}/scripts/make-manifest.sh" "Cubie A7S" 0.8.0 "${T}/blob.bin" "${T}/m2" >/dev/null 2>&1'
bash "${SB}/scripts/sign-release.sh" "${T}/blob.bin.manifest" "${T}/priv/primary.pem" "${T}/blob.sig" >/dev/null 2>&1
check "the signature is 64 bytes" '[ "$(stat -c %s "${T}/blob.sig")" = 64 ]'
check "verify-signature accepts the right key" 'bash "${SB}/scripts/verify-signature.sh" "${T}/blob.bin.manifest" "${T}/blob.sig" "${T}/priv/rogue.pub.pem" "${T}/priv/primary.pub.pem" >/dev/null 2>&1'
check "verify-signature refuses a key that did not sign" '! bash "${SB}/scripts/verify-signature.sh" "${T}/blob.bin.manifest" "${T}/blob.sig" "${T}/priv/rogue.pub.pem" >/dev/null 2>&1'
cp "${T}/blob.bin.manifest" "${T}/edited.manifest"; echo "extra=1" >> "${T}/edited.manifest"
check "verify-signature refuses a manifest edited after signing" '! bash "${SB}/scripts/verify-signature.sh" "${T}/edited.manifest" "${T}/blob.sig" "${T}/priv/primary.pub.pem" >/dev/null 2>&1'
# sign-release checks the result against the project's public keys when they sit next to it
mkdir -p "${T}/proj/scripts" "${T}/proj/keys/update"
cp "${S}/sign-release.sh" "${S}/verify-signature.sh" "${T}/proj/scripts/"; cp "${T}/priv/primary.pub.pem" "${T}/proj/keys/update/primary.pub.pem"
check "sign-release removes a signature made with a key that is not a project key" \
    '! bash "${T}/proj/scripts/sign-release.sh" "${T}/blob.bin.manifest" "${T}/priv/rogue.pem" "${T}/rogue.sig" >/dev/null 2>&1 && [ ! -e "${T}/rogue.sig" ]'
check "sign-release keeps a signature made with a project key" \
    'bash "${T}/proj/scripts/sign-release.sh" "${T}/blob.bin.manifest" "${T}/priv/primary.pem" "${T}/ok.sig" >/dev/null 2>&1 && [ -s "${T}/ok.sig" ]'

echo "== normal image (not a developer image)"
reset_device; publish 0.8.0 cubie-a7s primary
run_upgrade
check "signed with the primary key, newer version -> installs" 'installed && [ "${RC}" -eq 0 ] && relocked && grep -q "signature valid: boot.tar.xz version 0.8.0" <<<"${OUT}"'
reset_device; publish 0.8.0 cubie-a7s backup
run_upgrade
check "signed with the backup key -> installs" 'installed && [ "${RC}" -eq 0 ] && relocked'
reset_device; publish 0.7.0 cubie-a7s primary
run_upgrade
check "the same version as installed -> installs (a repair)" 'installed && [ "${RC}" -eq 0 ]'
reset_device; publish 0.8.0 cubie-a7s primary no
run_upgrade
check "signed, and no .md5/.sha256 published -> installs (the manifest is the checksum)" 'installed && [ "${RC}" -eq 0 ]'

reset_device; publish 0.8.0 cubie-a7s rogue
run_upgrade
check "signed by a key the image does not trust -> refused before the big download" 'refused "does not match any key" && no_archive_fetched'
reset_device; publish 0.8.0 cubie-a7s primary
sed -i 's/^version=0.8.0/version=9.9.9/' "${T}/serve/boot.tar.xz.manifest"
run_upgrade
check "manifest edited after it was signed -> refused" 'refused "does not match any key" && no_archive_fetched'
reset_device; publish 0.8.0 cubie-a7s primary
head -c 32 "${T}/serve/boot.tar.xz.manifest.sig" > "${T}/short.sig"; cp "${T}/short.sig" "${T}/serve/boot.tar.xz.manifest.sig"
run_upgrade
check "a truncated signature -> refused" 'refused "does not match any key"'

reset_device; publish 0.8.0 cubie-a7s primary
cp "${T}/serve/boot.tar.xz" "${T}/swap.tar.xz"; printf 'X' | dd of="${T}/swap.tar.xz" bs=1 seek=100 conv=notrunc 2>/dev/null; cp "${T}/swap.tar.xz" "${T}/serve/boot.tar.xz"
md5sum "${T}/serve/boot.tar.xz" | awk '{print $1}' > "${T}/serve/boot.tar.xz.md5"; sha256sum "${T}/serve/boot.tar.xz" | awk '{print $1}' > "${T}/serve/boot.tar.xz.sha256"
run_upgrade
check "archive swapped (same size, new checksum files published too) -> refused by the signed hash, download removed" \
    'refused "does not match the signed manifest" && [ ! -f "${T}/upg/boot.tar.xz" ]'
reset_device; publish 0.8.0 cubie-a7s primary
FAKE_HEAD_EXTRA=7 run_upgrade
check "the server's file is not the signed size -> refused" 'refused "not the size the signed manifest says"'

reset_device; publish 0.8.0 cubie-a7s primary
rm -f "${T}/serve/boot.tar.xz.manifest" "${T}/serve/boot.tar.xz.manifest.sig"
run_upgrade
check "no signature published -> refused" 'refused "not signed"'
reset_device; publish 0.8.0 cubie-a7s primary
rm -f "${T}/serve/boot.tar.xz.manifest.sig"
run_upgrade
check "manifest without a signature -> refused" 'refused "not signed"'
reset_device; publish 0.8.0 cubie-a7s primary; KEYS="${T}/no-such-folder"
run_upgrade
check "an image with no update keys -> refused (fails closed)" 'refused "no update keys"'

reset_device; publish 0.6.9 cubie-a7s primary
run_upgrade
check "an older (validly signed) version -> refused as a downgrade" 'refused "refusing the downgrade" && no_archive_fetched'
reset_device; publish 0.6.9 cubie-a7s primary
run_upgrade --allow-downgrade
check "--allow-downgrade accepts it, with a warning" 'installed && [ "${RC}" -eq 0 ] && grep -q "WARNING: installing the older version 0.6.9" <<<"${OUT}"'
reset_device; publish 0.6.9 cubie-a7s rogue
run_upgrade --allow-downgrade
check "--allow-downgrade does not excuse a wrong signature" 'refused "does not match any key"'
reset_device; publish 0.10.0 cubie-a7s primary; echo "0.9.0" > "${T}/installed.version"
run_upgrade
check "versions compare as numbers (0.10.0 is newer than 0.9.0)" 'installed && [ "${RC}" -eq 0 ]'
reset_device; publish 0.8.0 cubie-a7s primary; rm -f "${T}/installed.version"
run_upgrade
check "the installed version cannot be read -> refused" 'refused "cannot read the installed version"'
reset_device; publish 0.8.0 cubie-a7s primary; echo "v0.7.0" > "${T}/installed.version"
run_upgrade
check "an installed version written with a leading 'v' is understood" 'installed && [ "${RC}" -eq 0 ]'

reset_device; publish 0.8.0 rpi5 primary
run_upgrade
check "signed for another board -> refused" 'refused "update is signed for"'
reset_device; publish 0.8.0 cubie-a7s primary
sed -i 's/^file=boot.tar.xz/file=other.tar.xz/' "${T}/serve/boot.tar.xz.manifest"; resign primary
run_upgrade
check "manifest names a different file -> refused" 'refused "signed manifest is for"'
reset_device; publish 0.8.0 cubie-a7s primary
echo "version=0.1.0" >> "${T}/serve/boot.tar.xz.manifest"; resign primary
run_upgrade
check "a manifest with the version twice -> refused" 'refused "no valid version"'
reset_device; publish 0.8.0 cubie-a7s primary
grep -v '^sha256=' "${T}/serve/boot.tar.xz.manifest" > "${T}/m.tmp"; cp "${T}/m.tmp" "${T}/serve/boot.tar.xz.manifest"; resign primary
run_upgrade
check "a manifest without the sha256 -> refused" 'refused "no valid sha256"'
reset_device; publish 0.8.0 cubie-a7s primary
sed -i 's/^octaneos-manifest=1/octaneos-manifest=2/' "${T}/serve/boot.tar.xz.manifest"; resign primary
run_upgrade
check "an unknown manifest format -> refused" 'refused "unknown format"'
reset_device; publish 0.8.0 cubie-a7s primary
head -c 5000 /dev/zero | tr '\0' '#' | sed 's/^/# /' >> "${T}/serve/boot.tar.xz.manifest"; resign primary
run_upgrade
check "an oversized manifest -> refused" 'refused "too large"'

echo "== manual mode (files put in the upgrade folder by hand)"
reset_device; publish 0.8.0 cubie-a7s primary
cp "${T}/serve/boot.tar.xz" "${T}/serve/boot.tar.xz.manifest" "${T}/serve/boot.tar.xz.manifest.sig" "${T}/upg/"
run_upgrade manual
check "manual mode with a good signature -> installs and removes the files" \
    'installed && [ "${RC}" -eq 0 ] && [ ! -e "${T}/upg/boot.tar.xz" ] && [ ! -e "${T}/upg/boot.tar.xz.manifest" ] && [ ! -e "${T}/upg/boot.tar.xz.manifest.sig" ]'
reset_device; publish 0.8.0 cubie-a7s primary
cp "${T}/serve/boot.tar.xz" "${T}/upg/"
run_upgrade manual
check "manual mode, no signature -> refused" 'refused "not signed"'
reset_device; publish 0.8.0 cubie-a7s rogue
cp "${T}/serve/boot.tar.xz" "${T}/serve/boot.tar.xz.manifest" "${T}/serve/boot.tar.xz.manifest.sig" "${T}/upg/"
run_upgrade manual
check "manual mode, wrong key -> refused" 'refused "does not match any key"'

echo "== developer image (the flag file exists)"
reset_device; developer_image; publish 0.8.0 cubie-a7s primary
rm -f "${T}/serve/boot.tar.xz.manifest" "${T}/serve/boot.tar.xz.manifest.sig"
run_upgrade
check "no signature -> installs with a warning (checksums still checked)" 'installed && [ "${RC}" -eq 0 ] && grep -q "WARNING: this update has no signature" <<<"${OUT}"'
reset_device; developer_image; publish 0.8.0 cubie-a7s rogue
run_upgrade
check "a WRONG signature is still refused" 'refused "does not match any key"'
reset_device; developer_image; publish 0.8.0 cubie-a7s primary; KEYS="${T}/no-such-folder"
run_upgrade
check "no keys in the image, signature present -> installs with a warning" 'installed && [ "${RC}" -eq 0 ] && grep -q "has no update keys" <<<"${OUT}"'
reset_device; developer_image; publish 0.8.0 cubie-a7s primary
rm -f "${T}/serve/boot.tar.xz.md5" "${T}/serve/boot.tar.xz.sha256" "${T}/serve/boot.tar.xz.manifest" "${T}/serve/boot.tar.xz.manifest.sig"
run_upgrade
check "no signature and no checksum -> still refused" 'refused "no checksum"'

echo "== image build: the keys and the developer marker (code taken from post-build.sh and check-image.sh)"
PB="${REPO_ROOT}/board/batocera/allwinner/a733/post-build.sh"
CI="${REPO_ROOT}/scripts/check-image.sh"
awk '/^UPDATE_KEYS_SRC=/{f=1} f&&/^# =====/{exit} f' "${PB}" > "${T}/pb-block.sh"
awk '/^# Update signing: the updater refuses/{f=1} f&&/^echo "== Checksums"/{exit} f' "${CI}" > "${T}/ci-block.sh"
check "the post-build key block was found in post-build.sh" '[ -s "${T}/pb-block.sh" ] && grep -q allow-unsigned "${T}/pb-block.sh"'
check "the image-check key block was found in check-image.sh" '[ -s "${T}/ci-block.sh" ] && grep -q allow-unsigned "${T}/ci-block.sh"'

# a fake repo (public keys only) and a fake build target
mkdir -p "${T}/fake/scripts" "${T}/fake/keys/update"
cp "${T}/priv/primary.pub.pem" "${T}/fake/keys/update/primary.pub.pem"; cp "${T}/priv/backup.pub.pem" "${T}/fake/keys/update/backup.pub.pem"
post_build() { rm -rf "${T:?}/tgt"; mkdir -p "${T}/tgt/usr/share/octane"; [ -n "${PRE:-}" ] && eval "${PRE}"; \
    TARGET_DIR="${T}/tgt" REPO_ROOT_FOR_SCRIPTS="${T}/fake/scripts" OCTANE_DEV_KEY_FILE="${DEVFILE:-}" bash "${T}/pb-block.sh" >"${T}/pb.out" 2>&1; }
PRE=""; DEVFILE=""; post_build
check "a normal build installs both public keys" '[ "$(ls "${T}/tgt/usr/share/octane/update-keys" | tr "\n" " ")" = "backup.pem primary.pem " ] && cmp -s "${T}/fake/keys/update/primary.pub.pem" "${T}/tgt/usr/share/octane/update-keys/primary.pem"'
check "a normal build has no developer marker" '[ ! -e "${T}/tgt/usr/share/octane/allow-unsigned" ]'
PRE=': > "${T}/tgt/usr/share/octane/allow-unsigned"; mkdir -p "${T}/tgt/usr/share/octane/update-keys"; : > "${T}/tgt/usr/share/octane/update-keys/old-key.pem"'; DEVFILE=""; post_build
check "a normal build removes a developer marker left over from an earlier build" '[ ! -e "${T}/tgt/usr/share/octane/allow-unsigned" ]'
check "...and a key that is no longer in the repo" '[ ! -e "${T}/tgt/usr/share/octane/update-keys/old-key.pem" ]'
PRE=""; DEVFILE="/some/key.pub"; post_build
check "a developer build (OCTANE_DEV_KEY_FILE set) writes the marker, and still installs the keys" '[ -e "${T}/tgt/usr/share/octane/allow-unsigned" ] && [ -e "${T}/tgt/usr/share/octane/update-keys/primary.pem" ]'
rm -f "${T}/fake/keys/update/backup.pub.pem"; PRE=""; DEVFILE=""; post_build
check "fewer than two keys in the repo -> a warning in the build output" 'grep -q "fewer than two update keys" "${T}/pb.out"'
cp "${T}/priv/backup.pub.pem" "${T}/fake/keys/update/backup.pub.pem"

# the image check, against fake build outputs
run_image_check() {   # sets CI_OUT; RELEASE from $1
    CI_OUT=$(RELEASE="$1" OUT="${T}/imgout" REPO_ROOT="${T}/fake" bash -c '
        pass() { echo "PASS $1"; }; bad() { echo "FAIL $1"; }
        check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then pass "$d"; else bad "$d"; fi; }
        source "'"${T}"'/ci-block.sh"' 2>&1)
}
fake_image() {   # fake_image <keys: both|one|none> <marker: yes|no> <match: yes|no>
    rm -rf "${T:?}/imgout"; mkdir -p "${T}/imgout/target/usr/share/octane/update-keys"
    local u="${T}/imgout/target/usr/share/octane/update-keys"
    [ "$1" != none ] && cp "${T}/priv/primary.pub.pem" "${u}/primary.pem"
    [ "$1" = both ] && cp "${T}/priv/backup.pub.pem" "${u}/backup.pem"
    [ "$3" = no ] && [ "$1" = both ] && cp "${T}/priv/rogue.pub.pem" "${u}/backup.pem"
    [ "$2" = yes ] && : > "${T}/imgout/target/usr/share/octane/allow-unsigned"
    return 0
}
fake_image both no yes; run_image_check 1
check "release image with both project keys and no marker -> no failures" '! grep -q "^FAIL" <<<"${CI_OUT}" && grep -q "update signature keys are in the image" <<<"${CI_OUT}"'
fake_image both yes yes; run_image_check 1
check "release image with the developer marker -> FAIL" 'grep -q "^FAIL no .accepts unsigned updates. marker in a release image" <<<"${CI_OUT}"'
fake_image both yes yes; run_image_check 0
check "the same image as a plain test build -> only a note" '! grep -q "^FAIL" <<<"${CI_OUT}" && grep -q "NOTE  this image accepts updates without a signature" <<<"${CI_OUT}"'
fake_image one no yes; run_image_check 1
check "release image with only one key -> FAIL (a backup key is required)" 'grep -q "^FAIL a release image needs the primary and the backup" <<<"${CI_OUT}"'
fake_image none no yes; run_image_check 1
check "release image with no keys -> FAIL" 'grep -q "^FAIL a release image needs the primary and the backup" <<<"${CI_OUT}"'
fake_image both no no; run_image_check 1
check "release image whose key differs from the repo's -> FAIL" 'grep -q "^FAIL the keys in the image are exactly the project" <<<"${CI_OUT}"'
fake_image none no yes; run_image_check 0
check "a plain test build with no keys -> a note, not a failure" '! grep -q "^FAIL" <<<"${CI_OUT}" && grep -q "NOTE  this image has 0 update key" <<<"${CI_OUT}"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
