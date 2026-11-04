#!/bin/bash
# Claude Code Stop hook.  If this session changed files (uncommitted, or committed since the status file was last updated on any branch) but PROJECT_STATUS.md was not touched, ask Claude
# once to update it before finishing.  It never blocks twice in a row (stop_hook_active), never blocks a session that changed nothing, and
# only reads git.  Output is the JSON Claude Code expects; no output means "fine to stop".
IN="$(cat)"
case "${IN}" in *'"stop_hook_active": true'*|*'"stop_hook_active":true'*) exit 0 ;; esac
cd "${CLAUDE_PROJECT_DIR:-.}" 2>/dev/null || exit 0
[ -f PROJECT_STATUS.md ] || exit 0
git rev-parse --git-dir >/dev/null 2>&1 || exit 0
# What counts as "changed": uncommitted files in this checkout, plus files in commits made after the newest commit (on ANY branch) that touched
# PROJECT_STATUS.md.  Looking at every branch matters because the status is often updated in a separate worktree; comparing only with origin/main
# made the hook fire on every turn even when the status was already current.
LAST="$(git log --all -1 --format=%ct -- PROJECT_STATUS.md 2>/dev/null)"
CHANGED="$( { git status --porcelain --ignore-submodules=dirty | cut -c4-; if [ -n "${LAST}" ]; then git log --after="$((LAST + 1))" --name-only --format= HEAD 2>/dev/null; else git diff --name-only origin/main...HEAD 2>/dev/null; fi; } | sort -u )"
[ -n "${CHANGED}" ] || exit 0
printf '%s\n' "${CHANGED}" | grep -qx 'PROJECT_STATUS.md' && exit 0
# A status edit that is not committed yet, in any worktree of this repo, also counts as "updated".
git worktree list --porcelain | sed -n 's/^worktree //p' | while read -r W; do
  if git -C "${W}" status --porcelain -- PROJECT_STATUS.md 2>/dev/null | grep -q .; then exit 1; fi
done
[ $? -eq 1 ] && exit 0
cat <<'JSON'
{"decision":"block","reason":"This session changed files but PROJECT_STATUS.md was not updated. Per CLAUDE.md: update Last session, Resume here, waiting_on / decision / if_go, status_verified (today's date), and focus or progress if they changed. Mark anything not tested on a device as untested. Then run scripts/check-project-status.sh. If nothing in the status is out of date, say so and finish."}
JSON
