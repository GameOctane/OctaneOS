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

# --- the Stop hook (.claude/hooks/status-reminder.sh) in scratch repos ---
HOOK="${HERE}/../.claude/hooks/status-reminder.sh"
H="${T}/hook"; mkdir -p "${H}"; git -C "${H}" init -q -b main
g() { git -C "${H}" -c user.name=t -c user.email=t@t "$@"; }
cm() { GIT_COMMITTER_DATE="$1" GIT_AUTHOR_DATE="$1" g commit -q -m "$2"; }   # cm <date> <message>
echo status > "${H}/PROJECT_STATUS.md"; echo a > "${H}/a.txt"; g add -A; cm "2026-01-01T10:00:00" first
hk() { local name="$1" want="$2" input="${3:-{\}}"; local out; out="$(printf '%s' "${input}" | CLAUDE_PROJECT_DIR="${H}" bash "${HOOK}")"
  local got=quiet; [ -n "${out}" ] && got=block
  if [ "${got}" = "${want}" ]; then PASS=$((PASS+1)); echo "  ok    ${name}"; else FAILN=$((FAILN+1)); echo "  FAIL  ${name} (${got}, wanted ${want})"; fi; }
hk "hook: nothing changed since the status commit stays quiet" quiet
echo b >> "${H}/a.txt";                                              hk "hook: an uncommitted file asks for a status update" block
hk "hook: never blocks twice in a row" quiet '{"stop_hook_active": true}'
g add -A; cm "2026-01-02T10:00:00" "code change";                     hk "hook: a commit made after the status commit asks" block
echo s2 >> "${H}/PROJECT_STATUS.md"; g add -A; cm "2026-01-03T10:00:00" "status";   hk "hook: after the status commit it is quiet again" quiet
# The status is updated on another branch (a separate worktree) after this branch's last commit.
g checkout -q -b work; echo c >> "${H}/a.txt"; g add -A; cm "2026-01-04T10:00:00" "more code"
g checkout -q main; g worktree add -q -b statusbr "${T}/wt-status" main
echo s3 >> "${T}/wt-status/PROJECT_STATUS.md"; git -C "${T}/wt-status" add -A; git -C "${T}/wt-status" -c user.name=t -c user.email=t@t commit -q -m status3 --date=2026-01-05T10:00:00
GIT_COMMITTER_DATE=2026-01-05T10:00:00 git -C "${T}/wt-status" -c user.name=t -c user.email=t@t commit -q --amend --no-edit --date=2026-01-05T10:00:00
g checkout -q work;                                                    hk "hook: status updated on another branch counts" quiet
echo d >> "${H}/a.txt"
echo s4 >> "${T}/wt-status/PROJECT_STATUS.md";                         hk "hook: an uncommitted status edit in another worktree counts" quiet
# A build that patches files inside a submodule leaves it "modified"; that is not a session change.
git init -q "${T}/sub"; git -C "${T}/sub" -c user.name=t -c user.email=t@t commit -q --allow-empty -m s; echo x > "${T}/sub/f"; git -C "${T}/sub" add f; git -C "${T}/sub" -c user.name=t -c user.email=t@t commit -q -m f
g checkout -q -- . ; g checkout -q main; git -C "${H}" -c protocol.file.allow=always submodule add -q "${T}/sub" sub; cm "2026-01-06T10:00:00" "add submodule"
echo S >> "${T}/wt-status/PROJECT_STATUS.md"; git -C "${T}/wt-status" checkout -q -- PROJECT_STATUS.md
echo s5 >> "${H}/PROJECT_STATUS.md"; g add -A; cm "2026-01-07T10:00:00" "status5"
echo dirty >> "${H}/sub/f";                                            hk "hook: a modified submodule is not a session change" quiet
echo "${PASS} passed, ${FAILN} failed"; [ "${FAILN}" -eq 0 ]
