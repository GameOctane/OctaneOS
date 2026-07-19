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

## Ideas / Backlog
- **Second-screen achievement companion** — pair OctaneOS over local WiFi with a running [Achievement Scavenger](https://github.com/batureren/achievement-scavenger) instance on the player's PC/console setup. Scavenger already knows what game just launched on Steam/PSN/Xbox and holds valid platform sessions; OctaneOS acts as a lightweight display client showing live missable-item warnings, hints, and progress while you play on another platform. RetroAchievements is already covered natively on-device — this extends the same idea to non-emulated platforms. Idea credit + concept borrowed with permission from Batu Ozdogan ([@batureren](https://github.com/batureren)), author of Achievement Scavenger. Needs: pairing/discovery protocol, a small local API on Scavenger's side (author receptive to adding one), and an OctaneOS-side display client.

## What just shipped (v0.5.6-alpha)
**Freeze fix (20-min hard freeze)**: Four root causes identified and fixed — xpad auto_poweroff, ES screensaver, labwc idle DPMS, AIC8800 USB autosuspend.

## What's in v0.5.7-alpha
**Audio fix + UI freeze fix**: Root cause of audio -22 error identified via live dmesg. PipeWire probes ALSA with unconstrained rate (INT_MAX = 2,147,483,647). Without hw_constraint_list, asoc_simple_hw_params hits default → -EINVAL → PipeWire sink fails → ES blocks on audio init → UI freeze. Fix: snd_pcm_hw_constraint_list() in asoc_simple_startup() (0004 patch). Also: A76 OPP table extended to 2000MHz @ 1050mV (requires next linux-rebuild to take effect in image — DTS committed, image not yet rebuilt).

## Resume here
v0.5.7-alpha released. Next: flash v0.5.7, test audio. A76 2000MHz OPP needs linux-rebuild + image build for v0.5.8.

## Last session
2026-07-10: v0.5.7-alpha released. Audio -22 root cause: PipeWire INT_MAX rate, fixed with hw_constraint_list in asoc_simple_startup. A76 2000MHz OPP added to DTS but needs rebuild. Controller disconnect was symptom of audio freeze, not separate cause.
