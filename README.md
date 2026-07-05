# OctaneOS

> The operating system powering the Octane open source retro gaming handheld platform.

OctaneOS is a custom Linux distribution forked from [Batocera Linux](https://batocera.org), extended with hardware support for the Allwinner A733 SoC and built from the ground up for the Octane handheld platform.

Every Octane runs OctaneOS. Every OctaneOS is open source. Every update ships to every Octane in the world from [GameOctane.com](https://gameoctane.com).

---

## What is Octane?

Octane is an open source retro gaming handheld you build yourself. Not just a device — a platform.

- **$150 weekend build** that competes with $300 commercial handhelds
- **Three play modes** — handheld, docked, and wireless streaming
- **Universal dock** — HDMI, Component, and Composite outputs simultaneously
- **RetroAchievements** baked in and configured out of the box
- **Streetpass-style** passive community interactions over WiFi
- **100% open source** — hardware, software, STL files, everything

> *Build It. Play It. Own It.*

---

## What makes OctaneOS different?

Batocera is an incredible foundation. OctaneOS builds on top of it with features that will never exist in generic Batocera — because they only make sense on Octane hardware.

| Feature | Batocera | OctaneOS |
|---|---|---|
| Allwinner A733 support | ❌ | ✅ |
| Three mode system | ❌ | ✅ |
| Dual-radio WiFi — internet + streaming simultaneously | ❌ | ✅ |
| Cover art dock mode | ❌ | ✅ |
| Achievement overlay on device screen | ❌ | ✅ |
| Wireless streaming stack | ❌ | ✅ |
| Streetpass daemon | ❌ | ✅ |
| GameOctane companion app | ❌ | ✅ |
| OTA updates from GameOctane.com | ❌ | ✅ |
| Cart reader support (Phase 3) | ❌ | ✅ |
| RetroAchievements | ✅ | ✅ |
| EmulationStation frontend | ✅ | ✅ |
| RetroArch + cores | ✅ | ✅ |
| Controller auto-detection | ✅ | ✅ |

---

## Target Hardware

OctaneOS is built for the **Radxa Cubie A7S** with the Allwinner A733 SoC.

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

Full hardware specification available in the [Octane Platform Spec v1.3](docs/Octane_Platform_Spec_v1_3.pdf).

---

## Three Play Modes

OctaneOS manages three distinct play modes automatically — no configuration required.

**Handheld** — battery powered, screen shows the game, full controls active.

**Docked** — single USB-C cable carries DisplayPort video to TV and charges simultaneously. Octane screen switches to cover art and achievement notification mode.

**Wireless Streaming** — Octane stays in your hands. Game streams over a dedicated WiFi 6 radio (wlan1) to the dock. A second independent radio (wlan0) keeps the home network connection live — RetroAchievements, OTA updates, and netplay all work during streaming. Octane screen becomes a companion display.

---

## Emulation Targets

**Phase 1 (launch):**
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

## Download

**[OctaneOS v0.5.1-alpha — Radxa Cubie A7S](https://github.com/GameOctane/OctaneOS/releases/tag/v0.5.1-alpha)**

**Windows** — Use [Balena Etcher](https://etcher.balena.io). Flash the `.img.gz` directly — no need to decompress.

**Linux / Mac**
```
gunzip OctaneOS-a733-cubie-a7s-43-20260704.img.gz
dd if=OctaneOS-a733-cubie-a7s-43-20260704.img of=/dev/sdX bs=4M status=progress
```

Replace `/dev/sdX` with your SD card device. Verify with the included `.md5` or `.sha256` file before flashing.

**USB-C cable requirement** — DisplayPort Alt Mode requires a Full-Featured USB-C cable (also called "USB-C DP Alt Mode" or "Thunderbolt" cable). Standard charging cables do not carry video. If you see no display, the cable is the first thing to check.

---

## Build Status

[![Release](https://img.shields.io/github/v/release/GameOctane/OctaneOS?include_prereleases&label=latest)](https://github.com/GameOctane/OctaneOS/releases/latest)

> OctaneOS is in active early development. GPU hardware acceleration just shipped — EmulationStation is running smooth and ROMs are playing. We are building in public from day one — including the failures. Follow along.

| Milestone | Status |
|---|---|
| Batocera fork + A733 build target | ✅ Complete |
| GitHub Actions CI image build | ✅ Complete |
| A733 kernel + Cubie A7S device tree | ✅ Complete |
| aic8800 WiFi 6 — connects to SSIDs, SSH accessible | ✅ Complete |
| Boot blobs (boot0 + U-Boot) staged into image | ✅ Complete |
| First flashable image released | ✅ Complete |
| OctaneOS booting on Cubie A7S hardware | ✅ Complete |
| USB-C DisplayPort Alt Mode display output | ✅ Complete |
| USB-A host ports (controllers, keyboards, mice) | ✅ Complete |
| Gigabit Ethernet | ✅ Complete |
| CPU frequency scaling (A55 up to 1.8GHz, A76 up to 2.0GHz) | ✅ Complete |
| 120Hz DisplayPort output | ✅ Complete |
| PowerVR BXM-4-64 GPU kernel module loading | ✅ Complete |
| Batocera userspace + overlayfs booting | ✅ Complete |
| PowerVR GPU hardware acceleration (GLES2) | ✅ Complete |
| EmulationStation launching | ✅ Complete |
| Wired controller input (USB HID + xpad) | ✅ Complete |
| First ROM running | ✅ Complete |
| RetroAchievements configured | ⏳ Pending |
| Three mode system | ⏳ Pending |
| OTA update system | ⏳ Pending |
| GameOctane app | ⏳ Pending |

---

## Credits

- **[suckbluefrog](https://github.com/suckbluefrog)** — Pre-packaged buildroot dl cache tarballs for ecwolf and same-cdi, enabling CI builds without access to private Bitbucket repositories ([Batocera-Multilib](https://github.com/suckbluefrog/Batocera-Multilib))

- **[NickAlilovic](https://github.com/NickAlilovic)** — A733 bring-up work in the Armbian community build ([build/tree/Radxa-A7A](https://github.com/NickAlilovic/build/tree/Radxa-A7A)), which served as an essential reference for getting OctaneOS running on Cubie A7S hardware

---

## Development References

These resources are the foundation OctaneOS is built on:

- [Batocera Linux](https://github.com/batocera-linux/batocera.linux) — upstream fork base
- [Orange Pi BSP Kernel](https://github.com/orangepi-xunlong/linux-orangepi/tree/orange-pi-5.15-sun60iw2) — A733 kernel with full CCU, display, USB-C DP Alt Mode, and Cadence combo PHY support
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
- 💬 Discord — (https://discord.gg/pnuamjT)
- 🐦 (https://x.com/gameoctane)

---

## License

OctaneOS is licensed under the **GNU General Public License v3.0** — the same license as Batocera Linux.

This means you can use, modify, and distribute OctaneOS freely — but any modified version you distribute must also be open source under GPL v3.

See [LICENSE](LICENSE) for full terms.

---

*GameOctane.com — github.com/GameOctane — Built with Claude Code*