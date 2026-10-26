#!/bin/bash
# Sign a release manifest.  RUN THIS ON YOUR OFFLINE MACHINE, never on the build server: the whole
# point is that the private key never touches GitHub or the server that builds the images.
# It needs only OpenSSL 3 and the manifest file; copy the .sig file back to the build server.
#
# Usage: scripts/sign-release.sh <manifest> <private-key.pem> [signature-out]
#        (OpenSSL asks for the key's passphrase if it is encrypted)
# Writes <manifest>.sig (a 64-byte Ed25519 signature) and, if the public keys of the project are
# next to this script (../keys/update/*.pub.pem), checks that the signature matches one of them.
set -euo pipefail
die() { echo "sign-release: $*" >&2; exit 1; }
[ $# -ge 2 ] && [ $# -le 3 ] || die "usage: $0 <manifest> <private-key.pem> [signature-out]"
manifest="$1"; key="$2"; out="${3:-${manifest}.sig}"
[ -s "${manifest}" ] || die "no such manifest: ${manifest}"
[ -f "${key}" ] || die "no such key file: ${key}"
echo "About to sign this manifest:"; sed 's/^/    /' "${manifest}"
openssl pkeyutl -sign -inkey "${key}" -rawin -in "${manifest}" -out "${out}"
[ "$(stat -c %s "${out}")" -eq 64 ] || { rm -f "${out}"; die "the signature is not 64 bytes: was that an Ed25519 key?"; }
echo "wrote ${out}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
shopt -s nullglob
pubs=("${here}"/../keys/update/*.pub.pem)
if [ ${#pubs[@]} -gt 0 ]; then
    "${here}/verify-signature.sh" "${manifest}" "${out}" "${pubs[@]}" \
        || { rm -f "${out}"; die "this key is not one of the project's update keys (keys/update); signature removed"; }
else
    echo "note: no public keys found in keys/update, so the signature could not be checked against them"
fi
