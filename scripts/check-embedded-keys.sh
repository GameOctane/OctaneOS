#!/bin/bash
# Check which developer logins/keys are compiled into the built EmulationStation, against what keys.txt asks for.
# keys.txt (batocera/package/batocera/emulationstation/batocera-emulationstation/keys.txt, gitignored) is read by the package recipe at build
# time; whatever it holds is compiled into the program, where anyone can read it back with a text search.
#
# Policy (docs/retroachievements.md):
#   - SCREENSCRAPER_DEV_LOGIN: meant to be embedded in software; allowed in a release.
#   - CHEEVOS_DEV_LOGIN (the project's RetroAchievements Web API key, an account credential): test images only.  A release fails unless
#     OCTANE_ALLOW_SHARED_RA_KEY=1 is set on purpose (decide that only after RetroAchievements has said a shared key is acceptable).
#   - GAMESDB_APIKEY, HFS_DEV_LOGIN: not used by OctaneOS; reported if present.
#   - A key that keys.txt holds but the built program does not contain means a stale build (rebuild EmulationStation).
# Only key NAMES are ever printed, never values, and values are never put on a command line.
#
# Usage: scripts/check-embedded-keys.sh KEYS_FILE EMULATIONSTATION_BINARY [--release]
# Exit status: 0 = fine, 1 = a problem, 2 = bad arguments.   A missing keys file is fine (the build then has no developer logins).
set -uo pipefail
KEYS="${1:-}"; BIN="${2:-}"; RELEASE=0
[ "${3:-}" = "--release" ] && RELEASE=1
{ [ -n "${KEYS}" ] && [ -n "${BIN}" ] && { [ -z "${3:-}" ] || [ "${3}" = "--release" ]; }; } || { echo "usage: check-embedded-keys.sh KEYS_FILE BINARY [--release]" >&2; exit 2; }
[ -f "${BIN}" ] || { echo "ERROR: ${BIN} not found" >&2; exit 2; }
fail=0
pass() { printf '  PASS  %s\n' "$1"; }
bad()  { printf '  FAIL  %s\n' "$1"; fail=1; }
note() { printf '  NOTE  %s\n' "$1"; }

if [ ! -f "${KEYS}" ]; then
    pass "no keys.txt: EmulationStation was built without developer logins (players use their own accounts and keys)"
    exit 0
fi
value_of() { grep -E "^${1}=" "${KEYS}" | head -1 | cut -d= -f2-; }
in_binary() { grep -aqF -f <(printf '%s\n' "$1") "${BIN}"; }   # value passed through a pipe, not through a command line

for name in SCREENSCRAPER_DEV_LOGIN CHEEVOS_DEV_LOGIN GAMESDB_APIKEY HFS_DEV_LOGIN; do
    v="$(value_of "${name}")"
    if [ -z "${v}" ]; then continue; fi
    if ! in_binary "${v}"; then
        bad "${name} is in keys.txt but not in the built EmulationStation: stale build, rebuild batocera-emulationstation"
        continue
    fi
    case "${name}" in
        SCREENSCRAPER_DEV_LOGIN)
            note "${name} is compiled in (allowed in a release: it identifies the program, players still use their own account)" ;;
        CHEEVOS_DEV_LOGIN)
            if [ "${RELEASE}" -eq 1 ] && [ "${OCTANE_ALLOW_SHARED_RA_KEY:-0}" != 1 ]; then
                bad "${name} (the project's RetroAchievements account key) is compiled in: test images only. Remove it from keys.txt and rebuild, or set OCTANE_ALLOW_SHARED_RA_KEY=1 if you decided to ship it"
            elif [ "${RELEASE}" -eq 1 ]; then
                note "${name} is compiled in and OCTANE_ALLOW_SHARED_RA_KEY=1 is set: anyone can read it out of this image"
            else
                note "${name} is compiled in; fine for testing, not for a release"
            fi ;;
        *)  note "${name} is compiled in (OctaneOS does not use it)" ;;
    esac
done
[ "${fail}" -eq 0 ] && pass "developer logins compiled into EmulationStation match keys.txt and the release policy"
exit "${fail}"
