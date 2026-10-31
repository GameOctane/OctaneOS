#!/bin/bash
# Test scripts/apply-es-patches.sh on small throw-away source folders (no build, no board), and that the real patch in
# board/batocera/allwinner/a733/es-patches/ still applies to the real EmulationStation source when that source is available.
# Usage: scripts/test-es-patches.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APPLY="${REPO_ROOT}/scripts/apply-es-patches.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }

new_src() { rm -rf "${T}/src" "${T}/p"; mkdir -p "${T}/src" "${T}/p"; printf 'one\ntwo\nthree\n' > "${T}/src/a.txt"; printf 'alpha\nbeta\n' > "${T}/src/b.txt"; }
# a patch that inserts a line after "two" in a.txt, one that changes beta in b.txt
mkpatch() {  # name file old new  (builds the patch with diff)
    local n="$1" f="$2" old="$3" new="$4"; mkdir -p "${T}/w/a" "${T}/w/b"; cp "${T}/src/${f}" "${T}/w/a/${f}"; sed "s/${old}/${new}/" "${T}/src/${f}" > "${T}/w/b/${f}"
    (cd "${T}/w" && diff -u "a/${f}" "b/${f}" > "${T}/p/${n}.patch"); rm -rf "${T}/w"
}
run() { OUTTXT="$("${APPLY}" "$@" 2>&1)"; RC=$?; }

echo "== applying"
new_src; mkpatch 0001-a a.txt two "two\nTWO-ADDED"; mkpatch 0002-b b.txt beta BETA
run "${T}/src" "${T}/p"
check "applies both patches, in order" '[ "${RC}" = 0 ] && grep -q "^TWO-ADDED" "${T}/src/a.txt" && grep -q "^BETA" "${T}/src/b.txt" && echo "${OUTTXT}" | grep -c "applied:" | grep -q "^2$"'
cp "${T}/src/a.txt" "${T}/a.once"; run "${T}/src" "${T}/p"
check "running it again changes nothing and says 'already applied'" '[ "${RC}" = 0 ] && cmp -s "${T}/src/a.txt" "${T}/a.once" && echo "${OUTTXT}" | grep -c "already applied" | grep -q "^2$"'
new_src; mkpatch 0001-a a.txt two "two\nTWO-ADDED"; cp "${T}/src/a.txt" "${T}/a.orig"; sed -i 's/three/THREE-CHANGED-UPSTREAM/; s/two/TWO-RENAMED/' "${T}/src/a.txt"; cp "${T}/src/a.txt" "${T}/a.changed"
run "${T}/src" "${T}/p"
check "a patch that no longer applies -> exit 1, a clear message, the file untouched" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "does not apply" && cmp -s "${T}/src/a.txt" "${T}/a.changed"'
new_src; mkpatch 0001-a a.txt two "two\nTWO-ADDED"; printf 'bad\n' > "${T}/p/0002-bad.patch"; run "${T}/src" "${T}/p"
check "a later broken patch stops the run (exit 1) after the good one was applied" '[ "${RC}" = 1 ] && grep -q "^TWO-ADDED" "${T}/src/a.txt"'
new_src; run "${T}/src" "${T}/p"
check "an empty patch folder is fine and says so" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "no patches"'
run
check "no arguments -> exit 2" '[ "${RC}" = 2 ]'
run "${T}/nowhere" "${T}/p"
check "a source folder that does not exist -> exit 2 (not a pass)" '[ "${RC}" = 2 ]'

echo "== wired into the build and the image checks"
check "build.sh applies the patches before using the ES source, and stops on failure" 'grep -q "apply-es-patches.sh\" \"\${ES_SRCDIR}\" || exit 1" "${REPO_ROOT}/scripts/build.sh"'
check "check-image.sh checks that the built EmulationStation knows the key setting" 'grep -q "global.retroachievements.apikey" "${REPO_ROOT}/scripts/check-image.sh"'
check "the patch folder contains the RetroAchievements patch" '[ -s "${REPO_ROOT}/board/batocera/allwinner/a733/es-patches/0001-retroachievements-per-player-web-api-key.patch" ]'

echo "== the real patch against the real EmulationStation source (skipped when the source is not on this machine)"
ES="${REPO_ROOT}/batocera/dl/batocera-emulationstation/git"
if [ -d "${ES}/es-app/src" ]; then
    P="${REPO_ROOT}/board/batocera/allwinner/a733/es-patches/0001-retroachievements-per-player-web-api-key.patch"
    check "applies to the real source, or is already applied (check only, nothing is changed)" '(cd "${ES}" && { git apply --check "${P}" || git apply --check -R "${P}"; }) >/dev/null 2>&1'
else
    printf '  SKIP  the EmulationStation source is not at %s\n' "${ES}"
fi

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
