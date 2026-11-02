# Scraping (game art and information) on OctaneOS

Scraping downloads cover art, videos, manuals and descriptions for your games from **ScreenScraper** (screenscraper.fr), a free community
database. It is started from the menu (**Scraper**), for all games or for a single game from its own menu.

## What needs to be set up
Nothing. OctaneOS releases carry the project's ScreenScraper **developer login** inside EmulationStation. That login identifies the *program*
to ScreenScraper (like a name badge for the software); it is not a user account and it does not give anyone's games or data away. Without it
the scraping code is not even built in, which is why OctaneOS builds before 0.8.1 had no ScreenScraper scraping.

Scraping without any account of your own was tested on a device (image, video and manual were all downloaded).

## Your own ScreenScraper account (optional)
You can create a free account at screenscraper.fr and enter its username and password under the scraper settings. EmulationStation sends
your account with each request only when **both** the username and the password are filled in; with only one of them it scrapes anonymously.

What an account changes (limits, speed) is decided by ScreenScraper, not by OctaneOS. We have not measured it, so this page makes no claim
about quotas. Check ScreenScraper's own pages for the current rules.

## For maintainers: how the login gets into a build
- Batocera's EmulationStation package reads a file named `keys.txt` next to its recipe
  (`batocera/package/batocera/emulationstation/batocera-emulationstation/`). It is gitignored: **never commit it**.
- The line is `SCREENSCRAPER_DEV_LOGIN=devid=<id>&devpassword=<password>` (characters like `&`, `=` in the values must be percent-encoded).
- Buildroot does not notice a changed `keys.txt`: run `batocera-emulationstation-reconfigure` before the build.
- `scripts/check-embedded-keys.sh` (run by `scripts/check-image.sh`) compares `keys.txt` with the built program, printing key **names only**.
  A ScreenScraper login in a release is allowed. The project's RetroAchievements key is not (see `docs/retroachievements.md`).
- Keep a copy of `keys.txt` in a password manager. It is not stored on the build server's repository, GitHub or the images' source.
- A test image built with a dev SSH key must never be released, whatever else it contains.

## Known gaps
- The daily limits for anonymous scraping are unmeasured. If you hit a limit, adding your own account is the first thing to try.
- Whether a player account is actually used by this build was not confirmed on 2026-11-02 (the account's profile statistics did not change
  that day, which may just be a delay on the website). Treat it as unverified until checked.
