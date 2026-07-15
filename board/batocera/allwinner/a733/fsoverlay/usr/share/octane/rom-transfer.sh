#!/bin/sh
IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP="not connected — check WiFi settings"
HOSTNAME=$(cat /etc/hostname 2>/dev/null || echo "OctaneOS")

curl -s -X POST "http://localhost:1234/messagebox" \
    -H "Content-Type: text/plain" \
    -d "ROM Transfer

Web:  http://${IP}
SMB:  \\\\${HOSTNAME}
SSH:  root@${IP}
      password: linux

Drop ROMs into their system folder,
then restart EmulationStation." \
    2>/dev/null || true
