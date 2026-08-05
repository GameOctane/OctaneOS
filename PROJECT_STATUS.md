---
phase: active
priority: high
category: hardware
progress: 85
focus: Freeze fixes — xpad auto_poweroff, screensaver, labwc idle, USB autosuspend (v0.5.6)
next_milestone: Audio confirmed working + RetroAchievements
milestone_distance: weeks
community_pressure: high
excitement: very high
strategic: true
momentum: accelerating
audience: diy-retro-gaming-builders
uniqueness: first-mover
viral_potential: high
mvp_distance: weeks
---

## Why this exists
A $150 weekend build that anyone can make, own completely, and runs every retro game — open source from silicon to firmware.

## Strategic picture
OctaneOS is the foundation everything else in GameOctane sits on. GPU hardware acceleration just shipped. EmulationStation is running smooth. First ROM (Doom) confirmed playing with a controller. The platform is real. Next: RetroAchievements out of the box, three mode system, and OTA updates.

## Next up
- [ ] Audio — verify aplay -l shows allwinner-edp card on v0.5.5
- [ ] RetroAchievements configured out of the box
- [ ] Three mode system (handheld / docked / wireless streaming)
- [ ] OTA update system from GameOctane.com
- [ ] GameOctane companion app integration
- [ ] 8BitDo controller disconnect fix (intermittent, ~130s interval — likely controller sleep timer)
- [ ] Suppress spurious DP-1 hotplug events from sunxi-drm BSP
- [ ] Audio — aplay -l returns no soundcards; machine driver failing (simple_dai_link_of errors)
- [ ] Global RA activity ticker + Discord channel bot (design approved, build paused — see below)

## In progress — paused mid-build (2026-08-05)
**Global RA activity ticker + Discord channel bot** — grew out of issue #6
("social presence"). Landed on the backend-only version after ruling out
live player counts (RA API has no real-time presence endpoint, verified
against `api-docs.retroachievements.org`) and true Discord Rich Presence
(requires a locally-running Discord client via IPC — OctaneOS can't provide
that without a whole new companion app, which we decided was too much
friction to ask of users).

**Approach:** a new standalone Node.js service (`GameOctane/octane-ticker`,
hosted on the user's existing Railway Hobby plan) polls RA's
`API_GetRecentGameAwards` (site-wide feed, one API key, no per-user auth)
every 2 minutes, caches it, and (a) serves it to OctaneOS devices at
`/ticker.txt` for on-device toast notifications via the existing ES
`messagebox` API (same mechanism ROM Transfer/Moonlight Setup already use),
and (b) posts `completed`/`mastered` events to a GameOctane Discord channel
via an Incoming Webhook (not a full bot — simpler, smaller blast radius).
On-device: new `usr/bin/octane-ticker` script + `S90octane-ticker` init.d
service, following the `labwc-launch`/`S13octane-init` patterns exactly.
Full design doc: plan was approved and saved at
`/root/.claude/plans/radiant-inventing-honey.md` (session-local path — copy
the plan content somewhere durable if this needs to survive past this
session).

**Where it's at:** plan approved, `octane-ticker` service code partway
written (package.json + state.js done, in the session scratchpad, not yet
in a repo). **Blocked:** GitHub App integration lacks org-level
repo-creation permission (403) — `GameOctane/octane-ticker` needs to be
created manually before code can be pushed. Also still open: DNS access for
`api.gameoctane.com` (unconfirmed), Discord webhook needs to be created by
hand (needs "Manage Webhooks" on the GameOctane server), RA API key needs
generating from the existing GameOctane RA account.

## Ideas / Backlog
- **Chiaki — PS4/PS5 Remote Play** — Chiaki is an open-source Remote Play client for Linux with ARM support. Would let Octane stream PS4/PS5 games directly from a console on the local network. Touch screen on the Octane could map to PS4/PS5 touchpad input. Batocera has a chiaki package worth evaluating for aarch64 compatibility.
- **Steam Link** — Valve's official ARM Linux Steam Link client streams any Steam game from a PC on the local network. Batocera ships a steamlink package; needs evaluation for aarch64. Zero PC-side setup beyond enabling Remote Play in Steam.
- **Second-screen achievement companion** — pair OctaneOS over local WiFi with a running [Achievement Scavenger](https://github.com/batureren/achievement-scavenger) instance on the player's PC/console setup. Scavenger already knows what game just launched on Steam/PSN/Xbox and holds valid platform sessions; OctaneOS acts as a lightweight display client showing live missable-item warnings, hints, and progress while you play on another platform. RetroAchievements is already covered natively on-device — this extends the same idea to non-emulated platforms. Idea credit + concept borrowed with permission from Batu Ozdogan ([@batureren](https://github.com/batureren)), author of Achievement Scavenger. Needs: pairing/discovery protocol, a small local API on Scavenger's side (author receptive to adding one), and an OctaneOS-side display client.

## What just shipped (v0.5.6-alpha)
**Freeze fix (20-min hard freeze)**: Four root causes identified and fixed — xpad auto_poweroff, ES screensaver, labwc idle DPMS, AIC8800 USB autosuspend.

## What's in v0.5.7-alpha
**Audio fix + UI freeze fix**: Root cause of audio -22 error identified via live dmesg. PipeWire probes ALSA with unconstrained rate (INT_MAX = 2,147,483,647). Without hw_constraint_list, asoc_simple_hw_params hits default → -EINVAL → PipeWire sink fails → ES blocks on audio init → UI freeze. Fix: snd_pcm_hw_constraint_list() in asoc_simple_startup() (0004 patch). Also: A76 OPP table extended to 2000MHz @ 1050mV (requires next linux-rebuild to take effect in image — DTS committed, image not yet rebuilt).

## Resume here
Paused mid-build on the RA ticker + Discord bot (see "In progress" above) to
brainstorm further before continuing. First things to do when picking this
back up: (1) create the empty `GameOctane/octane-ticker` repo by hand, (2)
resume writing `src/ra.js`, `src/discord.js`, `src/poll.js`, `src/server.js`
per the plan, (3) then the on-device `usr/bin/octane-ticker` +
`S90octane-ticker` in this repo.

Separately, v0.5.7-alpha's audio/OPP items below are still the
hardware-track backlog — flash v0.5.7, test audio; A76 2000MHz OPP needs
linux-rebuild + image build for v0.5.8.

## Last session
2026-08-05: Scoped and got plan approval for a global RetroAchievements
activity ticker + Discord channel bot (issue #6 follow-through). Started
building the backend service, paused before finishing to brainstorm more.

2026-07-10: v0.5.7-alpha released. Audio -22 root cause: PipeWire INT_MAX rate, fixed with hw_constraint_list in asoc_simple_startup. A76 2000MHz OPP added to DTS but needs rebuild. Controller disconnect was symptom of audio freeze, not separate cause.
