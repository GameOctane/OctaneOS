#!/bin/bash
# Test scripts/check-repo-hygiene.sh in throw-away git repositories.  The fake secrets are canary strings; the tests also check that no output ever contains one.
# Usage: scripts/test-repo-hygiene.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="${REPO_ROOT}/scripts/check-repo-hygiene.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
fresh() { rm -rf "${T}/r"; mkdir -p "${T}/r/keys/update" "${T}/r/docs" "${T}/r/scripts"; git -C "${T}/r" init -q
    echo "public" > "${T}/r/keys/update/primary.pub.pem"; echo "readme" > "${T}/r/keys/update/README.md"
    echo 'SCREENSCRAPER_DEV_LOGIN=devid=<id>&devpassword=<password>' > "${T}/r/docs/x.md"; }
run() { git -C "${T}/r" add -A; OUT="$("${CHK}" "${T}/r" 2>&1)"; RC=$?; }

echo "== a clean repository"
fresh; run; check "public keys, placeholders only -> OK" '[ "${RC}" = 0 ]'

echo "== things that must fail"
fresh; echo x > "${T}/r/keys.txt"; run; check "tracked keys.txt" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "keys.txt"'
fresh; echo x > "${T}/r/keys/update/primary.key.pem"; run; check "a private key file in keys/update" '[ "${RC}" != 0 ]'
fresh; echo x > "${T}/r/keys/update/extra.txt"; run; check "any other file in keys/update" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "extra.txt"'
fresh; printf -- '-----BEGIN PRIVATE KEY-----\nCANARYKEYBODY\n-----END PRIVATE KEY-----\n' > "${T}/r/docs/notes.md"; run
check "a private key block in a doc" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "docs/notes.md"'
check "...and the key text is never printed" '! echo "${OUT}" | grep -q "CANARY"'
fresh; printf -- '-----BEGIN OPENSSH PRIVATE KEY-----\nx\n' > "${T}/r/id_ed25519"; run; check "an ssh private key file" '[ "${RC}" != 0 ]'
fresh; echo 'SCREENSCRAPER_DEV_LOGIN=devid=abc&devpassword=CANARYPW123' > "${T}/r/docs/y.md"; run
check "a real-looking developer password" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "docs/y.md"'
check "...and the password is never printed" '! echo "${OUT}" | grep -q "CANARY"'

echo "== things that must stay allowed"
fresh; printf -- '-----BEGIN PRIVATE KEY-----\nfake\n' > "${T}/r/scripts/test-thing.sh"; echo 'devpassword=CANARYPW123' >> "${T}/r/scripts/test-thing.sh"; run
check "fake keys and canaries inside scripts/test-*.sh" '[ "${RC}" = 0 ]'
fresh; echo x > "${T}/r/keys/update/backup.pub.pem"; run; check "a second public key" '[ "${RC}" = 0 ]'

echo "== the real repository"
check "this repository passes" '"${CHK}" "${REPO_ROOT}" >/dev/null 2>&1'

echo; echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
