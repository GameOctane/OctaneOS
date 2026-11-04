---
phase: active
priority: high
category: hardware
progress: 90                     # estimate toward next_milestone; Jason to confirm
focus: "Profiles v2 shipped in 0.8.2; login-isolation fix is on main but unreleased"
next_milestone: "0.8.3 release (new-profile login fix), then Syncthing verified with profiles"
milestone_distance: days
community_pressure: high
excitement: high                 # was 'very high'; Mission-Control's scoring only knows high/medium/low
strategic: true
momentum: rolling                # was 'accelerating'; scoring only knows rolling/steady/blocked/stalled
audience: diy-retro-gaming-builders
uniqueness: first-mover
viral_potential: high
mvp_distance: weeks
waiting_on: jason                # jason / claude / external / none
decision: "Cut 0.8.3 now (just the new-profile login fix), or batch it with Syncthing / the Batocera v43.1 rebase?"
if_go: "Claude opens a release/0.8.3 PR: version bump, release notes from docs/release-notes-template.md, runs scripts/check-release-consistency.sh. Jason still does the signed publish and the on-device OTA test."
status_verified: "2026-11-04 from git history and docs/ROADMAP.md; hardware state not re-tested"
---

## Why this exists
A $150 weekend build that anyone can make, own completely, and runs every retro game — open source from silicon to firmware.

## Strategic picture
OctaneOS is the foundation everything else in GameOctane sits on. It is no longer a bring-up project: it ships signed over-the-air updates (0.8.0+), RetroAchievements out of the box, per-player profiles with their own saves and logins, fan support, and working audio. Profiles are proposed upstream as batocera-emulationstation#2207 (open, no maintainer review yet). The next big unknown is the wireless dock and handheld (Part 2 of docs/ROADMAP.md); software work in Part 1 comes first.

## Shipped since the last status (v0.5.7 → v0.8.2)
- **Audio:** fixed. 0.8.1 release notes record sound normal in the OTA test.
- **OTA updates with signature checking** (0.8.0): real update-signing keys, signed manifests, version file read by devices.
- **RetroAchievements:** per-profile Web API key; release check refuses to ship the project's own key (0.8.1).
- **Profiles:** switch / create / delete from the menu, own saves and states, profile name shown on screen, Amiga saves follow the profile, safe first-switch migration (rename, not delete) (0.8.2).
- **Hardware:** PWM fan support, real EDID, DS vsync fix (the real cause of the audio warble), 30-pin header + fan bracket docs.
- **Release tooling:** secret guard and release-consistency CI checks, publish-release preflight and checklist.

## Next up
- [ ] **Release 0.8.3** — the new-profile login fix (PR #36) is merged to main after the 0.8.2 tag
- [ ] Syncthing verified on the board, then with profiles (sync only `saves` and `states`, never the whole profile folder)
- [ ] Profile v2 remainder — emulators that write saves outside the profile folder (parts of MAME, Saturn, Dreamcast, PS2); MAME high scores
- [ ] Device password (first-boot screen, `docs/security-design-phase1.md` phase 2)
- [ ] Rebase onto Batocera v43.1 (51 commits behind; our base is the 2026-04-06 snapshot)
- [ ] Refresh the Batocera PR (#2207) with Syncthing result and the current-profile indicator
- [ ] Wireless dock / handheld research (streaming latency, DPI screen, power, heat) — Part 2 of the roadmap
- [ ] 0.8.2 not yet device-tested: Amiga saves following the profile, renaming the default profile
- [ ] GameOctane companion app integration and the three-mode system (handheld / docked / streaming) — carried over from the old list, not in the roadmap

## Decisions for the maintainer (from the roadmap)
- Release 0.8.3 now, or batch? (the one in `decision` above)
- Ask for a profile at boot, or only in the menu?
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
Start with `git log v0.8.2..main` — the login-isolation fix is merged but unreleased. If releasing: follow `docs/releasing.md`, then run `scripts/check-release-consistency.sh`. If not: Syncthing step 1 (does it run on the board and does its page load) is next in `docs/ROADMAP.md`.

## Last session
2026-11-04: Status file rewritten by Claude from git history and docs/ROADMAP.md (it had been describing v0.5.7-alpha since July). Hardware state, `progress`, and `excitement` are carried over or estimated, not re-tested. Last real work before this: 2026-11-03, 0.8.2 released, then PR #36 (new profile starts with no login).
