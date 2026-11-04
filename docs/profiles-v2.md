# Profiles v2: design notes (draft)

**Status:** draft, 2026-11-02. Builds on `docs/batocera-profiles-spec-v0.1.md` (v1: RetroAchievements login, saves and save states per
profile, console-style switching without a password). Nothing here is built unless it says so.

## Who it is for
A family or a group sharing one device (for example three children and a parent: about four profiles), and one person with several
devices. Every profile sees every game; hiding games per profile may come later if people ask. Achievements: RetroArch signs in to
RetroAchievements with one account per session, so two accounts cannot earn on the same game; profiles stay separate.

## 1. Knowing who is playing (first)
- **Menu footer** and **start-up message** ("PROFILE: <name>"): built as ES patch 0002, compiles, not yet seen on a screen.
- **Badge:** an always-on label, opt-in setting, drawn by ES with its own semi-transparent background so it is readable on any theme;
  the player chooses the corner, off by default on small screens. A theme may position and style it with a "profile name" element.
  (In the Carbon theme: controller icons top left, Wi-Fi and battery top right, clock bottom right, button prompts along the bottom.)
- **Avatars later:** a local image in the profile folder, or the player's RetroAchievements picture (EmulationStation already shows it on
  the RA page; fetch once and cache it).
- **On boot (built):** the active profile is stored in `/userdata/system/.batocera-profiles.current`. The setting **START IN PROFILE** on the
  PROFILES screen (stored as `profiles.boot` in `batocera.conf`) chooses what happens when the device starts: `last` (the default, as before:
  the profile that was in use stays in use) or `main` (the boot script `S14octane-profile` switches back to the main profile, loading its
  RetroAchievements login as a normal switch does). "Ask who is playing" is not built yet: it needs a picker shown by EmulationStation at
  start-up.

## 2. Optional PIN (convenience, not security)
- Per profile, optional. It guards **switching into** a profile and **deleting** one, so nobody plays or deletes as someone else by accident.
- Entered with controller input like a console. Two ways, chosen per profile:
  - **Number pad:** a small grid of digits moved with the D-pad, A on each digit, 4 digits, shown as dots (the PS5 way).
  - **Button sequence:** a short run of controller buttons (for example Up, Up, A, B), with no screen keyboard needed; good for cabinets
    with only a joystick and buttons. Shown as dots too, one per press.
  Touch is not relied on.
- A short delay after a few wrong tries. A forgotten PIN is reset from the main profile or by a file on the boot partition.
- Store only a hash of the PIN. It does **not** protect against someone who has the SD card (nothing on the card is encrypted: the
  RetroAchievements password, the Wi-Fi password and the ScreenScraper login are readable) or who can reach SSH while the login is
  still `root` / `linux`. If a device is lost, treat its credentials as exposed: reset the RetroAchievements key and password, the
  Wi-Fi password and the ScreenScraper password.

## 3. Saves that bypass the profile folder (audit)
Audit of 2026-11-03, **from reading the configgen code and the list of packages in the image, not by running each emulator**.
`batoceraPaths.SAVES` follows the active profile; an emulator is per-profile when its generator builds its save paths from it.
- **In the image, fixed:** Amiberry (Amiga, 0.8.2); DuckStation (PlayStation memory cards and states were the relative path
  `../../../saves/duckstation`, always the shared folder); Game Boy link cable `gb2players` / `gbc2players` (copied saves in from the profile
  folder but its exit script copied them back to the fixed `/userdata/saves`). Both of the last two: configgen patch 0002.
- **In the image, per-profile already:** mupen64plus, Flycast (Dreamcast), standalone MAME, PPSSPP, melonDS, ScummVM, EDuke32, Raze,
  Cannonball, EasyRPG, DevilutionX, Xash3D, TheXTech, ECWolf, FS-UAE, and every RetroArch core that honours RetroArch's save and state
  folders (those two are set per profile).
- **Not audited:** libretro cores that ignore RetroArch's folders and write to their own path (for example DOSBox Pure, the ScummVM and
  libretro MAME cores). Needs a run on the board per core, or a look at each core's source.
- **Hard-coded fixed path, not in the image (matters only if added later):** shadps4, demul, Ymir (Saturn), xemu.
- The earlier note that Saturn, Dreamcast and parts of MAME write outside the profile folders did not hold up for what is in the image:
  Dreamcast (Flycast) and standalone MAME follow the profile, and Saturn here is the YabaSanshiro libretro core. PS2 and Dolphin standalone
  are not in the image.
**High scores:** the MAME core in the image (2003-Plus) keeps them in a `hi` folder inside the RetroArch save folder, so they are per-profile
today. Keep that for now; a "share arcade high scores" setting (per profile) would link `hi` to a common folder.

## 4. Per-profile settings and data
- **Settings:** ScreenScraper account per profile (next to the RetroAchievements one); language, music and netplay logins only if asked.
- **Game data:** playtime, play count, last played, favorites and "recently played" per profile (today the game lists are shared).
- **Managing profiles:** back up / export a profile to one file and import it elsewhere; a guest profile; archive instead of deleting.

## 5. Later
Kids mode and admin/standard permissions, per-profile controller mappings, two people at once on one game, and sync polish
(see `docs/security-design-phase1.md` phase 3 and the Syncthing test results).
