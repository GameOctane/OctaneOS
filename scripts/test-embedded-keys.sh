#!/bin/bash
# Test scripts/check-embedded-keys.sh with fake keys files and fake binaries.  The fake "secret" values are canary strings: the tests also
# check that no output ever contains one.
# Usage: scripts/test-embedded-keys.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="${REPO_ROOT}/scripts/check-embedded-keys.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
SS='devid=CANARYSS&devpassword=CANARYSSPW'; RA='z=CANARYRA&y=CANARYRAKEY'
run() { OUTTXT="$("${CHK}" "$@" 2>&1)"; RC=$?; }
mkbin() { printf 'ELF....\0%s\0more....\0' "$@" > "${T}/es"; [ "$#" -eq 0 ] && printf 'ELF....\0nothing\0' > "${T}/es"; }

echo "== no keys file"
mkbin; run "${T}/nokeys.txt" "${T}/es"; check "no keys.txt -> fine" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "without developer logins"'
run "${T}/nokeys.txt" "${T}/es" --release; check "...also for a release" '[ "${RC}" = 0 ]'

echo "== a test image with both keys"
printf 'SCREENSCRAPER_DEV_LOGIN=%s\nCHEEVOS_DEV_LOGIN=%s\n' "${SS}" "${RA}" > "${T}/keys.txt"; mkbin "${SS}" "${RA}"
run "${T}/keys.txt" "${T}/es"
check "both compiled in, not a release -> fine, with notes" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "NOTE  CHEEVOS_DEV_LOGIN"'
check "output never contains a value" '! echo "${OUTTXT}" | grep -q "CANARY"'

echo "== a release"
run "${T}/keys.txt" "${T}/es" --release
check "RetroAchievements key compiled in -> a release FAILS, and it names the key" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "FAIL  CHEEVOS_DEV_LOGIN"'
check "...the ScreenScraper login alone does not fail it" 'echo "${OUTTXT}" | grep -q "NOTE  SCREENSCRAPER_DEV_LOGIN"'
check "output never contains a value (release failure too)" '! echo "${OUTTXT}" | grep -q "CANARY"'
OCTANE_ALLOW_SHARED_RA_KEY=1 run "${T}/keys.txt" "${T}/es" --release
check "OCTANE_ALLOW_SHARED_RA_KEY=1 lets it through, with a warning" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "anyone can read it"'
printf 'SCREENSCRAPER_DEV_LOGIN=%s\n' "${SS}" > "${T}/ss.txt"; mkbin "${SS}"; run "${T}/ss.txt" "${T}/es" --release
check "ScreenScraper login only -> a release passes" '[ "${RC}" = 0 ]'

echo "== stale build (keys.txt has a key the program does not contain)"
mkbin "${SS}"; run "${T}/keys.txt" "${T}/es"
check "RetroAchievements key in keys.txt but not in the binary -> FAIL (stale), also for a test image" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "stale build"'
check "output never contains a value (stale failure)" '! echo "${OUTTXT}" | grep -q "CANARY"'

echo "== other cases"
printf 'SCREENSCRAPER_DEV_LOGIN=\nCHEEVOS_DEV_LOGIN=\n' > "${T}/empty.txt"; mkbin; run "${T}/empty.txt" "${T}/es" --release
check "empty values are ignored" '[ "${RC}" = 0 ]'
run "${T}/keys.txt" "${T}/missing-binary"; check "missing binary -> exit 2" '[ "${RC}" = 2 ]'
run; check "no arguments -> exit 2" '[ "${RC}" = 2 ]'
run "${T}/keys.txt" "${T}/es" --bogus; check "unknown option -> exit 2" '[ "${RC}" = 2 ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
