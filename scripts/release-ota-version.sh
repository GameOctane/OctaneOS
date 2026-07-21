#!/bin/bash
# Update ota/cubie-a7s/stable/last/batocera.version to match the build number
# in post-build.sh. Run this before committing a release.
#
# Usage: ./scripts/release-ota-version.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
POST_BUILD="${REPO_ROOT}/board/batocera/allwinner/a733/post-build.sh"
OTA_VERSION_FILE="${REPO_ROOT}/ota/cubie-a7s/stable/last/batocera.version"

BUILD_OUTPUT="${REPO_ROOT}/batocera/output/a733-cubie-a7s/target/usr/share/batocera/batocera.version"

if [ -f "${BUILD_OUTPUT}" ]; then
    VERSION_STRING=$(cat "${BUILD_OUTPUT}" | tr -d '\n\r')
    echo "${VERSION_STRING}" > "${OTA_VERSION_FILE}"
    echo "Updated ${OTA_VERSION_FILE} → ${VERSION_STRING} (from build output)"
else
    # Fallback: derive from post-build.sh if no build output exists
    BUILD_NUM=$(grep 'OCTANE_BUILD_NUMBER=' "${POST_BUILD}" | grep -v '#' | head -1 | cut -d= -f2)
    if [ -z "${BUILD_NUM}" ]; then
        echo "ERROR: could not read OCTANE_BUILD_NUMBER from ${POST_BUILD}" >&2
        exit 1
    fi
    VERSION_STRING="${BUILD_NUM} $(date +%Y/%m/%d) $(date +%H:%M)"
    echo "WARNING: build output not found, using current date — run after build for exact match" >&2
    echo "${VERSION_STRING}" > "${OTA_VERSION_FILE}"
    echo "Updated ${OTA_VERSION_FILE} → ${VERSION_STRING} (fallback — timestamps may not match)"
fi
