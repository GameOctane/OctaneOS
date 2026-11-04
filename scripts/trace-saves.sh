#!/bin/bash
# Show which files a play session wrote, and whether they went into the active profile's folder.  Read-only on the board: it only lists files.
#
# Why: profiles only work for a system if its saves, save states and memory cards land under /userdata/profiles/<profile>/.  A configgen
# generator or a libretro core that writes somewhere else (a fixed /userdata/saves/..., the game's folder, its own config folder) is shared by
# every profile.  Reading code finds most of these; only a real play session proves a system.
#
# Usage:
#   scripts/trace-saves.sh start            remember the board's clock (nothing is written on the board)
#   ...play the game, save in the game, and make a save state if the system allows it, then quit the game...
#   scripts/trace-saves.sh report           list what was written since "start" and sort it into INSIDE the profile / OUTSIDE it
# Environment: BOARD_HOST (default 192.168.1.250), BOARD_KEY (default ~/.ssh/octaneos_board), BOARD_KNOWN_HOSTS (a known_hosts file for the card),
#              TRACE_STATE (where "start" keeps the clock; default ~/.cache/octane-trace-saves).
set -uo pipefail
HOST="${BOARD_HOST:-192.168.1.250}"; KEY="${BOARD_KEY:-$HOME/.ssh/octaneos_board}"
KH="${BOARD_KNOWN_HOSTS:-$HOME/.ssh/known_hosts}"; STATE="${TRACE_STATE:-$HOME/.cache/octane-trace-saves}"
b() { ssh -i "${KEY}" -o UserKnownHostsFile="${KH}" -o ConnectTimeout=10 -o BatchMode=yes "root@${HOST}" "$@"; }

case "${1:-}" in
  start)
    mkdir -p "$(dirname "${STATE}")"
    T="$(b 'date +%s')" || { echo "cannot reach the board at ${HOST}" >&2; exit 1; }
    echo "${T}" > "${STATE}"; echo "started at board time ${T}; now play, save, quit the game, then run: $0 report"
    ;;
  report)
    [ -s "${STATE}" ] || { echo "run '$0 start' first" >&2; exit 1; }
    START="$(cat "${STATE}")"
    # The folders that change all the time and are not saves (ROMs and artwork, caches, logs, the theme and system state, the profiles' own conf).
    b "ACTIVE=\$(cat /userdata/system/.batocera-profiles.current 2>/dev/null); echo \"active profile: [\${ACTIVE}] (empty = the main/default profile)\";
       if [ -n \"\${ACTIVE}\" ]; then P=/userdata/profiles/\${ACTIVE}; else P=/userdata/profiles/.default; fi
       NOW=\$(date +%s); MINS=\$(( (NOW - ${START}) / 60 + 2 ))
       echo \"looking at files written in the last \${MINS} minutes\"; echo
       LIST=\$(find /userdata -xdev \\( -path /userdata/roms -o -path /userdata/thumbnails -o -path /userdata/system/cache -o -path /userdata/system/logs \\
            -o -path /userdata/system/.cache -o -path /userdata/system/.local -o -path /userdata/system/.config/syncthing \\) -prune -o \\
            -type f -mmin -\${MINS} -print 2>/dev/null | sort)
       echo '== INSIDE the active profile (good):'; printf '%s\\n' \"\${LIST}\" | grep \"^\${P}/\" | sed 's/^/   /'
       echo; echo '== OUTSIDE the active profile (check each: a save or card here is shared by every profile; settings under /userdata/system/configs are fine):'
       printf '%s\\n' \"\${LIST}\" | grep -v \"^\${P}/\" | sed 's/^/   /'"
    ;;
  *) sed -n '2,15p' "$0"; exit 2 ;;
esac
