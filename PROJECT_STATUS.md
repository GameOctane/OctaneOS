---
phase: active
priority: high
category: hardware
progress: 78
focus: First ROM running — GPU acceleration confirmed working
next_milestone: RetroAchievements + three mode system
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
- [ ] RetroAchievements configured out of the box
- [ ] Three mode system (handheld / docked / wireless streaming)
- [ ] OTA update system from GameOctane.com
- [ ] GameOctane companion app integration
- [ ] 8BitDo controller disconnect fix (intermittent BLE disconnect under load)
- [ ] Suppress spurious DP-1 hotplug events from sunxi-drm BSP

## What just shipped (boot 87)
PowerVR BXM-4-64 GPU hardware acceleration — fully working. Three-patch wlroots fix stack:
1. EGL render format set: add DRM_FORMAT_MOD_INVALID unconditionally (PVR marks all explicit modifiers external-only)
2. DRM dumb allocator: use MOD_INVALID so PVR EGL skips explicit modifier in eglCreateImageKHR
3. linux-dmabuf-v1: skip drmPrimeFDToHandle check when driver returns EINVAL (pvrsrvkm doesn't implement it)

## Resume here
GPU is working. EmulationStation smooth. Doom running. Focus is polish and the three mode system. Check `board/batocera/allwinner/a733/patches/wlroots/` for the full patch stack. Next immediate win: fix the 8BitDo intermittent disconnect and get RetroAchievements wired up.

## Last session
2026-07-03: GPU hardware acceleration achieved (boot 87). PowerVR BXM-4-64 driving EmulationStation at 1920x1080@60Hz over USB-C DisplayPort. Doom confirmed running with 8BitDo controller. Three wlroots patches required — all committed to `board/batocera/allwinner/a733/patches/wlroots/`.
