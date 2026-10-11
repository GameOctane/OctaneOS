#!/bin/bash
# Test scripts/prune-stale-overlay-files.sh in a throw-away folder.
# Usage: scripts/test-prune-overlay.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PRUNE="${REPO_ROOT}/scripts/prune-stale-overlay-files.sh"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

mkdir -p "${T}/ov1/usr/bin" "${T}/ov2/usr/share/labwc" "${T}/target/usr/bin" "${T}/target/usr/share/labwc"
echo a > "${T}/ov1/usr/bin/keep-me";          cp "${T}/ov1/usr/bin/keep-me" "${T}/target/usr/bin/keep-me"
echo b > "${T}/ov1/usr/bin/override-pkg-file"; cp "${T}/ov1/usr/bin/override-pkg-file" "${T}/target/usr/bin/override-pkg-file"
echo c > "${T}/ov2/usr/share/labwc/stale-hook"; cp "${T}/ov2/usr/share/labwc/stale-hook" "${T}/target/usr/share/labwc/stale-hook"
echo "somepkg,./usr/bin/override-pkg-file" > "${T}/pkglist"
echo "otherpkg,./usr/bin/something-else"  >> "${T}/pkglist"
MAN="${T}/manifest"

echo "== first run"
OUT=$("${PRUNE}" "${T}/target" "${T}/pkglist" "${MAN}" "${T}/ov1" "${T}/ov2" 2>&1)
check "first run records the overlay and deletes nothing" '[ -f "${MAN}" ] && echo "${OUT}" | grep -q "first run" && [ -f "${T}/target/usr/share/labwc/stale-hook" ]'
check "manifest lists all three overlay files" '[ "$(wc -l < ${MAN})" = 3 ]'

echo "== nothing changed"
OUT=$("${PRUNE}" "${T}/target" "${T}/pkglist" "${MAN}" "${T}/ov1" "${T}/ov2" 2>&1)
check "second run with an unchanged overlay removes nothing" 'echo "${OUT}" | grep -q "0 stale file(s) removed, 0 need" && [ -f "${T}/target/usr/share/labwc/stale-hook" ]'

echo "== two files removed from the overlay"
rm -f "${T}/ov2/usr/share/labwc/stale-hook" "${T}/ov1/usr/bin/override-pkg-file"
OUT=$("${PRUNE}" "${T}/target" "${T}/pkglist" "${MAN}" "${T}/ov1" "${T}/ov2" 2>&1)
check "a file only our overlay provided is removed from target" '[ ! -e "${T}/target/usr/share/labwc/stale-hook" ] && echo "${OUT}" | grep -q "removed stale file from target: ./usr/share/labwc/stale-hook"'
check "a file a package also installs is NOT deleted, and a warning names the package" '[ -f "${T}/target/usr/bin/override-pkg-file" ] && echo "${OUT}" | grep -q "package .somepkg. also installs it"'
check "a file still in the overlay is untouched" '[ -f "${T}/target/usr/bin/keep-me" ]'
check "summary counts are right" 'echo "${OUT}" | grep -q "1 stale file(s) removed, 1 need a package reinstall"'
check "manifest now matches the overlay" '[ "$(wc -l < ${MAN})" = 1 ]'

echo "== already gone from target"
echo "./usr/never-existed" >> "${MAN}"
OUT=$("${PRUNE}" "${T}/target" "${T}/pkglist" "${MAN}" "${T}/ov1" "${T}/ov2" 2>&1); RC=$?
check "a removed file that is not in target is not an error" '[ "${RC}" = 0 ]'

echo "== safety"
printf '../escape\n/etc/passwd\n./ok/../../escape\n' >> "${MAN}"
echo precious > "${T}/escape"
OUT=$("${PRUNE}" "${T}/target" "${T}/pkglist" "${MAN}" "${T}/ov1" "${T}/ov2" 2>&1); RC=$?
check "path-escaping manifest entries are ignored" '[ "${RC}" = 0 ] && [ "$(cat ${T}/escape)" = precious ]'
check "bad arguments exit with status 2" '"${PRUNE}" only two args >/dev/null 2>&1; [ $? = 2 ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
