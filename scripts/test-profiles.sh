#!/bin/bash
# Test board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-profiles, in particular that each profile keeps its OWN RetroAchievements Web
# API key next to its username (a key only works with the account it belongs to).  The script runs inside a throw-away folder
# (OCTANE_USERDATA), with fake batocera-settings-set and batocera-save-overlay; no board, no /userdata.
# Usage: scripts/test-profiles.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPT="${REPO_ROOT}/board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-profiles"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
UD="${T}/ud"; FAKE="${T}/bin"; mkdir -p "${FAKE}"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

cat > "${FAKE}/batocera-settings-set" <<'EOF'
#!/bin/sh
f="${OCTANE_USERDATA}/system/batocera.conf"
grep -v "^${1}=" "${f}" > "${f}.new" 2>/dev/null; echo "${1}=${2}" >> "${f}.new"; mv "${f}.new" "${f}"
EOF
cat > "${FAKE}/batocera-save-overlay" <<'EOF'
#!/bin/sh
echo called >> "${OCTANE_USERDATA}/overlay.log"
EOF
chmod +x "${FAKE}"/*

prof() { OCTANE_USERDATA="${UD}" PATH="${FAKE}:${PATH}" bash "${SCRIPT}" "$@" >/dev/null 2>&1; }
conf() { grep "^${1}=" "${UD}/system/batocera.conf" 2>/dev/null | cut -d= -f2-; }                 # a global setting
pconf() { grep "^${2}=" "${UD}/profiles/${1}/retroachievements.conf" 2>/dev/null | cut -d= -f2-; }  # a field of a named profile
dconf() { grep "^${1}=" "${UD}/profiles/.default-retroachievements.conf" 2>/dev/null | cut -d= -f2-; }  # a field of the default profile
setg() { OCTANE_USERDATA="${UD}" PATH="${FAKE}:${PATH}" batocera-settings-set "$1" "$2"; }           # what EmulationStation does when the player edits
fresh() {
    rm -rf "${UD}"; mkdir -p "${UD}/system/configs/retroarch" "${UD}/profiles"
    cat > "${UD}/system/batocera.conf" <<'EOF'
global.retroachievements=1
global.retroachievements.username=alice
global.retroachievements.password=alicepw
global.retroachievements.token=tokalice
global.retroachievements.apikey=KEYALICE
EOF
}
# the key must always belong to the username it is used with
paired() { [ "$(conf global.retroachievements.username)" = "$1" ] && [ "$(conf global.retroachievements.apikey)" = "$2" ]; }

echo "== a new profile starts as a copy of the current account, key included"
fresh; prof create bob
check "create: the profile file has the account's key" '[ "$(pconf bob apikey)" = "KEYALICE" ] && [ "$(pconf bob username)" = "alice" ]'
check "create: token starts empty, as before" '[ -z "$(pconf bob token)" ]'

echo "== two accounts, switching back and forth: the key always follows the username"
prof switch bob
check "switch to bob: the default profile's file got alice's key" '[ "$(dconf apikey)" = "KEYALICE" ] && [ "$(dconf username)" = "alice" ]'
check "...and the global settings are bob's profile (cloned alice)" 'paired alice KEYALICE'
setg global.retroachievements.username bob; setg global.retroachievements.password bobpw; setg global.retroachievements.token tokbob; setg global.retroachievements.apikey KEYBOB
prof switch
check "switch to default: bob's file saved bob's key" '[ "$(pconf bob apikey)" = "KEYBOB" ] && [ "$(pconf bob username)" = "bob" ]'
check "...and the globals are alice with ALICE'S key (not bob's)" 'paired alice KEYALICE'
prof switch bob
check "switch to bob: the globals are bob with BOB'S key" 'paired bob KEYBOB'
prof switch; prof switch bob; prof switch
check "several round trips keep the pairs intact" 'paired alice KEYALICE && [ "$(pconf bob apikey)" = "KEYBOB" ]'

echo "== a profile without a key must not inherit the previous profile's key"
printf 'username=carol\npassword=x\ntoken=t\nra_enabled=1\n' > "${UD}/profiles/carol.tmp"; mkdir -p "${UD}/profiles/carol/saves" "${UD}/profiles/carol/states"; mv "${UD}/profiles/carol.tmp" "${UD}/profiles/carol/retroachievements.conf"
prof switch bob; prof switch carol
check "old-format profile (no apikey line): the global key is cleared" '[ "$(conf global.retroachievements.username)" = "carol" ] && [ -z "$(conf global.retroachievements.apikey)" ] && grep -q "^global.retroachievements.apikey=$" "${UD}/system/batocera.conf"'
check "...and bob still has his own key" '[ "$(pconf bob apikey)" = "KEYBOB" ]'
prof switch bob
check "back to bob: his key is restored" 'paired bob KEYBOB'

echo "== the rename screen must not lose the key (it uses this exact command on the file)"
C="${UD}/profiles/bob/retroachievements.conf"
grep -v '^display_name=' "${C}" > "${T}/ra_conf.tmp"; echo 'display_name=Bobby' >> "${T}/ra_conf.tmp"; mv "${T}/ra_conf.tmp" "${C}"
check "after renaming, the key and the display name are both in the file" '[ "$(pconf bob apikey)" = "KEYBOB" ] && [ "$(pconf bob display_name)" = "Bobby" ]'
prof switch; prof switch bob
check "after a save and a load the display name AND the key survive" '[ "$(pconf bob display_name)" = "Bobby" ] && [ "$(pconf bob apikey)" = "KEYBOB" ] && paired bob KEYBOB'

echo "== a key set before profiles existed is captured by the profile that was active"
fresh; mkdir -p "${UD}/profiles/dave/saves" "${UD}/profiles/dave/states"; printf 'username=alice\npassword=alicepw\ntoken=tokalice\nra_enabled=1\n' > "${UD}/profiles/dave/retroachievements.conf"; echo dave > "${UD}/system/.batocera-profiles.current"
prof switch
check "leaving the active profile writes the global key into its (old-format) file" '[ "$(pconf dave apikey)" = "KEYALICE" ]'

echo "== existing behaviour stays"
fresh; prof create bob; printf 'username=zed\npassword=z\nra_enabled=1\n' > "${UD}/profiles/bob/retroachievements.conf"; prof switch bob
check "a profile without a token still clears the token (unchanged)" '[ -z "$(conf global.retroachievements.token)" ] && [ "$(conf global.retroachievements.username)" = "zed" ]'
check "the RetroArch username line is set (unchanged)" 'grep -q "^cheevos_username = \"zed\"" "${UD}/system/configs/retroarch/retroarchcustom.cfg"'
check "the RetroArch config does NOT get the Web API key (RetroArch does not use it)" '! grep -qi "apikey\|KEYALICE" "${UD}/system/configs/retroarch/retroarchcustom.cfg"'
check "the overlay is saved after a switch (unchanged)" '[ -s "${UD}/overlay.log" ]'
fresh; mkdir -p "${UD}/saves"; echo data > "${UD}/saves/game.srm"; prof switch
check "old flat saves are still migrated into the default profile (inside the test folder only)" '[ -f "${UD}/profiles/.default/saves/game.srm" ] && [ ! -e "${UD}/saves" ]'

echo "== the script on the board still uses /userdata by default"
check "default path is /userdata unless OCTANE_USERDATA is set" 'grep -q "USERDATA=\"\${OCTANE_USERDATA:-/userdata}\"" "${SCRIPT}"'
check "no hard-coded /userdata path is left in the commands (comments aside)" '! grep -vE "^[[:space:]]*#" "${SCRIPT}" | grep -v "OCTANE_USERDATA:-/userdata" | grep -q "/userdata"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
