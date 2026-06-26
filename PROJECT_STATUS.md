---
phase: active
priority: high
category: hardware
progress: 62
focus: PowerVR GPU hardware acceleration
next_milestone: First ROM running end-to-end
milestone_distance: weeks
community_pressure: high
excitement: high
strategic: true
momentum: rolling
audience: diy-retro-gaming-builders
uniqueness: first-mover
viral_potential: medium
mvp_distance: weeks
---

## Why this exists
A $150 weekend build that anyone can make, own completely, and runs every retro game — open source from silicon to firmware.

## Strategic picture
OctaneOS is the foundation everything else in GameOctane sits on. Shipping a device that actually plays games is what turns Discord watchers into builders, gets YouTube coverage, and validates the entire platform. The companion app, dock modes, streetpass daemon, OTA updates — all of it is downstream of a first ROM running. People are watching. This is the one.

## Next up
- [ ] PowerVR BXM-4-64 GPU hardware acceleration (userspace GL)
- [ ] First ROM running end-to-end
- [ ] RetroAchievements configured out of the box
- [ ] Three mode system (handheld / docked / wireless streaming)
- [ ] OTA update system from GameOctane.com
- [ ] GameOctane companion app integration

## Blockers
PowerVR userspace GL drivers — not publicly distributed by Imagination Technologies. Watching linux-sunxi A733 thread and community efforts. Mali blob workaround is a potential alternate path if PowerVR stalls.

## Resume here
Kernel module loads clean. The missing piece is the userspace GL blob that sits between RetroArch and the GPU. Check the linux-sunxi A733 thread for any new blob drops or community progress. If still stuck, try the Mali workaround NickAlilovic referenced in the Armbian thread — similar SoC class, may get emulators running even without native PowerVR support. First command: `cd package/pvr-gpu && make`.

## Last session
2026-06-24: EmulationStation launches. Wired controllers confirmed working (USB HID + xpad). PowerVR kernel module loads. Waiting on userspace GL to get first ROM running.
