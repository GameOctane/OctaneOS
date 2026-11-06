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
PATCHES=("${PDIR}"/*.patch)

# Which patches are already in?  A later patch can rewrite lines that an earlier patch's context or changes sit on, so testing each patch by
# itself ("does its reverse apply?") gives wrong answers once patches are layered.  The right test undoes them newest first, exactly as they
# were applied: copy the working tree into a throw-away git index (the real files are never touched) and reverse the patches there, from the
# last to the first.  A patch whose reverse applies at its turn is in; one that does not is not.  Only for a source that is its own git
# repository (EmulationStation); anything else uses the per-patch test in the loop below.
declare -A IN=(); LAYERED=0
if [ -z "${PREFIX}" ] && (cd "${SRC}" && git rev-parse --verify -q HEAD >/dev/null 2>&1); then
    IDX="$(mktemp)"; trap 'rm -f "${IDX}"' EXIT
    if (cd "${SRC}" && export GIT_INDEX_FILE="${IDX}" && git read-tree HEAD && git add -A >/dev/null 2>&1); then
        LAYERED=1
        for ((i=${#PATCHES[@]}-1; i>=0; i--)); do
            pp="$(cd "$(dirname "${PATCHES[i]}")" && pwd)/$(basename "${PATCHES[i]}")"
            if (cd "${SRC}" && GIT_INDEX_FILE="${IDX}" git apply --cached -R "${pp}" >/dev/null 2>&1); then IN["${i}"]=1; fi
        done
    fi
fi

i=-1
for p in "${PATCHES[@]}"; do
    i=$((i+1)); p="$(cd "$(dirname "${p}")" && pwd)/$(basename "${p}")"; name="$(basename "${p}")"; n=$((n+1))
    if [ "${LAYERED}" = 1 ] && [ "${IN[${i}]:-0}" = 1 ]; then
        echo "[es-patches] already applied: ${name}"
    elif [ "${LAYERED}" = 0 ] && (cd "${SRC}" && "${GA[@]}" --check -R "${p}" >/dev/null 2>&1); then
        echo "[es-patches] already applied: ${name}"
    elif (cd "${SRC}" && "${GA[@]}" --check "${p}" >/dev/null 2>&1); then
        (cd "${SRC}" && "${GA[@]}" "${p}") || { echo "ERROR: ${name} failed while applying" >&2; exit 1; }
        echo "[es-patches] applied: ${name}"
    elif [ "${LAYERED}" = 0 ] && [ -z "${PREFIX}" ] && (cd "${SRC}" && patch -p1 -R --dry-run -F3 -s < "${p}" >/dev/null 2>&1); then
        # A LATER patch changed lines right next to this patch's hunk, so the exact reverse check above fails although this patch is in.
        # Allow a little context difference (fuzz) for the reverse check only.  (Only used when the source is not a git repository.)
        echo "[es-patches] already applied (a later patch touches its neighbour lines): ${name}"
    else
        echo "ERROR: ${name} does not apply to ${SRC} (the ES source changed, or the patch was edited after it was applied: undo the old version with git apply -R, or reset the source, then run again)" >&2
        (cd "${SRC}" && "${GA[@]}" --check "${p}") 2>&1 | head -5 >&2
        exit 1
    fi
done
[ "${n}" -gt 0 ] || echo "[es-patches] no patches in ${PDIR}"
exit 0
