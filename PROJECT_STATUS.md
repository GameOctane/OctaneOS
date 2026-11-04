---
phase: active
priority: high
category: hardware
progress: 50                     # share of docs/ROADMAP.md Part 1 (software, 6 steps): step 1 done; 2 (Syncthing) and 3 (profile v2) mostly done but not proven on a board; 4 (device password) designed, decided and coded, not run; 5 (Batocera rebase) trial rebase clean, not built; 6 (upstream PR) not started. Part 2 (wireless dock, handheld) not started and not counted. Jason to confirm.
focus: "A new test image (profile start-up setting + device password first-boot screen) is building; next is flashing it and testing profiles and the password on the board"
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
decision: "Flash the new test card image when home, then play-test each console. Release 0.8.3 only after the tests pass, with the profile and password work in it?"
if_go: "Claude checks the board (version, boot script, password helper, first-boot screen), runs scripts/trace-saves.sh per system, writes one evidence document (tested / by code only / not covered), then opens a release/0.8.3 PR. Jason still does the signed publish and the on-device OTA test."
status_verified: "2026-11-04 from git history, local branches and tests run in scratch folders (profiles 49, device password 23, ES patches 14 pass). Nothing from the local branches has run on a board; the image build was still running when this was written."
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

## Written locally, not pushed, not run on a board
Branches `feat/profile-boot-setting` and `feat/device-password` (both have current main merged in) are combined in the local `test/integration-1104b`, which a test image is being built from (dev key, never to be released).
- **START IN PROFILE setting** (last one used / always the main profile) with a boot script `S14octane-profile`. The menu entry has not been seen on a screen.
- **Save audit fixes:** DuckStation memory cards and save states, and Game Boy link-cable saves, now follow the profile.
- **`scripts/trace-saves.sh`, `docs/profiles-testing.md`, `docs/profiles-downgrade.md`:** which files a play session wrote, and how to go back to an older version after profiles.
- **Device password:** `S35securepasswd` override (SHA-512, a Samba password that survives `%` and `\`, a `reset-password` file on the boot partition), the `octane-device-password` helper, and an EmulationStation first-boot question plus a Security menu entry (patch 0004). Tested only in scratch folders; the ES file was syntax-checked against stub headers, never compiled with the real ES. Not yet checked on the board: the encryption key (CPU serial and ethernet MAC), the SHA-512 hash being accepted, remounting `/boot`.
- **Video engine note** (`docs/video-engine-note`): libcedarc 2.0.0, license unknown. Radxa was emailed 2026-11-04.

## Next up
- [ ] **Flash the new test image and test each console** (NES, SNES, GB/GBC/GBA, Mega Drive, N64, DS, PlayStation incl. memory cards, PSP, Dreamcast, arcade incl. high scores, DOSBox Pure, ScummVM, Amiga, Game Boy link). Also test the boot setting, a default-profile rename and Amiga adoption (the last two were never device-tested)
- [ ] Open PRs for `feat/profile-boot-setting` and `feat/device-password` once the board tests pass, then **release 0.8.3** with them and the login fix (#36)
- [ ] Refresh Batocera PR #2207 (the maintainer's points are in an earlier chat and answered in our design: no symlinks, per-profile saves, safe migration, downgrade notes; the start-up setting and per-console evidence are still needed); then refresh it with the Syncthing result, the profile indicator and the per-console test evidence
- [ ] Syncthing: two-way sync of real saves and other profiles' saves folders (the one-way how-to page is in `docs/syncing-saves.md`)
- [ ] Device password: test on the board; Syncthing's page password; fix the profile-rename shell quoting in ES (a quote in a name breaks the command)
- [ ] Rebase onto Batocera v43.1 (51 commits): a trial rebase of our 34 Batocera commits and 6 ES commits is clean with the ES patches still applying; not built or tested. Do it after the profile tests pass
- [ ] Profile PIN (optional, design first); two players at once is a stretch and not wanted for now
- [ ] Wireless dock / handheld research (streaming latency, DPI screen, power, heat): Part 2 of the roadmap
- [ ] Video encoder (Cedar) is parked until Radxa names a license contact (libcedarc 2.0.0, no license file shipped)
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
When the build in `/srv/data/octaneos-work/run-integration-build.log` finishes: verify the image (`scripts/check-image.sh`, strings in the ES binary, the S35 script and helper in the target), then make a flash script like `flash-test-card-1104.sh`. Jason flashes the test card (`sudo`), boots it, and tells Claude; then follow `docs/profiles-testing.md` plus the password checks on the board. Keep the local branches unpushed until Jason says to push.

## Last session
2026-11-04: merged the status, spelling and Syncthing PRs; wrote the downgrade notes, the device password research and decision (keep Batocera's storage, SHA-512 for SSH), the device password code and first-boot screen, a clean trial rebase onto Batocera v43.1, and a status automation (CI check + Stop hook). #41 (password findings) is open. A new test image was building at the end. Nothing new has been run on a board.
