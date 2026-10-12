#!/bin/bash
# Remove files from Buildroot's target folder that used to come from our overlay and no longer do.
#
# Why: Buildroot keeps the target folder between builds and only ever adds or updates overlay
# files.  A file deleted from the overlay stays in target/, and so in the finished image.  This
# is how the second intro player (autostart_sun60iw2) survived its own removal.
#
# How: keep a manifest of the overlay files used by the previous build.  Files in the manifest
# that are no longer in the overlay are "removed".  A removed file is
#   - deleted from target/ if no package installs that path (it came only from our overlay);
#   - NOT deleted if a package also installs it (our overlay was overriding the package's copy;
#     deleting would break the system).  A warning says which package to reinstall instead.
# The first run has no manifest, so it only writes one.
#
# Usage: prune-stale-overlay-files.sh <target-dir> <packages-file-list> <manifest> <overlay-dir>...
# Exit status: 0 = done (warnings are printed), 2 = bad arguments.
set -euo pipefail

if [ "$#" -lt 4 ]; then
    sed -n '2,19p' "$0" >&2
    exit 2
fi
TARGET="$1"; PKGLIST="$2"; MANIFEST="$3"; shift 3

[ -d "${TARGET}" ] || { echo "ERROR: target folder ${TARGET} does not exist" >&2; exit 2; }

TMP="$(mktemp -d)"
trap 'rm -rf "${TMP:?}"' EXIT

# current overlay files, as ./relative/path
for dir in "$@"; do
    [ -d "${dir}" ] || { echo "ERROR: overlay folder ${dir} does not exist" >&2; exit 2; }
    ( cd "${dir}" && find . -type f -o -type l | sort )
done | sort -u > "${TMP}/now"

if [ ! -f "${MANIFEST}" ]; then
    mkdir -p "$(dirname "${MANIFEST}")"
    cp "${TMP}/now" "${MANIFEST}"
    echo "[overlay] first run: recorded $(wc -l < "${TMP}/now") overlay files, nothing to prune"
    exit 0
fi

sort -u "${MANIFEST}" > "${TMP}/before"
comm -23 "${TMP}/before" "${TMP}/now" > "${TMP}/removed"

removed=0; kept=0
while IFS= read -r rel; do
    [ -n "${rel}" ] || continue
    # only plain "./something" paths inside target/
    case "${rel}" in
        ./*) ;;
        *) echo "[overlay] ignoring odd manifest entry: ${rel}" >&2; continue ;;
    esac
    case "${rel}" in
        *..*) echo "[overlay] ignoring entry with '..': ${rel}" >&2; continue ;;
    esac
    owner=""
    if [ -f "${PKGLIST}" ]; then
        # grep finds nothing when no package owns the path; that is a normal answer, not an error
        owner="$(grep -F -m1 ",${rel}" "${PKGLIST}" | awk -F, -v p="${rel}" '$2 == p {print $1; exit}' || true)"
    fi
    if [ -n "${owner}" ]; then
        echo "[overlay] WARNING: ${rel} was removed from our overlay, but package '${owner}' also installs it."
        echo "          The old overlay copy is still in target/. Reinstall that package to restore its version: make ${owner}-reinstall"
        kept=$((kept + 1))
    elif [ -e "${TARGET}/${rel}" ] || [ -L "${TARGET}/${rel}" ]; then
        rm -f -- "${TARGET:?}/${rel:?}"
        echo "[overlay] removed stale file from target: ${rel}"
        removed=$((removed + 1))
    fi
done < "${TMP}/removed"

cp "${TMP}/now" "${MANIFEST}"
echo "[overlay] ${removed} stale file(s) removed, ${kept} need a package reinstall"
