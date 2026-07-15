#!/bin/sh
# OctaneOS ROM Transfer — shows connection info for adding ROMs to this device.
# Launched from EmulationStation > Ports > ROM Transfer.

clear

IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP="(not connected — check WiFi settings)"

HOSTNAME=$(cat /etc/hostname 2>/dev/null || echo "OctaneOS")

TIMEOUT=30

printf '\n'
printf '  ╔══════════════════════════════════════════════════════╗\n'
printf '  ║              ROM TRANSFER — OctaneOS                ║\n'
printf '  ╚══════════════════════════════════════════════════════╝\n'
printf '\n'
printf '  Device IP:  %s\n' "$IP"
printf '\n'
printf '  ┌─────────────────────────────────────────────────────┐\n'
printf '  │  Web browser (drag & drop)                          │\n'
printf '  │  http://%s                            \n' "$IP"
printf '  │                                                     │\n'
printf '  │  Windows file explorer (SMB)                        │\n'
printf '  │  \\\\%s                                  \n' "$HOSTNAME"
printf '  │                                                     │\n'
printf '  │  SSH / SFTP                                         │\n'
printf '  │  root@%s   password: linux              \n' "$IP"
printf '  └─────────────────────────────────────────────────────┘\n'
printf '\n'
printf '  Drop ROMs into the folder for their system.\n'
printf '  Restart EmulationStation when done to scan for new games.\n'
printf '\n'

i=$TIMEOUT
while [ $i -gt 0 ]; do
    printf '\r  Closing in %2d seconds...' "$i"
    sleep 1
    i=$((i - 1))
done
printf '\n'
