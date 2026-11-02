# OctaneOS roadmap

**Status:** draft, 2026-11-02, written after the 0.8.1 release. Nothing here is a promise or a date. It records what we know, what we
measured, and the order we think makes sense. Items marked *(unverified)* are things we believe but have not tested.

## Where we are
- **0.8.1 is released** (signed updates, RetroAchievements Web API key per profile, ScreenScraper scraping, display-report log line and issue form).
- **Player profiles exist and work** (switch, create and delete from the main menu; own saves, states and RetroAchievements login and key). It
  is an OctaneOS feature, proposed upstream as [batocera-emulationstation#2207](https://github.com/batocera-linux/batocera-emulationstation/pull/2207)
  (open, no maintainer review yet).
- Our base is a snapshot of Batocera's main branch from **2026-04-06** (about v43): 51 commits behind v43.1 and about 3,000 behind today's
  development branch, with 34 commits of our own on top.

## Part 1: software (in this order)

1. **Profile safety fix (small).** The first profile switch copies `/userdata/saves` and `/userdata/states` into the hidden `.default` profile
   and then deletes the originals, ignoring copy errors. Change it to: copy, verify, then *rename* the old folder. Add a test that simulates a
   failed copy. This is the one place where saves can be lost.
2. **Syncthing, verified with profiles.** Syncthing is a separate program Batocera includes; nobody has tried it on OctaneOS, with or without
   profiles. Test in small steps, each checked before the next: does it run on the board and does its page load (it is local-only by design);
   does it sync a plain test folder with a second device; does it sync one profile's `saves`; does switching profiles while it runs cause
   deletes or conflicts. Sync only a profile's `saves` and `states`, never the whole profile folder (it holds RetroAchievements credentials in
   plain text). Open questions: savestates between devices and versions; encrypted folders so a hub never reads the data. Result: a short
   "how to sync your profiles" page.
3. **Profile v2 (finish the idea).** Show the current profile's name on screen (the main request in the Batocera discussion); find which
   emulators write saves outside the per-profile folder (Amiga, PS4, Saturn, Dreamcast and parts of MAME write to `/userdata/saves/...`
   directly) and fix or document each; decide how MAME high scores are shared *(location not yet found)*; decide whether to ask for a profile at boot.
4. **Device password.** The skippable first-boot screen from `docs/security-design-phase1.md` (phase 2): modern password hash, migration for
   existing devices, a `reset-password` file on the boot partition, and the same password opening Syncthing's page on the network.
5. **Keep up with Batocera.** Rebase onto v43.1 (51 commits, mostly fixes; a few may matter for ARM64, such as an Azahar crash fix and storage
   mounting) and decide a rhythm, for example after each Batocera release. Do this before adding hardware work, so every later change is
   made on a current base.
6. **Update the Batocera PR.** After items 2 and 3, with evidence (Syncthing result, current-profile indicator) and a description that says it
   is no longer a proof of concept. Check it still applies to their current code.

## Part 2: the wireless dock and the handheld

The wireless dock is the biggest unknown ("the only for-sure unknown if it is even possible"). The rest of the handheld is believed to be
ordinary engineering.

### Streaming: measured so far (A7S alone, loopback, no radio, no receiver, October 2026)
| Stage | Result |
|---|---|
| Software encode, retro sizes | 640x480 at 60 fps uses about 0.5 core; 720p60 is the edge; 1080p60 cannot keep up |
| Codec path using ffmpeg's tools | about 71 ms (mostly the tools' own queues) |
| Purpose-built pipeline (our own small programs) | compress + send + decode about **13-15 ms** at 960x540, 60 fps |
| Screen capture through the compositor | the biggest piece: about 63 ms at 1080p, 39 ms at 720p; fitted to the handheld's 800x480 panel about 28 ms |
| Game frame to decoded frame, handheld panel size | about **38-42 ms** |
| Cheap receiver decode | a small core decoded 540p in about 2.6 ms |
| Wired USB-C dock | works: hubs, gigabit Ethernet and HDMI at 1080p60 |

### Streaming: not done yet
- A real Wi-Fi hop; a real receiver board; the TV's own display delay (8-16 ms).
- Audio and lip sync: observed only (the audio output queues about 75 ms), not measured.
- The overall glass-to-glass figure. Rough estimate 55-65 ms against the 33 ms (two-frame) target: **not met yet**.

### Streaming: next steps, cheapest first
1. Capture inside RetroArch instead of through the compositor (expected to save 25-30 ms), in a YUV format to skip a 4 ms conversion.
2. Use a PC as a stand-in dock over Ethernet, then home Wi-Fi; measure glass-to-glass with a 240 fps phone camera.
3. Audio path and lip sync.
4. Private access point: MT7921K Wi-Fi card with an E-key PCIe adapter (the Raspberry Pi M.2 HAT+ named in the spec is M-key only and does not
   fit), and hostapd (not in the image yet).
5. The real receiver board (Orange Pi Zero 2W first, software decode of 480p; Radxa Zero 3W as a fallback).
6. Design the link's pairing and security with the same care as update signing. A hidden network name is not security.

**The hardware encoder.** The encoder on the handheld's SoC is off in our kernel (`CONFIG_AW_VIDEO_ENCODER_DECODER=n`; a header from the
vendor SDK, `cedar_ve.h`, is missing). It is not needed for retro sizes. It matters for demanding systems (PS2, GameCube, Dreamcast), which
need the fast cores themselves; how much software encoding costs while such a game runs has *not been measured*. The receiver's hardware
decoder (Orange Pi, H618) reportedly does not work on mainline *(unverified)*; test software decode first.

### Handheld
- **Built-in screen:** our device tree has no entry for the DPI screen yet; the spec rates it medium risk. The DisplayPort output must keep working
  in every build (docked mode, cabinet).
- **Power:** an MT3608 boost converter may not carry the board under load, which could look like the hard shutoffs. Measure the real current draw
  before sizing it. There is no battery gauge in the plan.
- **Heat in a closed case:** the fan driver shipped in 0.8.0, but the speed control is not tested on a real fan. A soak test inside a case comes after.
- **Hard shutoffs under load (#11):** need an answer before a case is sealed.
- **Controls, rumble, audio on the shell:** believed workable; not yet in our device tree *(not checked)*.

### Cabinet and arcade
The wired DisplayPort path has nothing to encode, so it can proceed on its own.

## Later, and things to watch
- **GameCube/Wii:** no working default emulator. Revisit when the open GPU driver ("apercel", which targets our GPU but has only been tested on a
  different A733 board) matures; it could also unlock Vulkan.
- **Display path cleanup:** the picture can stay black after a monitor is switched off and on; EmulationStation does not recover from a runtime mode change.
- **Idle power** (`CPU_IDLE`), the boot-intro `Failed to commit atomic request` message, reproducible container builds (#9), the display driver port (#23).
- **Other boards** (Cubie A7Z, Orange Pi Zero 3W): feasible in principle; needs board-independent update tooling (one `boot.tar.xz` is assumed today),
  support tiers (tested every release, or community), and testers, since a bad update can brick a card.
- **Stale file:** `PROJECT_STATUS.md` still describes v0.5.7-alpha and needs bringing up to date or retiring.

## Decisions for the maintainer
- Ask for a profile at boot, or only in the menu?
- MAME high scores: shared by everyone, or per profile?
- RetroAchievements logins and keys: leave out of any sync, or use encrypted folders?
- Which receiver board to buy first, and what to run on the first test hardware.
