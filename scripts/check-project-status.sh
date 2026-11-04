#!/bin/bash
# Check PROJECT_STATUS.md: the frontmatter keys exist and use values the dashboard (Mission-Control) understands, and say if the status has
# fallen behind the git history.  Wrong values are an error (exit 1); a stale date is only a warning, because a quiet week is not a mistake.
# Usage: scripts/check-project-status.sh [REPO_DIR]      env STALE_DAYS (default 14)
set -uo pipefail
REPO="${1:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"; F="${REPO}/PROJECT_STATUS.md"
STALE_DAYS="${STALE_DAYS:-14}"; FAIL=0
bad() { printf '  FAIL  %s\n' "$1"; FAIL=1; }
[ -f "${F}" ] || { echo "no PROJECT_STATUS.md in ${REPO}" >&2; exit 2; }
[ "$(sed -n 1p "${F}")" = "---" ] || { bad "the file must start with a --- frontmatter line"; exit 1; }
FM="$(awk 'NR==1{next} /^---$/{exit} {print}' "${F}")"
# value of a key: text after "key:" up to a trailing " # comment", with surrounding quotes removed
val() { printf '%s\n' "${FM}" | sed -n "s/^$1:[[:space:]]*//p" | head -1 | sed -E 's/[[:space:]]+#.*$//; s/^"(.*)"$/\1/'; }
# one-of check: key, then the allowed values
oneof() { local k="$1" v; shift; v="$(val "${k}")"; for a in "$@"; do [ "${v}" = "${a}" ] && return 0; done; bad "${k}: '${v}' is not one of: $*"; }

echo "== frontmatter keys and values"
for k in phase priority category progress focus next_milestone milestone_distance community_pressure excitement strategic momentum \
         audience uniqueness viral_potential mvp_distance waiting_on decision if_go status_verified; do
  printf '%s\n' "${FM}" | grep -q "^${k}:" || bad "missing key: ${k}"
done
P="$(val progress)"; case "${P}" in ''|*[!0-9]*) bad "progress must be a whole number 0-100 (got '${P}')" ;; *) [ "${P}" -le 100 ] || bad "progress over 100" ;; esac
oneof momentum rolling steady blocked stalled
oneof excitement high medium low
oneof priority high medium low
oneof community_pressure high medium low
oneof viral_potential high medium low
oneof waiting_on jason claude external none
oneof milestone_distance days weeks months
oneof mvp_distance days weeks months
if [ "$(val waiting_on)" = "jason" ] && [ -z "$(val decision)" ]; then bad "waiting_on is jason but decision is empty (say what he must decide)"; fi

echo "== is the status current"
SV="$(val status_verified)"; D="$(printf '%s' "${SV}" | grep -Eo '^[0-9]{4}-[0-9]{2}-[0-9]{2}' || true)"
if [ -z "${D}" ]; then bad "status_verified must start with a date (YYYY-MM-DD)"
else
  LAST="$(git -C "${REPO}" log -1 --format=%cs 2>/dev/null || true)"
  if [ -n "${LAST}" ]; then
    GAP=$(( ( $(date -d "${LAST}" +%s) - $(date -d "${D}" +%s) ) / 86400 ))
    if [ "${GAP}" -gt "${STALE_DAYS}" ]; then
      printf '  WARN  status last verified %s, newest commit %s (%s days later): update PROJECT_STATUS.md\n' "${D}" "${LAST}" "${GAP}"
      [ -n "${GITHUB_ACTIONS:-}" ] && echo "::warning file=PROJECT_STATUS.md::status last verified ${D}, newest commit ${LAST}"
    else echo "  ok    verified ${D}, newest commit ${LAST}"; fi
  fi
fi
[ "${FAIL}" -eq 0 ] && echo "project status: OK" || echo "project status: PROBLEMS FOUND"
exit "${FAIL}"
