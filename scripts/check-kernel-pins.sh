#!/bin/bash
# Checks the kernel source pins (board/batocera/allwinner/a733/kernel-sources.pin):
#   - every key is present, commits are full 40-character hashes, URLs are https
#   - if the kernel and BSP clones exist (linux/kernel-66), they are at exactly the pinned commits
# Usage: scripts/check-kernel-pins.sh [--pin-file FILE] [--kernel-dir DIR]      exit status 0 = fine
set -u
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIN_FILE="${REPO_ROOT}/board/batocera/allwinner/a733/kernel-sources.pin"
KERNEL_DIR="${REPO_ROOT}/linux/kernel-66"
while [ $# -gt 0 ]; do
    case "$1" in
        --pin-file) PIN_FILE="$2"; shift 2 ;;
        --kernel-dir) KERNEL_DIR="$2"; shift 2 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
done
. "${REPO_ROOT}/scripts/lib-pin.sh"

[ -f "${PIN_FILE}" ] || { echo "FAIL: pin file not found: ${PIN_FILE}"; exit 1; }
bad=0
fail() { echo "FAIL: $*"; bad=1; }

for k in KERNEL BSP; do
    repo="$(read_pin "${PIN_FILE}" "${k}_REPO")"
    branch="$(read_pin "${PIN_FILE}" "${k}_BRANCH")"
    commit="$(read_pin "${PIN_FILE}" "${k}_COMMIT")"
    [[ "${repo}" =~ ^https://[A-Za-z0-9._/-]+$ ]] || fail "${k}_REPO must be an https URL (got '${repo}')"
    [[ "${branch}" =~ ^[A-Za-z0-9._/-]+$ ]]       || fail "${k}_BRANCH is missing or has odd characters (got '${branch}')"
    [[ "${commit}" =~ ^[0-9a-f]{40}$ ]]            || fail "${k}_COMMIT must be a full 40-character lowercase hash (got '${commit}')"
done

# the clones, when they exist, must be at the pins
check_clone() {   # NAME DIR COMMIT
    [ -d "$2/.git" ] || { echo "  (no ${1} clone at $2 yet; skipped)"; return; }
    local head; head="$(git -C "$2" rev-parse HEAD 2>/dev/null)"
    if [ "${head}" = "$3" ]; then echo "  ${1}: at the pinned commit ${3:0:12}"
    else fail "${1} clone is at ${head:0:12}, the pin says ${3:0:12}; run scripts/setup-kernel-66.sh --reset"; fi
}
check_clone kernel "${KERNEL_DIR}"     "$(read_pin "${PIN_FILE}" KERNEL_COMMIT)"
check_clone bsp    "${KERNEL_DIR}/bsp" "$(read_pin "${PIN_FILE}" BSP_COMMIT)"

[ "${bad}" -eq 0 ] && echo "kernel source pins OK"
exit "${bad}"
