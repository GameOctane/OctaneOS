#!/bin/bash
# Fail if the repository contains something that must never be committed: private keys, the build's keys.txt, real developer passwords, or
# anything but public keys in keys/update/.  It prints FILE NAMES and LINE NUMBERS only, never the matching text, so a leak is not repeated in a log.
# Usage: scripts/check-repo-hygiene.sh [REPO_DIR]     exit status 0 = clean
# The test suites (scripts/test-*.sh) contain fake keys and canary values on purpose and are skipped for the content rules.
set -uo pipefail
REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
cd "${REPO}" || { echo "no such folder: ${REPO}" >&2; exit 2; }
git rev-parse --git-dir >/dev/null 2>&1 || { echo "not a git repository: ${REPO}" >&2; exit 2; }
FAIL=0
bad() { printf '  FAIL  %s\n' "$1"; FAIL=1; }

# only regular tracked files (a git submodule shows up as a folder and is not scanned)
mapfile -d '' FILES < <(git ls-files -z)
REG=(); for f in "${FILES[@]}"; do [ -f "$f" ] && [ ! -L "$f" ] && REG+=("$f"); done

echo "== file names that must not be tracked"
for f in "${REG[@]}"; do
    case "$(basename "$f")" in
        keys.txt|*.key.pem|id_rsa|id_ed25519|id_ecdsa|*.p12|*.pfx) bad "tracked file that looks like a secret: $f" ;;
    esac
done

echo "== keys/update holds public keys only"
for f in "${REG[@]}"; do
    case "$f" in
        keys/update/*.pub.pem|keys/update/README.md) ;;
        keys/update/*) bad "unexpected file in keys/update: $f" ;;
    esac
done

echo "== file contents"
is_test() { case "$1" in scripts/test-*.sh) return 0 ;; esac; return 1; }
for f in "${REG[@]}"; do
    is_test "$f" && continue
    # a private key block in any text file
    if n=$(grep -nIE -- '-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----' "$f" | cut -d: -f1 | head -3 | tr '\n' ' ') && [ -n "$n" ]; then
        bad "private key block in $f (line $n)"
    fi
    # a developer password with a real-looking value (placeholders such as <password> are fine)
    if n=$(grep -nIE -- 'devpassword=[A-Za-z0-9%._~-]{4,}' "$f" | cut -d: -f1 | head -3 | tr '\n' ' ') && [ -n "$n" ]; then
        bad "developer password with a value in $f (line $n)"
    fi
done

echo
if [ "${FAIL}" = 0 ]; then echo "repository hygiene: OK (${#REG[@]} files looked at)"; else echo "repository hygiene: FAILED (values are not printed on purpose)"; fi
exit "${FAIL}"
