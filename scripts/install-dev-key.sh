#!/bin/bash
# Put a developer's SSH PUBLIC key into the image being built, so that person can log in as root
# on a test device without a password.  Called by post-build.sh when the build is started with
#     OCTANE_DEV_KEY_FILE=/absolute/path/to/key.pub ./scripts/build.sh --nohup
#
# Nothing is committed to the repo: the key comes from the file you point at.  Only the key type
# and the key itself are copied; the comment is replaced with "octaneos-dev", because the
# device's S13octane-init uses that word to find and remove developer keys.
#
# An image with a developer key must never be released: whoever holds the matching private key
# has root on every device running it (scripts/check-image.sh --release fails if it is present).
#
# Usage: install-dev-key.sh <public-key-file> <target-dir>
# Exit status: 0 = installed, 1 = bad key file or target, 2 = bad arguments.
set -euo pipefail

if [ "$#" -ne 2 ]; then
    sed -n '2,15p' "$0" >&2
    exit 2
fi
KEYFILE="$1"; TARGET="$2"

[ -r "${KEYFILE}" ] || { echo "ERROR: cannot read the key file ${KEYFILE}" >&2; exit 1; }
[ -d "${TARGET}" ] || { echo "ERROR: ${TARGET} is not a folder" >&2; exit 1; }

# first line only: "<type> <base64 key> [comment]"
read -r ktype kblob _ < "${KEYFILE}" || true

case "${ktype}" in
    ssh-ed25519|ssh-rsa|ecdsa-sha2-nistp256|ecdsa-sha2-nistp384|ecdsa-sha2-nistp521) ;;
    *) echo "ERROR: ${KEYFILE} does not look like an SSH public key (a .pub file). Is it the private key?" >&2; exit 1 ;;
esac
[[ "${kblob}" =~ ^[A-Za-z0-9+/]+=*$ ]] || { echo "ERROR: ${KEYFILE} has a malformed key" >&2; exit 1; }

install -d -m 0755 "${TARGET}/usr/share/octane"
printf '%s %s octaneos-dev\n' "${ktype}" "${kblob}" > "${TARGET}/usr/share/octane/dev-ssh-key.pub"
chmod 0644 "${TARGET}/usr/share/octane/dev-ssh-key.pub"
echo "[dev-key] installed a ${ktype} developer key into the image (comment: octaneos-dev)"
