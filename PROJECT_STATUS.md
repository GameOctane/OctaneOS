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

## What just shipped (v0.5.5-alpha)
Audio MODULE_ALIAS fix: snd_soc_sunxi_codec_av now auto-loads via udev. CPU info display shows 8 cores and 2 clusters. xpad auto_poweroff=N committed for v0.5.6 (was missing from v0.5.5 image).

## What's in v0.5.6-alpha
**Freeze fix (20-min hard freeze)**: Three root causes identified and fixed:
1. xpad auto_poweroff=Y (6.6 BSP default): 8BitDo repeatedly self-powered off after idle, corrupting USB EHCI TT state → hard freeze. Fix: options xpad auto_poweroff=N.
2. ES screensaver default fires after 5min → software video decode at 1080p hangs compositor (no HW decode on A733). Fix: system.screensaver.time=0 default in S13octane-init.
3. labwc idle DPMS: added <idle><timeout>0</timeout></idle> to rc.xml fsoverlay.
4. AIC8800 USB autosuspend: USB core parks dongle after 2s; aic8800 driver has no suspend/resume → kernel hangs. Fix: S13octane-init writes power/control=on at boot.
Also: MODULE_ALIAS formalized as kernel patch (0003); .gitignore fixed for modprobe.d/.

## Resume here
v0.5.7 kernel build in progress. Audio -22 root cause found: PipeWire sends rate=INT_MAX (2147483647) because no hw_constraint_list was registered. The rate switch hits default → -22 → PipeWire sink fails → ES blocks on audio init → UI freeze. Fix: added snd_pcm_hw_constraint_list() in asoc_simple_startup() (0004 patch). Full path for 48kHz verified to return 0 (extparam also safe — virtual notifier block returns 0). Rebuild underway. Next: flash v0.5.7, test audio in game.

## Last session
2026-07-09/10: Live dmesg captured — "Invalid rate 2147483647" at line 87. Rate constraint fix applied to kernel (0004 patch). Controller disconnect at ~193s is symptom of ES freeze (no input → 8BitDo disconnects), not a separate cause. v0.5.7 building overnight.
