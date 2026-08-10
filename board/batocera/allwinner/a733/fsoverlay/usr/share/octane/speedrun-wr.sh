#!/bin/sh
# OctaneOS — Speedrun WR Update
# Looks up the Any% world record for each scraped game and appends it to
# the game description in gamelist.xml. Results are cached so re-runs only
# fetch new games. Safe to run multiple times.

show_msg() {
    curl -s -X POST "http://localhost:1234/messagebox" \
        -H "Content-Type: text/plain" -d "$1" 2>/dev/null || true
}

show_msg "Speedrun WR Update

Scanning your library and fetching world records...
This may take a few minutes for large collections."

MSG=$(python3 -c "
import json, urllib.request, urllib.parse, sys, os, time
import xml.etree.ElementTree as ET

ROMS_DIR  = '/userdata/roms'
CACHE_FILE = '/userdata/system/speedrun-wr-cache.json'

def api_get(url):
    req = urllib.request.Request(url, headers={
        'User-Agent': 'OctaneOS/1.0',
        'Accept': 'application/json'
    })
    with urllib.request.urlopen(req, timeout=10) as r:
        if r.status == 420:
            time.sleep(60)
            return api_get(url)
        return json.loads(r.read())

def format_time(seconds):
    s = int(float(seconds))
    h, rem = divmod(s, 3600)
    m, s   = divmod(rem, 60)
    return (str(h) + ':' + str(m).zfill(2) + ':' + str(s).zfill(2)) if h else (str(m) + ':' + str(s).zfill(2))

def get_wr(title):
    q = urllib.parse.quote(title)
    data = api_get('https://www.speedrun.com/api/v1/games?name=' + q + '&max=1&_bulk=yes')
    games = data.get('data', [])
    if not games:
        return None
    game_id   = games[0]['id']

    cats = api_get('https://www.speedrun.com/api/v1/games/' + game_id + '/categories')
    time.sleep(0.3)
    target = None
    for cat in cats.get('data', []):
        if cat.get('type') != 'per-game':
            continue
        name = cat.get('name', '').lower()
        if 'any' in name:
            target = cat
            break
    if not target:
        for cat in cats.get('data', []):
            if cat.get('type') == 'per-game':
                target = cat
                break
    if not target:
        return None

    lb = api_get('https://www.speedrun.com/api/v1/leaderboards/' + game_id + '/category/' + target['id'] + '?top=1&embed=players')
    time.sleep(0.3)
    runs = lb.get('data', {}).get('runs', [])
    if not runs:
        return None

    t = runs[0]['run'].get('times', {}).get('primary_t')
    if not t:
        return None

    players = lb.get('data', {}).get('players', {}).get('data', [])
    runner = '?'
    if players:
        p = players[0]
        if p.get('rel') == 'user':
            runner = p.get('names', {}).get('international', '?')
        elif p.get('rel') == 'guest':
            runner = p.get('name', '?')

    return {'time': format_time(t), 'runner': runner, 'category': target['name']}

# Load cache
cache = {}
if os.path.exists(CACHE_FILE):
    try:
        with open(CACHE_FILE) as f:
            cache = json.load(f)
    except Exception:
        pass

updated = 0
skipped = 0
not_found = 0

for system in sorted(os.listdir(ROMS_DIR)):
    gamelist = os.path.join(ROMS_DIR, system, 'gamelist.xml')
    if not os.path.exists(gamelist):
        continue
    try:
        ET.register_namespace('', '')
        tree = ET.parse(gamelist)
        root = tree.getroot()
    except Exception:
        continue

    changed = False
    for game in root.findall('game'):
        name_el = game.find('name')
        if name_el is None or not (name_el.text or '').strip():
            continue
        title = name_el.text.strip()

        desc_el = game.find('desc')
        if desc_el is not None and desc_el.text and 'Speedrun WR:' in desc_el.text:
            skipped += 1
            continue

        wr = cache.get(title)
        if wr is None:
            try:
                wr = get_wr(title)
                cache[title] = wr if wr else False
                time.sleep(0.4)
            except Exception:
                not_found += 1
                cache[title] = False
                continue

        if not wr:
            not_found += 1
            continue

        wr_str = 'Speedrun WR: ' + wr['time'] + ' by ' + wr['runner'] + ' (' + wr['category'] + ')'
        if desc_el is None:
            desc_el = ET.SubElement(game, 'desc')
            desc_el.text = wr_str
        else:
            desc_el.text = (desc_el.text or '').rstrip() + '\n\n' + wr_str

        updated += 1
        changed = True

    if changed:
        tree.write(gamelist, encoding='unicode', xml_declaration=True)

try:
    with open(CACHE_FILE, 'w') as f:
        json.dump(cache, f)
except Exception:
    pass

print('Speedrun WR Update\n')
print('Updated:   ' + str(updated) + ' games')
print('Skipped:   ' + str(skipped) + ' (already have WR)')
print('Not found: ' + str(not_found))
print('\nRe-scrape games in ES to refresh the detail panel.')
" 2>/dev/null)

show_msg "${MSG:-Speedrun WR update failed. Check your connection.}"
