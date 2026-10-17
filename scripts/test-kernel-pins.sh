#!/bin/bash
# Tests scripts/lib-pin.sh and scripts/check-kernel-pins.sh with throw-away local git repositories (no network).
# Usage: scripts/test-kernel-pins.sh        exit status 0 = all tests passed
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_SYSTEM=/dev/null
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
. "${REPO_ROOT}/scripts/lib-pin.sh"

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
g() { git -c protocol.file.allow=always "$@"; }

# a fake upstream with three commits on branch "main"; the pin will be the SECOND one
U="${T}/upstream"; mkdir -p "${U}"; g -C "${U}" init -q -b main
echo one > "${U}/f"; g -C "${U}" add f; g -C "${U}" commit -q -m one
echo two > "${U}/f"; g -C "${U}" commit -q -am two;   C2="$(g -C "${U}" rev-parse HEAD)"
echo three > "${U}/f"; g -C "${U}" commit -q -am three; C3="$(g -C "${U}" rev-parse HEAD)"
g -C "${U}" config uploadpack.allowAnySHA1InWant true
URL="file://${U}"

echo "== read_pin"
printf '# comment\n\nA=1\nB=two words\nURL=https://x/y\n' > "${T}/p"
check "reads a value"                         '[ "$(read_pin ${T}/p A)" = 1 ]'
check "keeps spaces inside a value"           '[ "$(read_pin ${T}/p B)" = "two words" ]'
check "missing key gives an empty string"     '[ -z "$(read_pin ${T}/p NOPE)" ]'
check "ignores comment lines"                 '[ -z "$(read_pin ${T}/p comment)" ]'

echo "== pin_checkout"
PIN_CHANGED=0; pin_checkout "${T}/fresh" "${URL}" main "${C2}" >/dev/null 2>&1; rc=$?
check "fresh checkout lands on the pinned commit although the branch moved on" '[ "${rc}" = 0 ] && [ "$(g -C ${T}/fresh rev-parse HEAD)" = "${C2}" ] && [ "${C2}" != "${C3}" ]'
check "a fresh checkout reports a change"     '[ "${PIN_CHANGED}" = 1 ]'
check "the file content is the pinned one"    '[ "$(cat ${T}/fresh/f)" = two ]'

PIN_CHANGED=0; mv "${U}" "${U}.gone"   # the server vanishes: an up-to-date checkout must not need it
pin_checkout "${T}/fresh" "${URL}" main "${C2}" >/dev/null 2>&1; rc=$?
mv "${U}.gone" "${U}"
check "already at the pin: nothing fetched, nothing changed" '[ "${rc}" = 0 ] && [ "${PIN_CHANGED}" = 0 ]'

# an existing clone sitting at the branch tip is moved back to the pin, discarding local edits
g clone -q --depth=1 -b main "${URL}" "${T}/tip" 2>/dev/null; echo local > "${T}/tip/f"
PIN_CHANGED=0; pin_checkout "${T}/tip" "${URL}" main "${C2}" >/dev/null 2>&1; rc=$?
check "an existing clone at the tip is moved to the pin" '[ "${rc}" = 0 ] && [ "$(g -C ${T}/tip rev-parse HEAD)" = "${C2}" ] && [ "$(cat ${T}/tip/f)" = two ] && [ "${PIN_CHANGED}" = 1 ]'

# a server that refuses to hand out a commit by hash: fall back to fetching the branch
g -C "${U}" config uploadpack.allowAnySHA1InWant false; g -C "${U}" config uploadpack.allowReachableSHA1InWant false
PIN_CHANGED=0; pin_checkout "${T}/fallback" "${URL}" main "${C2}" >/dev/null 2>&1; rc=$?
check "server refuses fetch-by-hash: falls back to the branch and still pins" '[ "${rc}" = 0 ] && [ "$(g -C ${T}/fallback rev-parse HEAD)" = "${C2}" ]'

echo "== bad input"
out1="$(pin_checkout "${T}/x1" "${URL}" main "main" 2>&1)"; rc1=$?
check "a branch name instead of a hash is refused by the validator itself (message, and nothing created)" '[ "${rc1}" != 0 ] && echo "${out1}" | grep -q "40-character" && [ ! -d ${T}/x1 ]'
out2="$(pin_checkout "${T}/x2" "${URL}" main "${C2:0:12}" 2>&1)"; rc2=$?
check "a short hash is refused by the validator itself (message, and nothing created)" '[ "${rc2}" != 0 ] && echo "${out2}" | grep -q "40-character" && [ ! -d ${T}/x2 ]'
out3="$(pin_checkout "${T}/x4" "${URL}" main "${C2^^}" 2>&1)"; rc3=$?
check "an upper-case hash is refused (pins are lower-case)" '[ "${rc3}" != 0 ] && [ ! -d ${T}/x4 ]'
pin_checkout "${T}/x3" "${URL}" main "$(printf 'a%.0s' $(seq 40))" >/dev/null 2>&1; rc=$?
check "a commit that does not exist is refused"           '[ "${rc}" != 0 ]'
check "a refused pin leaves no checkout at a wrong commit" '[ ! -f ${T}/x3/f ]'

echo "== check-kernel-pins.sh"
cat > "${T}/good.pin" <<EOF
KERNEL_REPO=https://example.org/k
KERNEL_BRANCH=b
KERNEL_COMMIT=${C2}
BSP_REPO=https://example.org/bsp
BSP_BRANCH=b2
BSP_COMMIT=${C3}
EOF
mkdir -p "${T}/nokernel"
check "a valid pin file passes (no clones present)"   '"${REPO_ROOT}/scripts/check-kernel-pins.sh" --pin-file ${T}/good.pin --kernel-dir ${T}/nokernel >/dev/null'
sed 's/^KERNEL_COMMIT=.*/KERNEL_COMMIT=abc123/' "${T}/good.pin" > "${T}/short.pin"
check "a short commit in the pin file fails"          '! "${REPO_ROOT}/scripts/check-kernel-pins.sh" --pin-file ${T}/short.pin --kernel-dir ${T}/nokernel >/dev/null'
sed 's#^BSP_REPO=.*#BSP_REPO=http://example.org/bsp#' "${T}/good.pin" > "${T}/http.pin"
check "a plain http repository URL fails"             '! "${REPO_ROOT}/scripts/check-kernel-pins.sh" --pin-file ${T}/http.pin --kernel-dir ${T}/nokernel >/dev/null'
grep -v '^BSP_BRANCH' "${T}/good.pin" > "${T}/missing.pin"
check "a missing key fails"                           '! "${REPO_ROOT}/scripts/check-kernel-pins.sh" --pin-file ${T}/missing.pin --kernel-dir ${T}/nokernel >/dev/null'
# a clone at the wrong commit is caught
sed "s/^KERNEL_COMMIT=.*/KERNEL_COMMIT=${C3}/" "${T}/good.pin" > "${T}/mismatch.pin"
check "a clone at a different commit than the pin fails" '! "${REPO_ROOT}/scripts/check-kernel-pins.sh" --pin-file ${T}/mismatch.pin --kernel-dir ${T}/fresh >/dev/null'
check "the real pin file in the repo is valid"        '"${REPO_ROOT}/scripts/check-kernel-pins.sh" --kernel-dir ${T}/nokernel >/dev/null'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
