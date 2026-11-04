#!/bin/bash
# Test scripts/check-project-status.sh against good and bad status files in a scratch repo.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"; CHECK="${HERE}/check-project-status.sh"
T="$(mktemp -d)"; trap 'rm -rf "${T}"' EXIT; PASS=0; FAILN=0
good() { sed 's/^momentum:.*/momentum: rolling/' "${HERE}/../PROJECT_STATUS.md" > "${T}/PROJECT_STATUS.md"; }
t() { local name="$1" want="$2"; bash "${CHECK}" "${T}" >"${T}/out" 2>&1; local got=$?
  if [ "${got}" -eq "${want}" ]; then PASS=$((PASS+1)); echo "  ok    ${name}"; else FAILN=$((FAILN+1)); echo "  FAIL  ${name} (exit ${got}, wanted ${want})"; sed 's/^/        /' "${T}/out"; fi; }
git -C "${T}" init -q; git -C "${T}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m x
good;                                                          t "the real status file passes" 0
good; sed -i 's/^momentum:.*/momentum: accelerating/' "${T}/PROJECT_STATUS.md";  t "a momentum the dashboard cannot score fails" 1
good; sed -i 's/^excitement:.*/excitement: very high/' "${T}/PROJECT_STATUS.md"; t "excitement 'very high' fails" 1
good; sed -i 's/^progress:.*/progress: lots/' "${T}/PROJECT_STATUS.md";           t "progress must be a number" 1
good; sed -i '/^waiting_on:/d' "${T}/PROJECT_STATUS.md";                          t "a missing key fails" 1
good; sed -i 's/^status_verified:.*/status_verified: "recently"/' "${T}/PROJECT_STATUS.md"; t "status_verified needs a date" 1
good; sed -i 's/^status_verified: "[0-9-]*/status_verified: "2020-01-01/' "${T}/PROJECT_STATUS.md"; t "an old date only warns" 0
echo "${PASS} passed, ${FAILN} failed"; [ "${FAILN}" -eq 0 ]
