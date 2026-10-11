#!/bin/bash
# Test the developer SSH key handling: scripts/install-dev-key.sh (build time) and the key block
# of S13octane-init (device boot).  Everything runs against throw-away folders.
# Usage: scripts/test-dev-key.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INSTALL="${REPO_ROOT}/scripts/install-dev-key.sh"
S13="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/etc/init.d/S13octane-init"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

echo "== build time: install-dev-key.sh"
mkdir -p "${T}/target"
echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItestkeyblob someone@laptop" > "${T}/good.pub"
"${INSTALL}" "${T}/good.pub" "${T}/target" > /dev/null 2>&1; RC=$?
check "a good key is installed, with its comment replaced by octaneos-dev" '[ "${RC}" = 0 ] && [ "$(cat ${T}/target/usr/share/octane/dev-ssh-key.pub)" = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAItestkeyblob octaneos-dev" ]'
check "the original comment is not copied" '! grep -q laptop ${T}/target/usr/share/octane/dev-ssh-key.pub'

mkdir -p "${T}/target2"
printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nb3BlbnNzaC1rZXktdjEAAAAA\n-----END OPENSSH PRIVATE KEY-----\n' > "${T}/private.key"
"${INSTALL}" "${T}/private.key" "${T}/target2" > /dev/null 2>&1; RC=$?
check "a PRIVATE key file is refused and nothing is written" '[ "${RC}" = 1 ] && [ ! -e ${T}/target2/usr/share/octane/dev-ssh-key.pub ]'
echo "ssh-ed25519 not*base64!" > "${T}/bad.pub"
"${INSTALL}" "${T}/bad.pub" "${T}/target2" > /dev/null 2>&1; RC=$?
check "a malformed key is refused" '[ "${RC}" = 1 ] && [ ! -e ${T}/target2/usr/share/octane/dev-ssh-key.pub ]'
"${INSTALL}" "${T}/does-not-exist.pub" "${T}/target2" > /dev/null 2>&1; RC=$?
check "a missing key file is refused" '[ "${RC}" = 1 ]'
"${INSTALL}" "${T}/good.pub" "${T}/no-such-folder" > /dev/null 2>&1; RC=$?
check "a missing target folder is refused" '[ "${RC}" = 1 ]'
"${INSTALL}" only-one-argument > /dev/null 2>&1; RC=$?
check "wrong number of arguments exits with status 2" '[ "${RC}" = 2 ]'

echo "== device boot: the key block of S13octane-init"
# cut out the block from the real script so the test always checks the real code
awk '/SSH_DIR=\/userdata\/system\/.ssh/ {p=1} p && /^    ;;/ {exit} p' "${S13}" > "${T}/block.sh"
check "the key block was found in S13octane-init" '[ -s ${T}/block.sh ] && grep -q DEV_KEY_FILE ${T}/block.sh'

DEVKEY="ssh-ed25519 AAAAdevkey octaneos-dev"
OLDDECK="ssh-ed25519 AAAAolddeckkey octaneos-dev"
OTHER="ssh-ed25519 AAAAother someone@laptop"
# scenario <name-dir> <dev-key-in-image: 1/0> <initial authorized_keys, printf format> <times to run>
scenario() {
    local d="${T}/dev-$1"; mkdir -p "${d}/ssh"
    [ "$2" = 1 ] && echo "${DEVKEY}" > "${d}/devkey"
    [ -n "$3" ] && printf "$3" > "${d}/ssh/authorized_keys"
    sed -e "s|SSH_DIR=/userdata/system/.ssh|SSH_DIR=${d}/ssh|" -e "s|DEV_KEY_FILE=/usr/share/octane/dev-ssh-key.pub|DEV_KEY_FILE=${d}/devkey|" "${T}/block.sh" > "${d}/run.sh"
    local i; for i in $(seq 1 "${4:-1}"); do sh "${d}/run.sh"; done
    AK="${d}/ssh/authorized_keys"
}
scenario a 1 "" 1
check "dev image, no authorized_keys yet: key installed with mode 600" '[ "$(cat ${AK})" = "${DEVKEY}" ] && [ "$(stat -c %a ${AK})" = 600 ]'
scenario b 1 "${OTHER}" 1
check "dev image, existing key without trailing newline: both keys, one per line" '[ "$(sed -n 1p ${AK})" = "${OTHER}" ] && [ "$(sed -n 2p ${AK})" = "${DEVKEY}" ]'
scenario c 1 "${OTHER}\\n" 3
check "dev image, run three times: still exactly one developer key" '[ "$(grep -c octaneos-dev ${AK})" = 1 ] && grep -qx "${OTHER}" ${AK}'
scenario d 1 "${OTHER}\\n${OLDDECK}\\n" 1
check "dev image replaces an OLDER developer key (the old committed one) and keeps others" '! grep -q AAAAolddeckkey ${AK} && grep -q AAAAdevkey ${AK} && grep -qx "${OTHER}" ${AK}'
scenario e 0 "${OTHER}\\n${DEVKEY}\\n" 1
check "normal image removes the developer key and keeps other keys" '! grep -q octaneos-dev ${AK} && grep -qx "${OTHER}" ${AK}'
scenario f 0 "${OTHER}\\n" 1
check "normal image with nothing to remove leaves the file as it was" '[ "$(cat ${AK})" = "${OTHER}" ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
