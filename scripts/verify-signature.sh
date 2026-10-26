#!/bin/bash
# Check a release signature against one or more public keys.  Exit status 0 = the signature is
# valid for at least one of them.  The same OpenSSL call the device's updater uses.
#
# Usage: scripts/verify-signature.sh <manifest> <signature> <public-key.pem>...
set -u
[ $# -ge 3 ] || { echo "usage: $0 <manifest> <signature> <public-key.pem>..." >&2; exit 2; }
manifest="$1"; sig="$2"; shift 2
[ -s "${manifest}" ] && [ -s "${sig}" ] || { echo "verify-signature: manifest or signature is missing or empty" >&2; exit 1; }
for key in "$@"; do
    [ -f "${key}" ] || continue
    if openssl pkeyutl -verify -pubin -inkey "${key}" -rawin -in "${manifest}" -sigfile "${sig}" >/dev/null 2>&1; then
        echo "signature valid (key: $(basename "${key}"))"
        exit 0
    fi
done
echo "verify-signature: the signature does not match any of the given keys" >&2
exit 1
