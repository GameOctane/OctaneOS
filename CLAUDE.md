# Working in OctaneOS

## Project status (read first, update last)
`PROJECT_STATUS.md` is how Jason and Claude stay in sync across sessions. A morning job reads it across all his repos.

- **Before starting work:** read `PROJECT_STATUS.md` and `docs/ROADMAP.md`. If the status looks older than the recent git history, say so and fix it.
- **Before finishing a session:** update `PROJECT_STATUS.md`:
  - `Last session` — date, what changed, where you stopped.
  - `Resume here` — the first file or command for the next session.
  - `waiting_on` — `jason`, `claude`, `external` or `none`. If a decision is Jason's, put the question in `decision` and what you will do on a yes in `if_go`.
  - `focus`, `next_milestone`, `momentum` if they changed.
- Only write what you verified from the code, git history or a test. Mark anything you did not test (hardware, on-device behaviour) as untested. Do not change `excitement` or `priority`; those are Jason's.
- Keep the file's existing sections, and keep `Ideas / Backlog` intact.

## Conventions
- Changes go through a branch and a PR, never straight to `main`.
- Never merge a release or publish an OTA update. Releases need Jason's signing keys and an on-device test; follow `docs/releasing.md` and prepare the PR only.
- Run `scripts/check-patches.sh`, the `scripts/test-*.sh` suites, and `scripts/check-repo-hygiene.sh` before a PR (CI runs them too).
- No keys, logins, or developer passwords in the repo.

## Keeping the status current automatically
- CI runs `scripts/check-project-status.sh`: a wrong frontmatter value fails the PR; a status older than the git history only warns.
- A Stop hook (`.claude/hooks/status-reminder.sh`) asks once, at the end of a session that changed files, to update `PROJECT_STATUS.md`. It never blocks twice and never blocks a session that changed nothing.
