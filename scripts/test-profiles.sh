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
check "create: a new profile does NOT inherit the current login" '[ -z "$(pconf bob username)" ] && [ -z "$(pconf bob password)" ] && [ -z "$(pconf bob apikey)" ] && [ -z "$(pconf bob token)" ]'
check "create: the new profile is named what was typed" '[ "$(pconf bob display_name)" = "bob" ]'
check "create: RetroAchievements stays on for the new profile" '[ "$(pconf bob ra_enabled)" = "1" ]'
echo "== switching to a profile with no login clears the previous player's login"
prof switch bob
check "switch to a new profile: the global username and password are cleared" '[ -z "$(conf global.retroachievements.username)" ] && [ -z "$(conf global.retroachievements.password)" ] && [ -z "$(conf global.retroachievements.apikey)" ]'
check "switch to a new profile: RetroArch no longer holds the old login" 'grep -q "^cheevos_username = \"\"" "${UD}/system/configs/retroarch/retroarchcustom.cfg" && grep -q "^cheevos_password = \"\"" "${UD}/system/configs/retroarch/retroarchcustom.cfg"'
check "the default profile got a friendly name and kept alice's login" '[ "$(dconf display_name)" = "Default" ] && [ "$(dconf username)" = "alice" ]'
prof switch ""
check "back to default: alice's login is restored" '[ "$(conf global.retroachievements.username)" = "alice" ] && [ "$(conf global.retroachievements.apikey)" = "KEYALICE" ]'

echo "== two accounts, switching back and forth: the key always follows the username"
prof switch bob
check "switch to bob: the default profile's file got alice's key" '[ "$(dconf apikey)" = "KEYALICE" ] && [ "$(dconf username)" = "alice" ]'
check "...and bob starts logged out (nothing is cloned from alice)" '[ -z "$(conf global.retroachievements.username)" ] && [ -z "$(conf global.retroachievements.apikey)" ]'
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

echo "== existing behavior stays"
fresh; prof create bob; printf 'username=zed\npassword=z\nra_enabled=1\n' > "${UD}/profiles/bob/retroachievements.conf"; prof switch bob
check "a profile without a token still clears the token (unchanged)" '[ -z "$(conf global.retroachievements.token)" ] && [ "$(conf global.retroachievements.username)" = "zed" ]'
check "the RetroArch username line is set (unchanged)" 'grep -q "^cheevos_username = \"zed\"" "${UD}/system/configs/retroarch/retroarchcustom.cfg"'
check "the RetroArch config does NOT get the Web API key (RetroArch does not use it)" '! grep -qi "apikey\|KEYALICE" "${UD}/system/configs/retroarch/retroarchcustom.cfg"'
check "the overlay is saved after a switch (unchanged)" '[ -s "${UD}/overlay.log" ]'
fresh; mkdir -p "${UD}/saves"; echo data > "${UD}/saves/game.srm"; prof switch
check "old flat saves are still migrated into the default profile (inside the test folder only)" '[ -f "${UD}/profiles/.default/saves/game.srm" ] && [ ! -e "${UD}/saves" ]'

