#!/bin/bash
# Test the "is a newer version available?" comparison in batocera-es-swissknife.
# The function is cut out of the real script, so this always tests the shipped code.
# Usage: scripts/test-update-version.sh        exit status 0 = all tests passed
set -u

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-es-swissknife"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT

awk '/^octane_update_available\(\)/ {p=1} p {print} p && /^}/ {exit}' "${SCRIPT}" > "${T}/fn.sh"
[ -s "${T}/fn.sh" ] || { echo "FAIL  octane_update_available not found in ${SCRIPT}"; exit 1; }
# shellcheck disable=SC1091
source "${T}/fn.sh"

PASS=0; FAIL=0
# t <installed> <latest> <expected: yes|no>
t() {
    local got=no
    octane_update_available "$1" "$2" && got=yes
    if [ "${got}" = "$3" ]; then PASS=$((PASS+1)); printf '  PASS  installed %-8s latest %-20s -> update? %s\n' "'$1'" "'$2'" "${got}"
    else FAIL=$((FAIL+1)); printf '  FAIL  installed %-8s latest %-20s -> update? %s (wanted %s)\n' "'$1'" "'$2'" "${got}" "$3"; fi
}

t 0.6.9   v0.6.9              no     # the reported bug: a "v" on the tag made every device see an update
t v0.6.9  0.6.9               no
t 0.6.8   v0.6.9              yes
t 0.6.9   v0.6.10             yes    # 10 is newer than 9 (a plain string compare gets this wrong)
t 0.6.10  v0.6.9              no     # never offer an older version
t 0.6.9   v0.6.8              no
t unknown v0.6.9              yes    # installed version unreadable: offer it, as before
t 0.6.9   "Connection failed!" no
t 0.6.9   ""                  no
t 0.6.9   "<html>rate limited" no
t 0.6.9   v0.7.0-beta1        yes

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
