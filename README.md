# OctaneOS

> The operating system powering the Octane open source retro gaming handheld platform.

OctaneOS is a custom Linux distribution forked from [Batocera Linux](https://batocera.org), extended with hardware support for the Allwinner A733 SoC and built from the ground up for the Octane handheld platform.

Every Octane runs OctaneOS. Every OctaneOS is open source. Every update ships to every Octane in the world from [GameOctane.com](https://gameoctane.com).

---

## What is Octane?

Octane is an open source retro gaming handheld you build yourself. Not just a device — a platform.

- **~$220 weekend build** that competes with $300–400 commercial handhelds
- **Three play modes** — handheld, docked, and wireless streaming
- **Universal dock** — HDMI, Component, and Composite outputs simultaneously
- **RetroAchievements** baked in and configured out of the box
- **Streetpass-style** passive community interactions over WiFi
- **100% open source** — hardware, software, STL files, everything

> *Build It. Play It. Own It.*

---

## What makes OctaneOS different?

Batocera is an incredible foundation. OctaneOS builds on top of it with features that will never exist in generic Batocera — because they only make sense on Octane hardware.

**Working today:**

| Feature | Batocera | OctaneOS |
|---|---|---|
| Allwinner A733 support | ❌ | ✅ |
| 120Hz DisplayPort output | ❌ | ✅ |
| OTA updates from GameOctane.com | ❌ | ✅ |
| PC streaming via Moonlight (Big Picture) | ❌ | ✅ |
| ROM transfer over WiFi (no PC software needed) | ❌ | ✅ |
| Box art default (TheGamesDB + ScreenScraper) | ❌ | ✅ |
| RetroAchievements | ✅ | ✅ |
| EmulationStation frontend | ✅ | ✅ |
| RetroArch + cores | ✅ | ✅ |
| Controller auto-detection | ✅ | ✅ |

**Phase 1 complete.** The software platform is done — GPU acceleration, EmulationStation, RetroArch, OTA updates, social features, and streaming all running on Allwinner A733 Linux.

**Phase 2 — handheld hardware build:**

| Feature |
|---|
| Physical handheld enclosure + PCB integration |
| Three mode system — handheld, docked, wireless streaming |
| Dual-radio WiFi — internet + streaming simultaneously |
| Cover art dock mode |
| Achievement overlay on device screen |
| Streetpass daemon |
| GameOctane companion app |
| Cart reader support (Phase 3) |

---

## Target Hardware

OctaneOS currently runs on the **Radxa Cubie A7S** with the Allwinner A733 SoC. This is the Phase 1 development board — the board works standalone, no handheld hardware required.

| Component | Spec |
|---|---|
| SoC | Allwinner A733 |
| CPU | 2× Cortex-A76 + 6× Cortex-A55 @ 2.0GHz |
| GPU | Imagination PowerVR BXM-4-64 MC1 |
| RAM | 6GB LPDDR5 |
| WiFi | WiFi 6 (802.11ax) |
| Bluetooth | 5.4 |
| Display out | USB-C DisplayPort Alt Mode |
| GPIO | 30-pin + 15-pin headers |

Full hardware specification available in the [Octane Platform Spec v1.4](docs/Octane_Platform_Spec_v1_4.md).

---

## Emulation Targets

**Phase 1 (current):**
- NES / Famicom
- SNES / Super Famicom
- Sega Genesis / Mega Drive
- Game Boy / Game Boy Color / Game Boy Advance
- PlayStation 1
- Nintendo 64

**Phase 2:**
- Nintendo DS
- PlayStation Portable
- Sega Saturn
- Dreamcast

---

## Ports

OctaneOS includes pre-configured entries in the **Ports** section of EmulationStation for tools that extend Octane beyond emulation.

| Port | Description |
|---|---|
| **Moonlight** | Stream your PC game library over your local network in Big Picture mode |
| **ROM Transfer** | Transfer ROMs wirelessly from your phone or PC — no USB cable, no software required |

---

## Download

**[Latest Release — Radxa Cubie A7S](https://github.com/GameOctane/OctaneOS/releases/latest)**

**Windows** — Use [Balena Etcher](https://etcher.balena.io). Flash the `.img.gz` directly — no need to decompress.

**Linux / Mac**
```bash
gunzip OctaneOS-a733-cubie-a7s-*.img.gz
dd if=OctaneOS-a733-cubie-a7s-*.img of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your SD card device. Verify with the included `.md5` or `.sha256` file before flashing.

**USB-C cable requirement** — DisplayPort Alt Mode requires a Full-Featured USB-C cable (also called "USB-C DP Alt Mode" or "Thunderbolt" cable). Standard charging cables do not carry video. If you see no display, the cable is the first thing to check.

---

## Build Status

[![Release](https://img.shields.io/github/v/release/GameOctane/OctaneOS?include_prereleases&label=latest)](https://github.com/GameOctane/OctaneOS/releases/latest)

> OctaneOS Phase 1 is complete. GPU hardware acceleration, 120Hz DisplayPort, EmulationStation, ROMs, OTA updates — all running on Allwinner A733 Linux. We are building in public from day one. Follow along.

| Milestone | Status |
|---|---|
| Batocera fork + A733 build target | ✅ Complete |
| GitHub Actions CI image build | ✅ Complete |
| A733 kernel + Cubie A7S device tree | ✅ Complete |
| aic8800 WiFi 6 — connects to SSIDs | ✅ Complete |
| SSH access (root/linux, or dev key) | ✅ Complete |
| Bash shell for root | ✅ Complete |
| US keyboard layout set by default | ✅ Complete |
| Clean shutdown (AXP8191 PMIC poweroff) | ✅ Complete |
| Boot blobs (boot0 + U-Boot) staged into image | ✅ Complete |
| First flashable image released | ✅ Complete |
| OctaneOS booting on Cubie A7S hardware | ✅ Complete |
| USB-C DisplayPort Alt Mode display output | ✅ Complete |
| USB-A host ports (controllers, keyboards, mice) | ✅ Complete |
| Gigabit Ethernet | ✅ Complete |
| CPU frequency scaling | ✅ Complete |
| PowerVR BXM-4-64 GPU kernel module loading | ✅ Complete |
| PowerVR GPU hardware acceleration (GLES2) | ✅ Complete |
| Batocera userspace + overlayfs booting | ✅ Complete |
| EmulationStation launching | ✅ Complete |
| Wired controller input (USB HID + xpad) | ✅ Complete |
| First ROM running | ✅ Complete |
| RetroAchievements configured out of the box | ✅ Complete |
| OTA update system | ✅ Complete |
| PC streaming via Moonlight | ✅ Complete |
| Box art scraping (TheGamesDB + ScreenScraper) | ✅ Complete |
| ROM transfer over WiFi | ✅ Complete |
| RetroAchievements friends activity feed | ✅ Complete |
| Site-wide RA completions & masteries feed | ✅ Complete |
| Speedrun world records in game library | ✅ Complete |
| 120Hz DisplayPort output | ✅ Complete |
| **Phase 1 software platform** | ✅ **Complete — v0.6.0** |
| Physical handheld hardware build | ⏳ Phase 2 |
| Three mode system | ⏳ Phase 2 |
| GameOctane app | ⏳ Phase 2 |

---

## Credits

- **[suckbluefrog](https://github.com/suckbluefrog)** — Pre-packaged buildroot dl cache tarballs for ecwolf and same-cdi, enabling CI builds without access to private Bitbucket repositories ([Batocera-Multilib](https://github.com/suckbluefrog/Batocera-Multilib))

- **[NickAlilovic](https://github.com/NickAlilovic)** — A733 bring-up work in the Armbian community build ([build/tree/Radxa-A7A](https://github.com/NickAlilovic/build/tree/Radxa-A7A)), which served as an essential reference for getting OctaneOS running on Cubie A7S hardware

- **Amish** — Early adopter, tester, and contributor. Invaluable help getting 120Hz smart glasses support off the ground, and steady feedback across features that has shaped the direction of OctaneOS from the start.

---

## Development References

- [Batocera Linux](https://github.com/batocera-linux/batocera.linux) — upstream fork base
- [Radxa 6.6 BSP Kernel](https://github.com/radxa/kernel/tree/allwinner-aiot-linux-6.6) — A733 kernel with full CCU, display, USB-C DP Alt Mode, and Cadence combo PHY support
- [Armbian A733 Community Build](https://github.com/NickAlilovic/build/tree/Radxa-A7A) — A733 bring-up reference
- [Radxa Cubie A7S Docs](https://docs.radxa.com/en/cubie/a7s) — hardware documentation
- [linux-sunxi A733](https://linux-sunxi.org/A733) — mainline kernel status

---

## Contributing

OctaneOS is community-built from day one. If you're interested in contributing — whether that's kernel work, emulator configs, UI design, documentation, or testing — open an issue and introduce yourself.

All skill levels welcome. If you're learning Linux through this project, you're in the right place.

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a PR.

---

## Community

- 🌐 [GameOctane.com](https://gameoctane.com)
- 💬 [Discord](https://discord.gg/pnuamjT)
- 🐦 [X / Twitter](https://x.com/gameoctane)

---

## License

OctaneOS is licensed under the **GNU General Public License v3.0** — the same license as Batocera Linux.

This means you can use, modify, and distribute OctaneOS freely — but any modified version you distribute must also be open source under GPL v3.

See [LICENSE](LICENSE) for full terms.

---

*GameOctane.com — github.com/GameOctane — Built with Claude Code*
