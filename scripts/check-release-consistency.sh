#!/bin/bash
# The version a build is stamped with, the release notes and the published version file must agree.
#   - post-build.sh: the tag is v<version>, the build number is a number
#   - docs/releases/<version>.md exists, has the usual sections and no template placeholders (the publish script refuses those too)
#   - the version file that announces updates (ota/.../batocera.version) is not NEWER than the version being built
# Usage: scripts/check-release-consistency.sh [REPO_DIR]     exit status 0 = consistent
set -uo pipefail
REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
PB="${REPO}/board/batocera/allwinner/a733/post-build.sh"
OTA="${REPO}/ota/cubie-a7s/stable/last/batocera.version"
FAIL=0
bad() { printf '  FAIL  %s\n' "$1"; FAIL=1; }
ok() { printf '  PASS  %s\n' "$1"; }
[ -f "${PB}" ] || { echo "no post-build.sh at ${PB}" >&2; exit 2; }

get() { sed -nE "s/^$1=\"?([^\"#]*)\"?.*/\1/p" "${PB}" | head -1; }
NUM="$(get OCTANE_BUILD_NUMBER)"; TAG="$(get OCTANE_RELEASE_TAG)"; VER="$(get OCTANE_VERSION_STRING)"
echo "== versions in post-build.sh: build ${NUM:-?}, tag ${TAG:-?}, version ${VER:-?}"
[[ "${NUM}" =~ ^[0-9]+$ ]] && ok "build number is a number" || bad "OCTANE_BUILD_NUMBER is not a number (${NUM:-empty})"
[[ "${VER}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] && ok "version looks like X.Y.Z" || bad "OCTANE_VERSION_STRING is not X.Y.Z (${VER:-empty})"
[ "${TAG}" = "v${VER}" ] && ok "tag is v<version>" || bad "tag ${TAG:-empty} does not match version ${VER:-empty} (expected v${VER})"

echo "== release notes"
N="${REPO}/docs/releases/${VER}.md"
if [ -s "${N}" ]; then
    ok "docs/releases/${VER}.md exists"
    for h in "## Compatibility" "## What changed" "## Known issues" "## Files"; do
        grep -qF "$h" "${N}" && ok "has section: ${h#\#\# }" || bad "notes are missing the section: ${h#\#\# }"
    done
    if grep -qE 'yes / no|<version>|<yes/no>|<link' "${N}"; then bad "notes still contain template placeholders (yes / no, <version>, <yes/no>, <link ...>)"; else ok "no template placeholders"; fi
else
    bad "docs/releases/${VER}.md is missing or empty"
fi

echo "== the announcing version file"
if [ -f "${OTA}" ]; then
    O="$(tr -d '[:space:]' < "${OTA}")"
    if [[ "${O}" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if [ "$(printf '%s\n%s\n' "${O}" "${VER}" | sort -V | tail -1)" = "${VER}" ]; then ok "version file (${O}) is not newer than the build (${VER})"
        else bad "version file says ${O}, newer than the build ${VER}: devices would be told about a version that does not exist"; fi
    else bad "version file is not X.Y.Z (${O:-empty})"; fi
else
    bad "no version file at ota/cubie-a7s/stable/last/batocera.version"
fi

echo
if [ "${FAIL}" = 0 ]; then echo "release consistency: OK"; else echo "release consistency: FAILED"; fi
exit "${FAIL}"
