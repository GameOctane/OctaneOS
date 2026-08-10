#!/bin/sh
# OctaneOS — Today's Completions
# Shows recent game masteries and completions from the RetroAchievements community.

BATOCERA_CONF="/userdata/system/batocera.conf"

get_conf() { grep "^$1=" "$BATOCERA_CONF" 2>/dev/null | cut -d= -f2-; }

show_msg() {
    curl -s -X POST "http://localhost:1234/messagebox" \
        -H "Content-Type: text/plain" -d "$1" 2>/dev/null || true
}

RA_KEY=$(get_conf "global.retroachievements.apikey")
[ -z "$RA_KEY" ] && RA_KEY=$(get_conf "global.retroachievements.password")

if [ -z "$RA_KEY" ]; then
    show_msg "Today's Completions

Not signed in to RetroAchievements.
Go to Game Settings → RetroAchievements and enter your credentials."
    exit 0
fi

MSG=$(RA_API_KEY="$RA_KEY" python3 -c "
import os, json, urllib.request, sys

key = os.environ['RA_API_KEY']
base = 'https://retroachievements.org/API'
headers = {'User-Agent': 'OctaneOS/1.0'}

def get(url):
    req = urllib.request.Request(url, headers=headers)
    with urllib.request.urlopen(req, timeout=8) as r:
        return json.loads(r.read())

try:
    data = get(base + '/API_GetRecentGameAwards.php?y=' + key + '&c=25')
except Exception:
    print('Could not reach RetroAchievements.\nCheck your internet connection.')
    sys.exit(0)

results = data.get('Results', []) if isinstance(data, dict) else []
if not results:
    print('Today\\'s Completions\n\nNo recent completions found.')
    sys.exit(0)

labels = {
    'mastered':          'mastered',
    'completed':         'completed',
    'beaten-hardcore':   'beat (hardcore)',
    'beaten-softcore':   'beat',
}

lines = []
for r in results[:20]:
    user  = r.get('User', '?')
    game  = r.get('Title', '?')
    kind  = labels.get(r.get('AwardKind', ''), r.get('AwardKind', ''))
    lines.append(user + ' ' + kind + ' ' + game)

if lines:
    print('Today\\'s Completions\n')
    for line in lines:
        print(line)
else:
    print('Today\\'s Completions\n\nNo recent completions found.')
" 2>/dev/null)

show_msg "${MSG:-Could not fetch completions. Check your connection.}"
