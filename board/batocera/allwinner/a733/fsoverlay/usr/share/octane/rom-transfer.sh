#!/bin/sh
# OctaneOS ROM Transfer — displays connection info via ES popup.
# Launched from EmulationStation > Ports > ROM Transfer.
# Uses ES's built-in messagebox API — no terminal emulator needed,
# dismissable with any controller button.

IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP="not connected — check WiFi settings"

HOSTNAME=$(cat /etc/hostname 2>/dev/null || echo "OctaneOS")

MSG="Web:  http://${IP}
SMB:  \\\\${HOSTNAME}
SSH:  root@${IP}
      password: linux

Drop ROMs into their system folder,
then restart EmulationStation."

curl -s "http://localhost:1234/messagebox" \
    --data-urlencode "title=ROM Transfer" \
    --data-urlencode "message=${MSG}" \
    2>/dev/null || true
