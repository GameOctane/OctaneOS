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

BUILD_NUM=$(grep 'OCTANE_BUILD_NUMBER=' "${POST_BUILD}" | grep -v '#' | head -1 | cut -d= -f2)
if [ -z "${BUILD_NUM}" ]; then
    echo "ERROR: could not read OCTANE_BUILD_NUMBER from ${POST_BUILD}" >&2
    exit 1
fi

VERSION_STRING="${BUILD_NUM} $(date +%Y/%m/%d) $(date +%H:%M)"
echo "${VERSION_STRING}" > "${OTA_VERSION_FILE}"
echo "Updated ${OTA_VERSION_FILE} → ${VERSION_STRING}"
