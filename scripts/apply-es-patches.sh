#!/bin/bash
# Apply the OctaneOS patches to the EmulationStation source that scripts/build.sh builds from (BATOCERA_EMULATIONSTATION_OVERRIDE_SRCDIR).
# Buildroot does not apply a package's own patches to an override source tree, and the ES source is a separate repository, so the changes
# OctaneOS needs live in board/batocera/allwinner/a733/es-patches/ and are applied here.
#
# Safe to run on every build: a patch that is already applied is left alone; a patch that does not apply STOPS the build (the ES source
# changed upstream: look at it, do not skip it).  Each patch is applied all-or-nothing.
#
# Usage: scripts/apply-es-patches.sh SRC_DIR [PATCH_DIR]
# Exit status: 0 = every patch applied or already applied, 1 = a patch does not apply, 2 = bad arguments.
set -uo pipefail
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="${1:-}"; PDIR="${2:-${REPO_ROOT}/board/batocera/allwinner/a733/es-patches}"
if [ -z "${SRC}" ] || [ ! -d "${SRC}" ] || [ ! -d "${PDIR}" ]; then
    echo "usage: apply-es-patches.sh SRC_DIR [PATCH_DIR]   (both must be folders)" >&2; exit 2
fi
SRC="$(cd "${SRC}" && pwd)"; n=0
# A patch made with "diff --git" names its files relative to the ROOT of the repository.  When SRC is a sub-folder of a bigger repository (the
# configgen source inside the Batocera submodule) git apply would silently skip every file "outside the current folder" and still report
# success, so tell it which sub-folder we are in.  (Empty for a source that is its own repository, like EmulationStation.)
PREFIX="$(cd "${SRC}" && git rev-parse --show-prefix 2>/dev/null)"; PREFIX="${PREFIX%/}"
GA=(git apply); [ -n "${PREFIX}" ] && GA+=("--directory=${PREFIX}")
shopt -s nullglob
for p in "${PDIR}"/*.patch; do
    p="$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; name="$(basename "${p}")"; n=$((n+1))
    if (cd "${SRC}" && "${GA[@]}" --check -R "${p}" >/dev/null 2>&1); then
        echo "[es-patches] already applied: ${name}"
    elif (cd "${SRC}" && "${GA[@]}" --check "${p}" >/dev/null 2>&1); then
        (cd "${SRC}" && "${GA[@]}" "${p}") || { echo "ERROR: ${name} failed while applying" >&2; exit 1; }
        echo "[es-patches] applied: ${name}"
    else
        echo "ERROR: ${name} does not apply to ${SRC} (the ES source changed? update the patch)" >&2
        (cd "${SRC}" && "${GA[@]}" --check "${p}") 2>&1 | head -5 >&2
        exit 1
    fi
done
[ "${n}" -gt 0 ] || echo "[es-patches] no patches in ${PDIR}"
exit 0
