#!/bin/bash
# Test scripts/audit-default-emulators.py and scripts/fix-default-emulators.py on small synthetic image folders (no build, no board).
# Usage: scripts/test-default-emulators.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AUDIT="${REPO_ROOT}/scripts/audit-default-emulators.py"
FIX="${REPO_ROOT}/scripts/fix-default-emulators.py"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

# a tiny image: three systems; gamecube offers only libretro/dolphin (like ours), nes offers libretro/fceumm, wii like gamecube
new_image() {  # dir
    local d="$1"; rm -rf "${d}"; mkdir -p "${d}/usr/share/emulationstation" "${d}/usr/share/batocera/configgen"
    cat > "${d}/usr/share/emulationstation/es_systems.cfg" <<'XML'
<systemList>
  <system><name>nes</name><emulators>
    <emulator name="libretro"><cores><core default="true">fceumm</core><core>mesen</core></cores></emulator>
  </emulators></system>
  <system><name>gamecube</name><emulators>
    <emulator name="libretro"><cores><core default="true">dolphin</core></cores></emulator>
  </emulators></system>
  <system><name>wii</name><emulators>
    <emulator name="libretro"><cores><core default="true">dolphin</core></cores></emulator>
  </emulators></system>
</systemList>
XML
    cat > "${d}/usr/share/batocera/configgen/configgen-defaults.yml" <<'YML'
nes:
  emulator: libretro
  core:     fceumm
gamecube:
  emulator: dolphin
  core:     dolphin
wii:
  emulator: dolphin
  core:     dolphin
YML
    printf 'nds:\n  emulator: libretro\n  core:     melonds\n' > "${d}/usr/share/batocera/configgen/configgen-defaults-arch.yml"
}
audit() { OUTTXT="$(python3 -I "${AUDIT}" "$@" 2>&1)"; RC=$?; }

echo "== the audit"
I="${T}/img"; new_image "${I}"
audit "${I}"
check "dolphin missing as a default emulator -> exit 1, and gamecube and wii are named" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "PROBLEM  gamecube" && echo "${OUTTXT}" | grep -q "PROBLEM  wii"'
check "...while nes (fine) is not named" '! echo "${OUTTXT}" | grep -q "nes "'
python3 -I "${FIX}" "${I}" >/dev/null; audit "${I}"
check "after the fix: exit 0" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "exists in the image"'

new_image "${I}"; sed -i 's/core:     fceumm/core:     nosuchcore/' "${I}/usr/share/batocera/configgen/configgen-defaults.yml"; python3 -I "${FIX}" "${I}" >/dev/null; audit "${I}"
check "a default core the image does not offer -> exit 1" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "default core .nosuchcore. is not offered"'

new_image "${I}"; printf 'gamecube:\n  emulator: libretro\n  core:     dolphin\nwii:\n  emulator: libretro\n  core:     dolphin\nnes:\n  emulator: libretro\n  core:     fceumm\n' > "${I}/usr/share/batocera/configgen/configgen-defaults-arch.yml"; audit "${I}"
check "the board file overrides the generic file (generic says dolphin, board says libretro) -> exit 0" '[ "${RC}" = 0 ]'

new_image "${I}"; printf 'gamecube  # known\n' > "${T}/accepted.txt"; audit "${I}" --accepted "${T}/accepted.txt"
check "an accepted problem is listed as ACCEPTED and does not fail it... but a NEW one (wii) still fails" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "ACCEPTED gamecube" && echo "${OUTTXT}" | grep -q "PROBLEM  wii"'
printf '# comment\ngamecube  # a\nwii  # b\nnes  # stale\n' > "${T}/accepted.txt"; audit "${I}" --accepted "${T}/accepted.txt"
check "everything accepted -> exit 0" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "apart from 2 accepted"'
check "an accepted system with no problem is reported as stale" 'echo "${OUTTXT}" | grep -q "note: .nes. is in the accepted list but has no problem"'

audit "${T}/nothing-here"
check "a folder without the files -> exit 2 (not a pass)" '[ "${RC}" = 2 ]'

new_image "${I}"; python3 -I "${FIX}" "${I}" >/dev/null; mkdir -p "${I}/usr/lib/libretro"; : > "${I}/usr/lib/libretro/fceumm_libretro.so"; audit "${I}"
check "cores visible and the default core's library is missing (dolphin) -> exit 1" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "has no library"'
: > "${I}/usr/lib/libretro/dolphin_libretro.so"; audit "${I}"
check "...present -> exit 0" '[ "${RC}" = 0 ]'
new_image "${I}"; python3 -I "${FIX}" "${I}" >/dev/null; audit "${I}"
check "no cores visible at all -> the library check is skipped, with a note" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "core-library check was skipped"'

echo "== the fix"
new_image "${I}"; A="${I}/usr/share/batocera/configgen/configgen-defaults-arch.yml"
OUTTXT="$(python3 -I "${FIX}" "${I}" 2>&1)"; RC=$?
check "sets gamecube and wii to libretro/dolphin" '[ "${RC}" = 0 ] && python3 -I -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert d[\"gamecube\"]==d[\"wii\"]=={\"emulator\":\"libretro\",\"core\":\"dolphin\"}" "${A}"'
check "keeps the entries that were already in the board file (nds)" 'python3 -I -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert d[\"nds\"][\"core\"]==\"melonds\"" "${A}"'
cp "${A}" "${T}/once.yml"; python3 -I "${FIX}" "${I}" >/dev/null
check "running it twice changes nothing and says so" 'cmp -s "${A}" "${T}/once.yml" && python3 -I "${FIX}" "${I}" | grep -q "already set"'
new_image "${I}"; printf 'nds:\n  emulator: libretro\n  core:     melonds\ngamecube:\n  emulator: dolphin\n  core:     dolphin\nwii:\n  emulator: dolphin\n  core:     dolphin\n' > "${A}"; python3 -I "${FIX}" "${I}" >/dev/null
check "replaces a wrong existing entry; exactly one gamecube block remains" '[ "$(grep -c "^gamecube:" "${A}")" = 1 ] && [ "$(grep -c "^wii:" "${A}")" = 1 ] && python3 -I -c "import yaml,sys; d=yaml.safe_load(open(sys.argv[1])); assert d[\"gamecube\"][\"emulator\"]==\"libretro\" and d[\"nds\"][\"core\"]==\"melonds\"" "${A}"'
rm -f "${A}"; python3 -I "${FIX}" "${I}" >/dev/null 2>&1; RC=$?
check "no board defaults file -> exit 1 (the build must stop and be looked at)" '[ "${RC}" = 1 ]'
python3 -I "${FIX}" >/dev/null 2>&1; RC=$?
check "no arguments -> exit 2" '[ "${RC}" = 2 ]'

echo "== wired into the image checks (the fix itself is deliberately NOT in the build, see docs/a733-gotchas.md item 21)"
check "check-image.sh runs the audit with the accepted list" 'grep -q "audit-default-emulators.py" "${REPO_ROOT}/scripts/check-image.sh" && grep -q "default-emulators-accepted.txt" "${REPO_ROOT}/scripts/check-image.sh"'
check "the accepted list names gamecube and wii, with a reason" 'grep -qE "^gamecube +#.+" "${REPO_ROOT}/scripts/default-emulators-accepted.txt" && grep -qE "^wii +#.+" "${REPO_ROOT}/scripts/default-emulators-accepted.txt"'
check "every accepted entry has a reason (a # comment)" '! grep -vE "^[[:space:]]*(#|$)" "${REPO_ROOT}/scripts/default-emulators-accepted.txt" | grep -qvE "#"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
