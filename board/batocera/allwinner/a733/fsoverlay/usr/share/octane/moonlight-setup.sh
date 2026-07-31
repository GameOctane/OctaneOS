#!/bin/sh
# Moonlight PC Streaming setup guide — displayed as an ES messagebox popup.
# Paired with the Moonlight system already built into OctaneOS.
IP=$(ip -4 addr show scope global | awk '/inet / {print $2}' | cut -d/ -f1 | head -1)
[ -z "$IP" ] && IP="not connected — check WiFi settings"

curl -s -X POST "http://localhost:1234/messagebox" \
    -H "Content-Type: text/plain" \
    -d "Moonlight — PC Streaming Setup

Stream games from your PC to OctaneOS.

Step 1: Install Sunshine on your PC
  sunshine.app (free, works with any GPU)
  Open Sunshine web UI at https://localhost:47990

Step 2: Pair from OctaneOS
  SSH into OctaneOS:
    root@${IP}   password: linux

  Then run:
    batocera-moonlight pair <your-PC-IP>
  Accept the PIN in Sunshine.

Step 3: Sync your game list
    batocera-moonlight sync <your-PC-IP>

Step 4: Launch
  The Moonlight system now appears in ES.
  Select any game to start streaming." \
    2>/dev/null || true
