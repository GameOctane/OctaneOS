# RetroAchievements on OctaneOS

Two different things use RetroAchievements, and they sign in differently. That is why the achievements can work in a game while the menus say
"Unauthorized".

| What | Where | Signs in with |
|---|---|---|
| **Earning achievements in a game** | RetroArch | your username and password (it gets its own login token) |
| **The RetroAchievements pages in the menu and the home-screen entry** (your points, recent games, progress) | EmulationStation | RetroAchievements' **Web API**, which needs a **Web API key** |

## Why the menu said "Unauthorized"
Batocera's official builds compile in the project's own private Web API key. A community build such as this one has none, so the Web API
answers **HTTP 401 "Unauthenticated"** and the menu shows "Unauthorized" (the home-screen entry is not offered either, because the
statistics behind it cannot be fetched). Your password, your login token and your profiles were never the problem. We checked: the login token
is **not** accepted as a Web API key (401 as well).

## What to do (once per RetroAchievements account)
1. On retroachievements.org: **Settings** > **Keys** > copy your **Web API Key**. (It is free and belongs to your account. Treat it like a
   password: do not post it.)
2. On the device: **Game settings** > **RetroAchievement settings** > **WEB API KEY**, type it in, and leave the screen.
   (Or put `global.retroachievements.apikey=<your key>` in `batocera.conf`.)

The key is stored with the other RetroAchievements settings, which the file share hides from guests (the `system` folder and the
`retroachievements.conf` files are not visible over the network). It is kept in plain text, like the password.

## Several profiles
Each profile has its own RetroAchievements account, and the key belongs to the account, so `batocera-profiles` saves and loads it together
with the username: switching profile switches the key. A profile without a key clears the previous profile's key (the site would reject a
key that does not match the username). A new profile starts with no login at all (nothing is copied from the profile that created it) and with RetroAchievements left
switched on; the player enters their own username, password and key in the settings screen. Switching to a profile without a
login also clears the previous player's login, so one player's achievements are never credited to another.

## Where it lives in the code
- `board/batocera/allwinner/a733/es-patches/0001-retroachievements-per-player-web-api-key.patch`: the EmulationStation change (the
  setting, the `WEB API KEY` row, using `z=<username>&y=<key>` in the Web API calls, and making the feature available without the
  built-in key). `scripts/apply-es-patches.sh` applies it to the ES source on every build; a patch that stops applying stops the build.
- `board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-profiles`: the per-profile `apikey=` field.
- `scripts/check-image.sh` fails an image whose EmulationStation does not know the setting (a stale build).
- Tests: `scripts/test-profiles.sh`, `scripts/test-es-patches.sh`.

## Status
Verified on a device (2026-11-01, a fresh install of 0.8.1-pre): after the player's own Web API key was entered and the device restarted, the
RetroAchievements entry appeared in the main menu and its page loaded the player's data. Earning achievements in a game was never affected.
If the site's answer to a valid key is something other than the user summary, the log of EmulationStation (debug mode) will show it, but see
the warning in `docs/releasing.md` first: that log can contain the login token in clear.
