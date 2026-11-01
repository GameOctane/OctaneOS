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
key that does not match the username). Creating a profile copies the current account, key included; if the new profile uses a different
RetroAchievements account, enter that account's key in the settings screen.

## Where it lives in the code
- `board/batocera/allwinner/a733/es-patches/0001-retroachievements-per-player-web-api-key.patch`: the EmulationStation change (the
  setting, the `WEB API KEY` row, using `z=<username>&y=<key>` in the Web API calls, and making the feature available without the
  built-in key). `scripts/apply-es-patches.sh` applies it to the ES source on every build; a patch that stops applying stops the build.
- `board/batocera/allwinner/a733/fsoverlay/usr/bin/batocera-profiles`: the per-profile `apikey=` field.
- `scripts/check-image.sh` fails an image whose EmulationStation does not know the setting (a stale build).
- Tests: `scripts/test-profiles.sh`, `scripts/test-es-patches.sh`.

## Status
Written and unit-tested; **not yet run in a built image on a device**. The first build after this change is the first real test: enter a key,
open the RetroAchievements page in the menu, and check the home screen for the RetroAchievements entry. If the site's answer to a valid key
is something other than the user summary, the log of EmulationStation (debug mode) will show it.

## The project's own keys (developer logins)
Batocera's builds compile in developer logins for ScreenScraper and RetroAchievements; ours has none unless `keys.txt` is created, so by default
there is no ScreenScraper scraping and the RetroAchievements pages need the player's own key (above).

`batocera/package/batocera/emulationstation/batocera-emulationstation/keys.txt` (gitignored; never commit it, never paste it anywhere) is read
by the package recipe at build time:
```
SCREENSCRAPER_DEV_LOGIN=devid=<devid>&devpassword=<devpassword>
CHEEVOS_DEV_LOGIN=z=<project account>&y=<project Web API key>
```
Whatever is in it is compiled into the program, and anyone can read it back out of a downloaded image with a text search. So:
- **ScreenScraper dev login:** meant to be embedded in software; fine in a release.
- **RetroAchievements key:** an account credential. For test images only. `scripts/check-image.sh --release` FAILS an image that contains it, unless
  you build with `OCTANE_ALLOW_SHARED_RA_KEY=1` after deciding, with RetroAchievements' agreement, to ship a shared key.
- A player's own key (set in the menu) is always used first, so a revoked project key never breaks players who set their own.
- `scripts/check-embedded-keys.sh` does the checking, prints key names only (never values), and also fails a stale build (a key in `keys.txt` that the built
  EmulationStation does not contain: rebuild `batocera-emulationstation`).
- Keep a copy of `keys.txt` in a password manager. Do not store it with the update-signing keys.
