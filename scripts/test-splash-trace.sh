#!/bin/bash
# Test etc/init.d/S11splash-trace: off by default, on when asked, and it records a second video player.
# Runs the real script under dash, with a stand-in for batocera-settings-get and a fake mpv (sleep).
# Usage: scripts/test-splash-trace.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/etc/init.d/S11splash-trace"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT
command -v dash >/dev/null || { echo "dash is needed for this test" >&2; exit 2; }

PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

mkdir -p "${T}/bin"
cp /bin/sleep "${T}/bin/mpv"
# the script calls /usr/bin/batocera-settings-get by absolute path: point it at a stand-in
sed "s|/usr/bin/batocera-settings-get|${T}/bin/bsg|g" "${SCRIPT}" > "${T}/run.sh"
setting() { printf '#!/bin/sh\n[ "$1" = octane.splashtrace ] && echo "%s"\n' "$1" > "${T}/bin/bsg"; chmod +x "${T}/bin/bsg"; }

run() { # <seconds> ; env passed by the caller
    rm -f "${T}/t.log" "${T}/t.log.prev"
    OCTANE_SPLASHTRACE_LOG="${T}/t.log" OCTANE_SPLASHTRACE_SECONDS="$1" OCTANE_SPLASHTRACE_FG=1 dash "${T}/run.sh" start
}

echo "== off by default"
setting ""; run 2
check "setting absent: nothing is recorded" '[ ! -e ${T}/t.log ]'
setting 0; run 2
check "octane.splashtrace=0: nothing is recorded" '[ ! -e ${T}/t.log ]'
setting 1; OCTANE_SPLASHTRACE_FORCE=0 run 2
check "octane.splashtrace=1: it records" '[ -s ${T}/t.log ] && grep -q "splash trace started" ${T}/t.log'
setting ""; OCTANE_SPLASHTRACE_FORCE=1 run 2
check "the test override (FORCE=1) records without the setting" '[ -s ${T}/t.log ]'
setting 1; OCTANE_SPLASHTRACE_FORCE=0 dash "${T}/run.sh" stop; RC=$?
check "any action other than start does nothing and exits 0" '[ "${RC}" = 0 ]'

echo "== it records every video player"
setting 1
( sleep 1; "${T}/bin/mpv" 2 & sleep 4; "${T}/bin/mpv" 2 & wait ) &
OCTANE_SPLASHTRACE_FORCE=0 run 9; wait
check "two separate players show as two different process ids" '[ "$(grep -c "mpv pids: \[[0-9]" ${T}/t.log)" = 2 ] && [ "$(grep "mpv pids: \[[0-9]" ${T}/t.log | grep -o "\[[0-9]* \]" | sort -u | wc -l)" = 2 ]'
check "each new player gets its command line and parent recorded" '[ "$(grep -c "cmdline:" ${T}/t.log)" = 2 ] && [ "$(grep -c "ppid:" ${T}/t.log)" = 2 ]'

echo "== the previous boot is kept"
setting 1; OCTANE_SPLASHTRACE_FORCE=0 OCTANE_SPLASHTRACE_LOG="${T}/keep.log" OCTANE_SPLASHTRACE_SECONDS=1 OCTANE_SPLASHTRACE_FG=1 dash "${T}/run.sh" start
OCTANE_SPLASHTRACE_FORCE=0 OCTANE_SPLASHTRACE_LOG="${T}/keep.log" OCTANE_SPLASHTRACE_SECONDS=1 OCTANE_SPLASHTRACE_FG=1 dash "${T}/run.sh" start
check "the second run keeps the first as .prev" '[ -s ${T}/keep.log ] && [ -s ${T}/keep.log.prev ]'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
