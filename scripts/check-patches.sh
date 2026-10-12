#!/bin/bash
# Check every patch that the build applies, without building anything.
#
# Fails when:
#   - a patch has wrong hunk counts or no trailing context (GNU patch 2.7 either rejects it
#     as "malformed" or only applies it by guessing; see scripts/validate-patches.py), or
#   - a package patch folder is named host-<something>.  For host packages Buildroot looks in
#     <patch dir>/<name without "host-">, so such a folder is silently never applied.
#
# Not checked: anything under an obsolete/ folder, and board/.../a733/linux_patches/, a legacy
# directory from the old 5.15 kernel that the build no longer uses.
#
# Usage: scripts/check-patches.sh        (run from anywhere; exit status 0 = all good)
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
A733="${REPO_ROOT}/board/batocera/allwinner/a733"
status=0

# 1. Folder names under patches/ must be real Buildroot package names, never host-*.
for d in "${A733}"/patches/host-*; do
    [ -e "${d}" ] || continue
    echo "ERROR: ${d#"${REPO_ROOT}"/} is never applied." >&2
    echo "       Buildroot looks for host package patches under the name without 'host-'." >&2
    echo "       Rename it (for example host-xxd -> xxd) or move it to patches/obsolete/." >&2
    status=1
done

# 2. Hunk counts and context in every applied patch.
mapfile -t patches < <(
    {
        find "${A733}/linux_patches_66" -maxdepth 1 -name '*.patch'
        find "${A733}/patches" -name '*.patch' -not -path '*/obsolete/*'
    } | sort
)
echo "Checking ${#patches[@]} applied patch files..."
if ! "${REPO_ROOT}/scripts/validate-patches.py" "${patches[@]}"; then
    status=1
fi

[ "${status}" -eq 0 ] && echo "All patch checks passed."
exit "${status}"
