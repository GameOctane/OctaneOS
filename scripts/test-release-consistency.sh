#!/bin/bash
# Test scripts/check-release-consistency.sh with throw-away folders.
# Usage: scripts/test-release-consistency.sh        exit status 0 = all tests passed
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHK="${REPO_ROOT}/scripts/check-release-consistency.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T:?}"' EXIT
R="${T}/r"; PB="${R}/board/batocera/allwinner/a733/post-build.sh"; OTA="${R}/ota/cubie-a7s/stable/last/batocera.version"
PASS=0; FAIL=0
check() { if eval "$2"; then PASS=$((PASS+1)); printf '  PASS  %s\n' "$1"; else FAIL=$((FAIL+1)); printf '  FAIL  %s\n        %s\n' "$1" "$2"; fi; }
fresh() { rm -rf "${R}"; mkdir -p "$(dirname "${PB}")" "$(dirname "${OTA}")" "${R}/docs/releases"
    printf 'OCTANE_BUILD_NUMBER=73\nOCTANE_RELEASE_TAG="v0.8.1"\nOCTANE_VERSION_STRING="0.8.1"\n' > "${PB}"
    echo 0.8.0 > "${OTA}"
    printf '## Compatibility\nx\n## What changed\nx\n## Known issues\nx\n## Files\nx\n' > "${R}/docs/releases/0.8.1.md"; }
run() { OUT="$("${CHK}" "${R}" 2>&1)"; RC=$?; }

echo "== consistent"
fresh; run; check "a release being prepared (version file still the old one)" '[ "${RC}" = 0 ]'
fresh; echo 0.8.1 > "${OTA}"; run; check "after the announcement (version file equals the build)" '[ "${RC}" = 0 ]'

echo "== inconsistent"
fresh; sed -i 's/v0.8.1/v0.8.0/' "${PB}"; run; check "tag does not match the version" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "does not match"'
fresh; rm "${R}/docs/releases/0.8.1.md"; run; check "no release notes for the version" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "missing or empty"'
fresh; sed -i 's/## Files//' "${R}/docs/releases/0.8.1.md"; run; check "notes missing a section" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "missing the section: Files"'
fresh; echo '- Update over the air: <yes/no>' >> "${R}/docs/releases/0.8.1.md"; run; check "a <yes/no> placeholder" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "placeholders"'
fresh; echo 'see <link to the release>' >> "${R}/docs/releases/0.8.1.md"; run; check "a <link ...> placeholder" '[ "${RC}" != 0 ]'
fresh; echo 0.9.0 > "${OTA}"; run; check "version file newer than the build" '[ "${RC}" != 0 ] && echo "${OUT}" | grep -q "newer than the build"'
fresh; echo 0.10.0 > "${OTA}"; sed -i 's/0\.8\.1/0.9.5/g' "${PB}"; mv "${R}/docs/releases/0.8.1.md" "${R}/docs/releases/0.9.5.md"; run; check "0.10.0 is newer than 0.9.5 (compared as numbers, not text)" '[ "${RC}" != 0 ]'
fresh; sed -i 's/=73/=abc/' "${PB}"; run; check "build number not a number" '[ "${RC}" != 0 ]'
fresh; rm "${OTA}"; run; check "no version file" '[ "${RC}" != 0 ]'

echo "== the real repository"
check "this repository is consistent" '"${CHK}" "${REPO_ROOT}" >/dev/null 2>&1'

echo; echo "${PASS} passed, ${FAIL} failed"
[ "${FAIL}" -eq 0 ]
