---
phase: active
priority: high
category: hardware
progress: 85
focus: Audio codec built-in fix + CPU info display fix (v0.5.5)
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

## What just shipped (v0.5.4-alpha)
Bash shell, US keyboard layout, AXP8191 clean shutdown, audio drivers in (SND_SOC_SUNXI_CODEC_AV=m). Audio still not working — see v0.5.5 fix below.

## What's in v0.5.5-alpha (building now)
**Audio fix (root cause)**: SND_SOC_SUNXI_CODEC_AV had no MODULE_ALIAS in the source — udev could never auto-load it. Machine driver hit EPROBE_DEFER forever. Fix: =y (built-in). Registers at late_initcall before any modules load; platform device created by DRM EDP driver immediately matched.

**batocera-info CPU display**: Script showed "CPU Cores: 6" on A733 (8-core). Bug: sysfs fallback used physical_package_id (all 0 on single-SoC ARM) + core_id — A76 core_ids 0-1 collided with A55 core_ids 0-1 → 6 unique pairs. Fix: try cluster_id first (A55=0, A76=1). Now shows 8 cores + two clusters with correct frequencies.

## Resume here
v0.5.5-alpha building. Verify: aplay -l shows allwinner-edp card, CPU Cores shows 8, CPU Cluster 1: 6 cores @ 1800 MHz / CPU Cluster 2: 2 cores @ 2000 MHz.

## Last session
2026-07-07: Audio root cause found — no MODULE_ALIAS on snd_soc_sunxi_codec_av. Fixed =m→=y. batocera-info fsoverlay override for CPU core count and frequency display.
