---
phase: active
priority: high
category: hardware
progress: 45                     # share of docs/ROADMAP.md Part 1 (software, 6 steps) done: step 1 done, steps 2 and 3 mostly done but not fully proven, steps 4-6 not started. Part 2 (wireless dock, handheld) is not started and is not counted. Jason to confirm.
focus: "Proving profiles v2 on the test card: start-up profile setting and the save audit are written and built, not yet run on a board"
next_milestone: "Roadmap Part 1 (software) finished: profiles v2 proven per console, device password, Batocera v43.1 rebase, Batocera PR refreshed"
milestone_distance: weeks
community_pressure: high
excitement: high                 # was 'very high'; Mission-Control's scoring only knows high/medium/low
strategic: true
momentum: rolling                # scoring only knows rolling/steady/blocked/stalled
audience: diy-retro-gaming-builders
uniqueness: first-mover
viral_potential: high
mvp_distance: weeks
waiting_on: jason                # jason / claude / external / none
decision: "Flash the test card and play-test each console (needs your sudo and games), then cut 0.8.3 with everything that passed, instead of releasing the one-line login fix alone?"
if_go: "Claude runs scripts/trace-saves.sh per system, writes the results into one evidence document (tested / by code only / not covered), then opens a release/0.8.3 PR. Jason still does the signed publish and the on-device OTA test."
status_verified: "2026-11-04 from git history, the local feat/profile-boot-setting branch and a built test image (check-image passed). Nothing from that branch has run on a board yet."
---

## Why this exists
A $150 weekend build that anyone can make, own completely, and runs every retro game — open source from silicon to firmware.

## Strategic picture
OctaneOS is the foundation everything else in GameOctane sits on. It is no longer a bring-up project: it ships signed over-the-air updates (0.8.0+), RetroAchievements out of the box, per-player profiles with their own saves and logins, fan support, and working audio. Profiles are proposed upstream as batocera-emulationstation#2207 (open; the maintainers' comments have not been reviewed here yet). The next big unknown is the wireless dock and handheld (Part 2 of docs/ROADMAP.md); software work in Part 1 comes first.

