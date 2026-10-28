#!/bin/bash
# Test the one-time settings migrations in the device's init script (fsoverlay/etc/init.d/S13octane-init).
# The block is cut out of the real script, so the test always checks the real code, and it runs against
# throw-away folders; nothing here touches a device.
# Usage: scripts/test-migrations.sh        exit status 0 = all tests passed
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
S13="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/etc/init.d/S13octane-init"
T="$(mktemp -d)"
[ -n "${T}" ] && [ -d "${T}" ] || { echo "cannot create a temporary folder" >&2; exit 2; }
trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

echo "== migration ds-vsync-off"
awk '/# BEGIN migration ds-vsync-off/ {p=1} p {print} /# END migration ds-vsync-off/ {exit}' "${S13}" > "${T}/block.sh"
check "the migration block was found in S13octane-init" '[ -s "${T}/block.sh" ] && grep -q "MIGRATE_DIR=" "${T}/block.sh"'

# scenario <name> <initial batocera.conf (printf format; "-" = no file)> <times to run>
scenario() {
    local d="${T}/$1"; rm -rf "${d:?}"; mkdir -p "${d}"
    [ "$2" != "-" ] && printf "$2" > "${d}/batocera.conf"
    sed -e "s|MIGRATE_DIR=/userdata/system/.octane-migrations|MIGRATE_DIR=${d}/migrations|" "${T}/block.sh" > "${d}/run.sh"
    CONF="${d}/batocera.conf"; MARK="${d}/migrations/ds-vsync-off"; DIR="${d}"
    local i; for i in $(seq 1 "${3:-1}"); do BATOCERA_CONF="${CONF}" sh "${d}/run.sh"; RC=$?; done
}
lines() { grep -c "^nds.retroarch.video_vsync=" "${CONF}"; }

scenario existing 'wifi.enabled=1\nsystem.language=en_US\n' 1
check "an existing card without the line gets nds.retroarch.video_vsync=false" '[ "$(grep "^nds.retroarch.video_vsync=" "${CONF}")" = "nds.retroarch.video_vsync=false" ]'
check "...the marker file is written" '[ -e "${MARK}" ]'
check "...and every other line is untouched" '[ "$(head -n 2 "${CONF}" | tr "\n" "|")" = "wifi.enabled=1|system.language=en_US|" ] && [ "$(wc -l < "${CONF}")" = 3 ]'
scenario twice 'wifi.enabled=1\n' 3
check "run three times: still exactly one line" '[ "$(lines)" = 1 ]'
scenario fresh 'wifi.enabled=1\nnds.retroarch.video_vsync=false\n' 1
check "a fresh card (the default file already has the line): unchanged, still one line" '[ "$(lines)" = 1 ] && [ "$(wc -l < "${CONF}")" = 2 ]'
check "...and the marker is written, so a later change is respected" '[ -e "${MARK}" ]'
scenario usertrue 'nds.retroarch.video_vsync=true\nwifi.enabled=1\n' 1
check "a user who set it to true: left alone" '[ "$(grep "^nds.retroarch.video_vsync=" "${CONF}")" = "nds.retroarch.video_vsync=true" ] && [ "$(lines)" = 1 ]'
scenario deleted 'wifi.enabled=1\n' 1
sed -i '/^nds.retroarch.video_vsync=/d' "${CONF}"; BATOCERA_CONF="${CONF}" sh "${DIR}/run.sh"
check "after the migration ran, a user who deletes the line is NOT overridden again" '[ "$(lines)" = 0 ]'
scenario nofile - 1
check "no batocera.conf yet: nothing is created and no marker is written (the system creates the full file later)" '[ ! -e "${CONF}" ] && [ ! -e "${MARK}" ]'
printf 'wifi.enabled=1\n' > "${CONF}"; BATOCERA_CONF="${CONF}" sh "${DIR}/run.sh"
check "...and once the file exists, the next boot adds the line" '[ "$(lines)" = 1 ] && [ -e "${MARK}" ]'
scenario blocked 'wifi.enabled=1\n' 1
rm -rf "${DIR}/migrations"; : > "${DIR}/migrations"; rm -f "${CONF}"; printf 'wifi.enabled=1\n' > "${CONF}"
BATOCERA_CONF="${CONF}" sh "${DIR}/run.sh"; BATOCERA_CONF="${CONF}" sh "${DIR}/run.sh"
check "a marker folder that cannot be created: no crash and the line is not duplicated on the next boot" '[ "$(lines)" = 1 ]'
scenario bezel 'nds.bezel=none\nsnes.bezel=none\n' 1
check "a user's bezel choices are not touched" 'grep -qx "nds.bezel=none" "${CONF}" && grep -qx "snes.bezel=none" "${CONF}"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
