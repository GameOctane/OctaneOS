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
# two patches that touch NEIGHBOURING lines (the second was made on top of the first): a second run must still say "already applied"
new_src; printf 'one\ntwo\nthree\nfour\nfive\nsix\n' > "${T}/src/a.txt"; mkpatch 0001-a a.txt three "three\nX-FIRST"
cp "${T}/src/a.txt" "${T}/a.base"; run "${T}/src" "${T}/p"; mkpatch 0002-a a.txt X-FIRST "X-FIRST\nY-SECOND"; cp "${T}/a.base" "${T}/src/a.txt"; run "${T}/src" "${T}/p"
cp "${T}/src/a.txt" "${T}/a.both"; run "${T}/src" "${T}/p"
check "two patches on neighbouring lines: a second run changes nothing and reports 'already applied' for both" '[ "${RC}" = 0 ] && cmp -s "${T}/src/a.txt" "${T}/a.both" && grep -q "^X-FIRST" "${T}/src/a.txt" && grep -q "^Y-SECOND" "${T}/src/a.txt" && [ "$(echo "${OUTTXT}" | grep -c "already applied")" = 2 ]'
# Layered patches in a source that is a git repository (like the real ES source): the second patch REWRITES lines the first one added, so the
# first patch's own reverse can no longer be tested alone, not even with fuzz.  The run must still recognise both as applied (this broke the build).
gitsrc() { new_src; printf 'one\ntwo\nthree\nfour\nfive\n' > "${T}/src/a.txt"; (cd "${T}/src" && git init -q && git add -A && git -c user.name=t -c user.email=t@t commit -q -m base); }
gitsrc; mkpatch 0001-a a.txt three "three\nX-FIRST"
run "${T}/src" "${T}/p"; mkpatch 0002-a a.txt "X-FIRST" "Y-REWRITTEN"      # the second patch changes the very line the first one added
(cd "${T}/src" && git checkout -q -- a.txt); run "${T}/src" "${T}/p"      # start again from the base with both patches in the folder
cp "${T}/src/a.txt" "${T}/a.layered"; run "${T}/src" "${T}/p"
check "git source, layered patches that rewrite each other: a second run changes nothing and says 'already applied' for both" '[ "${RC}" = 0 ] && cmp -s "${T}/src/a.txt" "${T}/a.layered" && [ "$(echo "${OUTTXT}" | grep -c "already applied")" = 2 ]'
gitsrc; mkpatch 0001-a a.txt three "three\nX-FIRST"; run "${T}/src" "${T}/p"; mkpatch 0002-b b.txt beta BETA
run "${T}/src" "${T}/p"
check "git source: the first patch is in, a new second patch is applied (partial state)" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "already applied: 0001" && echo "${OUTTXT}" | grep -q "applied: 0002" && grep -q "^BETA" "${T}/src/b.txt"'
gitsrc; cp "${T}/src/a.txt" "${T}/a.base2"; mkpatch 0001-a a.txt three "three\nX-FIRST"; run "${T}/src" "${T}/p"; cp "${T}/src/a.txt" "${T}/a.applied2"
cp "${T}/a.base2" "${T}/src/a.txt"; mkpatch 0001-a a.txt three "three\nX-EDITED"; cp "${T}/a.applied2" "${T}/src/a.txt"
run "${T}/src" "${T}/p"
check "git source: a patch edited after it was applied is refused with a message that says so (exit 1)" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "edited after it was applied"'
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

echo "== a source folder INSIDE a bigger repository (like configgen inside the Batocera submodule); the patch uses 'diff --git' paths"
rm -rf "${T}/s1" "${T}/big" "${T}/p2"; mkdir -p "${T}/s1" "${T}/p2" "${T}/big/pkg/deep"
printf 'one\ntwo\nthree\n' > "${T}/s1/a.txt"
(cd "${T}/s1" && git init -q . && git add -A && git -c user.name=t -c user.email=t@t commit -qm b && sed -i 's/two/TWO-ADDED/' a.txt && git diff > "${T}/p2/0001-a.patch" && git checkout -q a.txt)
cp -a "${T}/s1" "${T}/big/pkg/deep/src"; rm -rf "${T}/big/pkg/deep/src/.git"
(cd "${T}/big" && git init -q . && git add -A && git -c user.name=t -c user.email=t@t commit -qm base)
run "${T}/big/pkg/deep/src" "${T}/p2"
check "the patch is really applied (the file changes), not silently skipped" '[ "${RC}" = 0 ] && grep -q "^TWO-ADDED" "${T}/big/pkg/deep/src/a.txt" && echo "${OUTTXT}" | grep -q "applied: 0001"'
run "${T}/big/pkg/deep/src" "${T}/p2"
check "a second run says already applied" '[ "${RC}" = 0 ] && echo "${OUTTXT}" | grep -q "already applied: 0001"'
(cd "${T}/big/pkg/deep/src" && git checkout -q a.txt 2>/dev/null; sed -i 's/two/TWO-RENAMED/' a.txt)
run "${T}/big/pkg/deep/src" "${T}/p2"
check "a patch that does not match is REFUSED there too (exit 1), never reported as applied" '[ "${RC}" = 1 ] && echo "${OUTTXT}" | grep -q "does not apply"'

echo
echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