echo "== the one-time move of the old flat saves/states into the default profile never risks the player's files"
proff() { OCTANE_USERDATA="${UD}" PATH="${FAKE}:${PATH}" bash "${SCRIPT}" "$@" 2>&1; }         # output and warnings kept
flat() { fresh; mkdir -p "${UD}/saves/gba" "${UD}/states"; echo SAVE1 > "${UD}/saves/gba/game.srm"; echo STATE1 > "${UD}/states/game.state"; }
echo '#!/bin/sh
exit 1' > "${FAKE}/cp"; chmod +x "${FAKE}/cp"
flat; OUT="$(proff switch)"
check "a failing copy: the original saves and states are untouched" '[ "$(cat "${UD}/saves/gba/game.srm")" = SAVE1 ] && [ "$(cat "${UD}/states/game.state")" = STATE1 ]'
check "...nothing is renamed or marked as done, and a warning is printed" '[ ! -e "${UD}/saves.migrated" ] && [ ! -e "${UD}/profiles/.flat-folders-migrated" ] && echo "${OUT}" | grep -q WARNING'
check "...and the switch itself still works" 'echo "${OUT}" | grep -q "Switched to profile"'
rm -f "${FAKE}/cp"
OUT="$(proff switch)"
check "the next switch retries and succeeds (the failure was not final)" '[ -f "${UD}/profiles/.default/saves/gba/game.srm" ] && [ -f "${UD}/profiles/.flat-folders-migrated" ]'
echo '#!/bin/sh
exit 0' > "${FAKE}/cp"; chmod +x "${FAKE}/cp"
flat; OUT="$(proff switch)"
check "a copy that reports success but copied nothing is caught: the original stays" '[ "$(cat "${UD}/saves/gba/game.srm")" = SAVE1 ] && [ ! -e "${UD}/saves.migrated" ] && echo "${OUT}" | grep -q WARNING'
rm -f "${FAKE}/cp"
flat; OUT="$(proff switch)"
check "success: the files are in the default profile" '[ "$(cat "${UD}/profiles/.default/saves/gba/game.srm")" = SAVE1 ] && [ "$(cat "${UD}/profiles/.default/states/game.state")" = STATE1 ]'
check "...the original is RENAMED, not deleted (the data exists twice)" '[ "$(cat "${UD}/saves.migrated/gba/game.srm")" = SAVE1 ] && [ "$(cat "${UD}/states.migrated/game.state")" = STATE1 ] && [ ! -e "${UD}/saves" ]'
check "...a marker file records that it is done" '[ -f "${UD}/profiles/.flat-folders-migrated" ]'
mkdir -p "${UD}/saves/amiga"; echo AMIGA1 > "${UD}/saves/amiga/disk.sav"
proff switch >/dev/null
check "once done, a folder an emulator recreates in /userdata/saves is never swept again" '[ "$(cat "${UD}/saves/amiga/disk.sav")" = AMIGA1 ] && [ ! -e "${UD}/profiles/.default/saves/amiga" ]'
flat; mkdir -p "${UD}/profiles/.default/saves/gba"; echo OTHER > "${UD}/profiles/.default/saves/gba/game.srm"; OUT="$(proff switch)"
check "a different file of the same name already in .default is never overwritten, and the original stays" '[ "$(cat "${UD}/profiles/.default/saves/gba/game.srm")" = OTHER ] && [ "$(cat "${UD}/saves/gba/game.srm")" = SAVE1 ] && echo "${OUT}" | grep -q WARNING'
flat; echo "" > "${UD}/system/.batocera-profiles.current"; mkdir -p "${UD}/system"; proff switch >/dev/null
check "a device that already used profiles (older script) is not swept: its /userdata/saves is left alone" '[ "$(cat "${UD}/saves/gba/game.srm")" = SAVE1 ] && [ -f "${UD}/profiles/.flat-folders-migrated" ] && [ ! -e "${UD}/saves.migrated" ]'
fresh; mkdir -p "${UD}/real" "${UD}/system"; echo KEEP > "${UD}/real/x"; ln -s "${UD}/real" "${UD}/saves"; proff switch >/dev/null
check "an old symlink is removed but what it pointed at is not" '[ ! -L "${UD}/saves" ] && [ "$(cat "${UD}/real/x")" = KEEP ]'
fresh; proff switch >/dev/null; echo X > "${UD}/saves.late" 2>/dev/null
check "a fresh card with nothing to move just gets the marker" '[ -f "${UD}/profiles/.flat-folders-migrated" ] && [ ! -e "${UD}/saves.migrated" ]'

echo "== the script on the board still uses /userdata by default"
check "default path is /userdata unless OCTANE_USERDATA is set" 'grep -q "USERDATA=\"\${OCTANE_USERDATA:-/userdata}\"" "${SCRIPT}"'
check "no hard-coded /userdata path is left in the commands (comments aside)" '! grep -vE "^[[:space:]]*#" "${SCRIPT}" | grep -v "OCTANE_USERDATA:-/userdata" | grep -q "/userdata"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
