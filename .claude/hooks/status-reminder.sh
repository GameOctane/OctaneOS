#!/bin/bash
# Claude Code Stop hook.  If this session changed files (or the branch is ahead of origin/main) but PROJECT_STATUS.md was not touched, ask Claude
# once to update it before finishing.  It never blocks twice in a row (stop_hook_active), never blocks a session that changed nothing, and
# only reads git.  Output is the JSON Claude Code expects; no output means "fine to stop".
IN="$(cat)"
case "${IN}" in *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;; esac
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -f PROJECT_STATUS.md ] || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
CHANGED="$( { git status --porcelain | cut -c4-; git diff --name-only origin/main...HEAD 2>/dev/null; } | sort -u )"
[ -n "${CHANGED}" ] || exit 0
printf '%s\n' "${CHANGED}" | grep -qx 'PROJECT_STATUS.md' && exit 0
cat <<'JSON'
{"decision":"block","reason":"This session changed files but PROJECT_STATUS.md was not updated. Per CLAUDE.md: update Last session, Resume here, waiting_on / decision / if_go, status_verified (today's date), and focus or progress if they changed. Mark anything not tested on a device as untested. Then run scripts/check-project-status.sh. If nothing in the status is out of date, say so and finish."}
JSON
