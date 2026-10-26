#!/bin/bash
# Write the release manifest for an update archive: the small text file that gets signed.
#
# The manifest binds four things together so one signature covers all of them: the board the
# update is for, its version, and the exact size and SHA-256 of the archive.  The device checks
# the signature on this file first, then checks that the archive it downloads matches it.
#
# Usage: scripts/make-manifest.sh <board> <version> <archive> [manifest-out]
#        scripts/make-manifest.sh cubie-a7s 0.8.0 boot.tar.xz        (writes boot.tar.xz.manifest)
# Format, one key=value per line:
#        octaneos-manifest=1
#        board=cubie-a7s
#        version=0.8.0
#        file=boot.tar.xz
#        size=<bytes>
#        sha256=<64 hex digits>
set -euo pipefail
die() { echo "make-manifest: $*" >&2; exit 1; }
[ $# -ge 3 ] && [ $# -le 4 ] || die "usage: $0 <board> <version> <archive> [manifest-out]"
board="$1"; version="$2"; archive="$3"; out="${4:-${archive}.manifest}"
[[ "${board}" =~ ^[a-z0-9][a-z0-9-]*$ ]] || die "the board name must be lower-case letters, digits and dashes: '${board}'"
[[ "${version}" =~ ^[0-9]+(\.[0-9]+)*$ ]] || die "the version must be numbers and dots, like 0.8.0: '${version}'"
[ -f "${archive}" ] || die "no such archive: ${archive}"
name="$(basename "${archive}")"
[[ "${name}" =~ ^[A-Za-z0-9._-]+$ ]] || die "the archive name has odd characters: '${name}'"
size="$(stat -c %s "${archive}")"
[ "${size}" -gt 0 ] || die "the archive is empty"
sha="$(sha256sum "${archive}" | awk '{print $1}')"
printf 'octaneos-manifest=1\nboard=%s\nversion=%s\nfile=%s\nsize=%s\nsha256=%s\n' \
    "${board}" "${version}" "${name}" "${size}" "${sha}" > "${out}"
echo "wrote ${out}"