## Shipped since the last status (v0.5.7 → v0.8.2)
- **Audio:** fixed. 0.8.1 release notes record sound normal in the OTA test.
- **OTA updates with signature checking** (0.8.0): real update-signing keys, signed manifests, version file read by devices.
- **RetroAchievements:** per-profile Web API key; release check refuses to ship the project's own key (0.8.1).
- **Profiles:** switch / create / delete from the menu, own saves and states, profile name shown on screen, Amiga saves follow the profile, safe first-switch migration (rename, not delete) (0.8.2).
- **On main, not yet released:** a new profile starts with no RetroAchievements login and keeps the name typed (PR #36).
- **Syncthing, one-way test (2026-11-03):** the board's saves folder syncs to a server; delete and conflict behaviour and a profile switch were tested on the real card. Two-way sync and other profiles' folders are untested.
- **Hardware:** PWM fan support, real EDID, DS vsync fix (the real cause of the audio warble), 30-pin header + fan bracket docs.
- **Release tooling:** secret guard and release-consistency CI checks, publish-release preflight and checklist.

## Written locally, not pushed, not yet run on a board (branch `feat/profile-boot-setting`)
- **START IN PROFILE setting** (last one used / always the main profile) with a boot script `S14octane-profile`. In the built image; the menu entry has not been seen on a screen.
- **Save audit fixes:** DuckStation memory cards and save states, and Game Boy link-cable saves, now follow the profile.
- **`scripts/trace-saves.sh` and `docs/profiles-testing.md`:** show which files a play session wrote and whether they went into the active profile's folder.
- A dev-key test image is built (never to be released). It needs flashing to the test card by Jason.

## Next up
- [ ] **Flash the test card and test each console** (NES, SNES, GB/GBC/GBA, Mega Drive, N64, DS, PlayStation incl. memory cards, PSP, Dreamcast, arcade incl. high scores, DOSBox Pure, ScummVM, Amiga, Game Boy link). Also test the boot setting, a default-profile rename and Amiga adoption (the last two were never device-tested)
- [ ] Open a PR for `feat/profile-boot-setting` once the tests pass, then **release 0.8.3** with it and the login fix (#36)
- [ ] Review the Batocera maintainers' comments on #2207, then refresh it with the Syncthing result, the profile indicator and the per-console test evidence
- [ ] Syncthing: two-way sync of real saves, other profiles' saves folders, a "how to sync" page (sync only `saves` and `states`, never the whole profile folder)
- [ ] Device password (first-boot screen, `docs/security-design-phase1.md` phase 2)
- [ ] Rebase onto Batocera v43.1 (51 commits behind as of the roadmap; our base is the 2026-04-06 snapshot)
- [ ] Profile PIN (optional, design first); two players at once is a stretch and not wanted for now
- [ ] Wireless dock / handheld research (streaming latency, DPI screen, power, heat): Part 2 of the roadmap
- [ ] Video encoder (Cedar) is parked until Radxa names a licence contact (libcedarc 2.0.0, no licence file shipped)
- [ ] GameOctane companion app integration and the three-mode system (handheld / docked / streaming): carried over from the old list, not in the roadmap

## Decisions for the maintainer (from the roadmap)
- Release 0.8.3 after the console tests, or earlier? (the one in `decision` above)
- MAME high scores: shared by everyone, or per profile?
- RetroAchievements logins and keys: leave out of any sync, or use encrypted folders?
- Which receiver board to buy first, and what to run on the first test hardware.

## Ideas / Backlog
- **Chiaki — PS4/PS5 Remote Play** — Chiaki is an open-source Remote Play client for Linux with ARM support. Would let Octane stream PS4/PS5 games directly from a console on the local network. Touch screen on the Octane could map to PS4/PS5 touchpad input. Batocera has a chiaki package worth evaluating for aarch64 compatibility.
- **Steam Link** — Valve's official ARM Linux Steam Link client streams any Steam game from a PC on the local network. Batocera ships a steamlink package; needs evaluation for aarch64. Zero PC-side setup beyond enabling Remote Play in Steam.
- **Second-screen achievement companion** — pair OctaneOS over local WiFi with a running [Achievement Scavenger](https://github.com/batureren/achievement-scavenger) instance on the player's PC/console setup. Scavenger already knows what game just launched on Steam/PSN/Xbox and holds valid platform sessions; OctaneOS acts as a lightweight display client showing live missable-item warnings, hints, and progress while you play on another platform. RetroAchievements is already covered natively on-device — this extends the same idea to non-emulated platforms. Idea credit + concept borrowed with permission from Batu Ozdogan ([@batureren](https://github.com/batureren)), author of Achievement Scavenger. Needs: pairing/discovery protocol, a small local API on Scavenger's side (author receptive to adding one), and an OctaneOS-side display client.


## Blockers
- GameCube/Wii games do not start (GPU driver; standalone Dolphin not in the image, libretro core stalls). Revisit when the open GPU driver matures.
- Some units switch off under heavy load with no heatsink (#11). Needs an answer before a case is sealed.
- Picture can stay black after a monitor is switched off and on.
- Wireless dock: glass-to-glass latency estimated 55-65 ms against a 33 ms target; not met yet.

## Resume here
Jason flashes the test card: `sudo bash /srv/data/octaneos-work/flash-test-card-1104.sh /dev/sdc` (confirm it is the test card first). Then boot the board and follow `docs/profiles-testing.md` on the `feat/profile-boot-setting` branch (`scripts/trace-saves.sh start` / `report` per game). Keep that branch local until Jason says to push.

## Last session
2026-11-04: 0.8.2 announced and merged; PR #36 (new profile has no login) merged; Syncthing one-way saves backup working on the main card and server; start-up profile setting, DuckStation and Game Boy link save fixes written and built into a test image (verified in the image, not run on a board). `progress` is now 45, defined as the share of roadmap Part 1; the earlier 90 was a guess.
