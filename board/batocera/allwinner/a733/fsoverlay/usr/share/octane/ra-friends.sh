#!/bin/sh
# OctaneOS — Friends Activity
# Shows recent achievements from people you follow on RetroAchievements.
# Credentials are read from batocera.conf — no extra sign-in needed.

BATOCERA_CONF="/userdata/system/batocera.conf"

get_conf() { grep "^$1=" "$BATOCERA_CONF" 2>/dev/null | cut -d= -f2-; }

show_msg() {
    curl -s -X POST "http://localhost:1234/messagebox" \
        -H "Content-Type: text/plain" -d "$1" 2>/dev/null || true
}

RA_USER=$(get_conf "global.retroachievements.username")
RA_KEY=$(get_conf "global.retroachievements.apikey")
[ -z "$RA_KEY" ] && RA_KEY=$(get_conf "global.retroachievements.password")

if [ -z "$RA_USER" ] || [ -z "$RA_KEY" ]; then
    show_msg "Friends Activity

Not signed in to RetroAchievements.
Go to Game Settings → RetroAchievements and enter your credentials."
    exit 0
fi

MSG=$(RA_API_KEY="$RA_KEY" python3 -c "
import os, json, urllib.request, sys, time

key = os.environ['RA_API_KEY']
base = 'https://retroachievements.org/API'
headers = {'User-Agent': 'OctaneOS/1.0'}

def get(url):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read())

try:
    following = get(base + '/API_GetUsersIFollow.php?y=' + key + '&c=50')
except Exception:
    print('Could not reach RetroAchievements.\nCheck your internet connection.')
    sys.exit(0)

if not isinstance(following, list) or not following:
    print('Friends Activity\n\nYou are not following anyone on RetroAchievements.\nVisit retroachievements.org to follow friends.')
    sys.exit(0)

lines = []
for user in following[:25]:
    uname = user.get('User', '')
    if not uname:
        continue
    try:
        achs = get(base + '/API_GetUserRecentAchievements.php?y=' + key + '&u=' + uname + '&m=120')
        for a in achs[:3]:
            game  = a.get('GameTitle', '?')
            title = a.get('Title', '?')
            pts   = a.get('Points', 0)
            lines.append(uname + ': ' + title + ' (' + game + ', ' + str(pts) + 'pts)')
    except Exception:
        pass
    time.sleep(0.2)

if lines:
    print('Friends Activity — last 2 hours\n')
    for line in lines[:15]:
        print(line)
else:
    print('Friends Activity\n\nNo activity from friends in the last 2 hours.')
" 2>/dev/null)

show_msg "${MSG:-Could not fetch friends activity. Check your connection.}"
