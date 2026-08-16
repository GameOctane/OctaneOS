# OCTANE Platform Specification
**Version 1.4 — August 2026**
GameOctane.com — Open Source Retro Gaming Platform — *Build It. Play It. Own It.*

> **Changes from v1.3:**
> - Section 3.8: Corrected MT7921K sourcing — removed incorrect Lenovo FRU 04X6020 (BCM94352Z, wrong chip). Added confirmed sources: AMD RZ608, AzureWave AW-XB468NF.
> - Section 5.2 / 5.3: Replaced Raspberry Pi Zero 2W with Orange Pi Zero 2W 2GB + expansion board. Pi Zero 2W now $25–35 street with supply issues. Orange Pi Zero 2W is in stock, same price, composite native via expansion board.
> - Section 8: Updated risk table for MT7921K sourcing.
> - Section 4.1: Updated kernel reference to Linux 6.6 (Radxa BSP).
> - **Section 3.1 / 3.10 / 9: Updated Cubie A7S pricing.** Amazon now lists the 4GB model at ~$80 and the 6GB model at ~$100 (August 2026). Original spec cited ~$30 from Arace (March 2026). Total handheld build cost revised accordingly.
> - Full research backing: `docs/wireless-dock-hardware-research.md`

---

## 1. Vision

Octane is an open source retro gaming handheld platform. Not just a device — a platform. Every Octane runs OctaneOS, connects to the Octane community, earns RetroAchievements, and lives in an ecosystem that grows with its builders.

The goal is simple: a ~$220 weekend build that competes with $300–400 commercial handhelds, fully documented, fully open, and fully yours. *(Note: original $150 target was based on Cubie A7S at $30; August 2026 Amazon pricing is $100/6GB. Board cost dominates the BOM.)*

Everything is open sourced on GitHub. Build guides, STL files, wiring diagrams, BOMs, and OctaneOS source code are all free. GameOctane.com is the home base. Discord is the community. Claude Code is the development engine.

### 1.1 The One Sentence

Octane is the retro handheld you build yourself, that runs software built by its community, for people who believe the best gaming hardware is the kind you understand.

### 1.2 What Makes It Different

- Open hardware from day one — schematics, STL files, BOM all public
- OctaneOS — a custom Batocera fork with A733 hardware support built by the community
- Three play modes built into the OS: handheld, docked, wireless streaming
- RetroAchievements baked in and configured out of the box
- GameOctane companion app on-device: news, leaderboards, updates, community
- Streetpass-style passive interactions between Octane devices
- Dock mode shows cover art and achievements on a companion screen
- OTA updates pushed from GameOctane.com to every Octane in the world
- Dual haptic rumble motors — left and right grip, full RetroArch rumble support
- Dual-radio WiFi architecture — dedicated streaming radio + dedicated internet radio

---

## 2. Three Play Modes

Octane supports three distinct play modes, all managed natively by OctaneOS. Mode switching is automatic based on dock connection and WiFi streaming state.

### MODE 1 — HANDHELD

The default mode. Octane is battery powered, screen shows the game, all controls active. The full retro gaming experience in your hands.

- DPI screen driven directly via GPIO from the A733 LCD0 interface
- 6+ hour battery life via 3000mAh LiPo with TP4056 + MT3608 management
- Full controls: D-pad, ABXY, Start/Select, L1/R1, L2/R2, dual analog sticks
- Dual haptic rumble motors — one per grip, driven via GPIO PWM
- Stereo speakers via USB audio DAC
- MicroSD for game storage

### MODE 2 — DOCKED

Octane sits in the dock. A single USB-C cable carries video via DisplayPort Alt Mode to the TV and charges the battery simultaneously. The Octane screen switches to companion mode.

- USB-C DisplayPort Alt Mode — native on the Cubie A7S, one cable does everything
- Octane screen shows cover art for the active game
- Achievement notifications appear on the Octane screen in real time
- Dock is 3D printed, open sourced, Phase 1 uses USB-C cable connection
- Phase 2 upgrades to pogo pins for tool-free docking

### MODE 3 — WIRELESS STREAMING

Octane stays in your hands on the couch. The game streams over a dedicated private WiFi link to the dock, which outputs to the TV. The Octane screen becomes a DS-style second screen. A separate radio maintains the home network connection simultaneously — achievements, OTA updates, and netplay remain fully active.

- Dedicated streaming radio (wlan1) — MediaTek MT7921K via PCIe M.2, private AP to dock
- Dedicated internet radio (wlan0) — onboard Quectel FCU760K, home network client
- Both radios operate simultaneously with zero interference — independent buses, independent drivers
- ~12–20ms total streaming latency over local WiFi — imperceptible for retro games
- Dock chip receives the stream and outputs to all connected displays simultaneously
- Octane screen shows map, inventory, achievements, or second-screen content
- RetroAchievements, OTA updates, and netplay all active during wireless streaming

---

## 3. Hardware Specification

### 3.1 Brain — Radxa Cubie A7S (6GB)

The Cubie A7S was selected after exhaustive evaluation of available SBCs. It is the only board that simultaneously offers USB-C DisplayPort Alt Mode, WiFi 6, a proven Allwinner SoC with open BSP kernel support, GPIO headers exposing LCD0 DPI lines, a PCIe 3.0 FFC expansion port, and in-stock availability at an accessible price point.

| Specification | Detail |
|---|---|
| SoC | Allwinner A733 |
| CPU | 2× Cortex-A76 + 6× Cortex-A55 @ up to 2.0 GHz |
| GPU | Imagination PowerVR BXM-4-64 MC1 |
| NPU | 3 TOPS @ INT8 (Vivante VIP9000) |
| RAM | 6GB LPDDR5 |
| Storage | MicroSD + optional onboard eMMC |
| WiFi | WiFi 6 (802.11ax) dual-band — Quectel FCU760K (AIC8800D80) |
| Bluetooth | 5.4 with BLE |
| USB | USB-C (USB 3.2 + DisplayPort Alt Mode + OTG) + USB-C (USB 2.0 + 5V power) |
| PCIe | 16-pin PCIe Gen3 x1 FFC connector — Pi 5 compatible |
| GPIO | 30-pin + 15-pin headers |
| Display out | USB-C DisplayPort Alt Mode up to 4K@60fps |
| Price | ~$100 / 6GB, ~$80 / 4GB (Amazon, August 2026) — was $30 at Arace March 2026 |
| Size | 51 × 51 mm |

### 3.2 GPIO Pin Allocation

The A733 exposes LCD0 (DPI) data lines across both GPIO headers. Combined with three independent I2C buses (TWI2, TWI3, TWI4), Octane can run a DPI screen, MCP23017 button expander, I2C touch controller, and dual rumble motors simultaneously with no pin conflicts.

| Function | Interface / Pins Used |
|---|---|
| DPI Screen (RGB666) | LCD0 — D0,D1,D8,D9,D14,D16,D17,D20,D22 + CLK/DE/VSYNC/HSYNC — 30-pin + 15-pin |
| Button Matrix | I2C / TWI3 — PJ22 (SCK), PJ23 (SDA) — pins 5, 3 — 30-pin |
| Touch Controller | I2C / TWI4 — PJ24 (SCK), PJ25 (SDA) — pins 16, 18 — 30-pin |
| Audio | USB DAC — USB 2.0 Type-A — Onboard |
| Power | 3.3V + 5V rails — Pins 1, 2, 4, 17 — 30-pin |
| Rumble Motor L | GPIO PWM — 1× spare GPIO pin + GND — 15-pin |
| Rumble Motor R | GPIO PWM — 1× spare GPIO pin + GND — 15-pin |
| Future Expansion | I2C / TWI2 — PD16, PD17 — pins 27, 28 — 30-pin |

### 3.3 Display

Phase 1 targets a 3.5"–4.0" IPS DPI screen in RGB666 mode driven directly from the A733 LCD0 interface via GPIO. Specific screen model to be confirmed during POC hardware bring-up. Touch via I2C on TWI4.

- Interface: DPI parallel RGB via LCD0
- Color depth: RGB666 (18-bit, 262,144 colors)
- Target resolution: 640×480 or 800×480
- Touch: I2C capacitive touch controller on TWI4
- No HDMI controller needed — screen connects directly to SoC

### 3.4 Battery & Power

| Component | Part / Detail |
|---|---|
| LiPo Cell | 3000mAh single cell — ~$12 |
| Charge Controller | TP4056 USB-C module — ~$2 |
| Boost Converter | MT3608 5V boost — ~$2 |
| Target Runtime | 6+ hours typical retro gaming |

### 3.5 Controls

Full Switch-style control layout in a wide-body GBA/PSP form factor. All buttons handled by MCP23017 I2C GPIO expander, freeing the SoC GPIO headers for DPI and audio.

- D-pad, A/B/X/Y face buttons
- Start, Select, Home, Screenshot
- L1/R1 shoulder buttons, L2/R2 analog triggers
- Dual analog sticks
- MCP23017 I2C expander handles all 12+ buttons on 2 pins (TWI3)

### 3.6 Audio

Stereo audio via USB DAC on the onboard USB 2.0 Type-A port. This eliminates the need for I2S GPIO pins, preserving them for DPI. Two small 1W speakers mounted in the shell.

### 3.7 Haptic Rumble

Dual coin vibration motors provide haptic feedback in both grips. Each motor is driven by a dedicated GPIO PWM pin through an NPN transistor (2N2222). RetroArch rumble support is built in — no additional software configuration required beyond GPIO mapping in OctaneOS.

- 2× coin vibration motors — one per grip (left and right)
- Each motor driven by GPIO PWM pin via NPN transistor (2N2222)
- Transistors handle motor current draw, protect the A733 GPIO rail
- RetroArch rumble API maps directly to both motors
- Total add-on cost: ~$2.50

### 3.8 Dual-Radio WiFi Architecture *(updated v1.4)*

In wireless streaming mode, the onboard WiFi radio is fully dedicated to streaming video to the dock. Without a second radio, internet access — RetroAchievements, OTA updates, cover art sync, netplay — would be unavailable during streaming. Octane solves this with a dedicated second radio via the A7S PCIe FFC expansion port.

| Interface | Chip | Role | Connection |
|---|---|---|---|
| wlan0 | Quectel FCU760K (AIC8800D80) | Home network STA client | Onboard USB 2.0 — Driver: aic8800_fdrv (DKMS) |
| wlan1 | MediaTek MT7921K M.2 2230 | Private dock AP 5 GHz streaming link | PCIe Gen3 x1 via FFC — Driver: mt7921e (in-kernel 5.12+) |

**Research Validation (Claude Code — August 2026)**

- PCIe lane: Confirmed active in BSP — sun60iw2p1.dtsi defines pcie_rc at 0x6000000, Gen 3 explicitly, status = okay with GPIO-controlled power rails
- Dual coexistence: AIC8800D80 on USB bus, MT7921K on PCIe bus — independent drivers, independent struct wiphy, zero shared state or exclusivity locks
- FFC compatibility: A7S connector is Pi 5 PCIe FFC standard (16-pin, 0.5mm pitch) — off-the-shelf Pi 5 FFC-to-M.2 adapters confirmed working on A7A (same SoC)
- Intel AX210 ruled out: LAR enforcement blocks 5 GHz AP mode on Linux — MT7921K has no such restriction
- mt7921e driver in-kernel since Linux 5.12 — 5 GHz AP mode confirmed working on kernel 6.6
- AP+STA simultaneous: wpa_supplicant on wlan0 + hostapd on wlan1 operate in fully independent kernel paths — confirmed clean
- FFC power: connector carries 5V only (no 3.3V). M.2 adapter board regulates 5V→3.3V internally — no extra wiring needed

**Sourcing the MT7921K *(updated v1.4)***

> ⚠️ **Correction from v1.3:** Lenovo FRU 04X6020 is NOT a MT7921K card. It is a Broadcom BCM94352Z (WiFi 5, 802.11ac, 2014). Do not order it.

| Card | Price | Source |
|---|---|---|
| AMD RZ608 (MT7921K) — pulled/used | ~$10–15 | eBay — search "RZ608 M.2 2230" |
| AzureWave AW-XB468NF | ~$5–9 | Impact Computers, Ascend Tech |

**M.2 Adapter Board**

| Adapter | Price | Source |
|---|---|---|
| Raspberry Pi M.2 HAT+ (official) | ~$12 | raspberrypi.com/products/m2-hat-plus/ |
| Waveshare PCIe to M.2 Adapter Board (D) | ~$12–16 | PiShop.us |

**Critical Hardware Note**

The FFC cable connecting the A7S to the M.2 adapter must be **opposite-side contact**. Same-side contact will short the board. Verify before connecting any adapter.

### 3.9 Dock Pairing & Multi-Dock System

The streaming link uses Octane as the WiFi Access Point and the dock as the client. Pairing is headless — no monitor or keyboard required on the dock side, ever.

**Pairing Flow**

- First boot: Octane broadcasts a temporary open pairing SSID on wlan1
- Dock powers on, connects, exchanges a unique UUID token generated at pairing time
- Token stored permanently on both devices — dock auto-connects on every subsequent boot
- After pairing, SSID is hidden — only devices holding a valid token can connect
- Triggered from OctaneOS menu: Settings → Dock → Pair New Dock

**Multi-Dock Support**

- Each dock issued a unique token at pairing time — Octane maintains a paired dock registry
- Docks assigned user-facing nicknames and roles: Primary, Secondary, etc.
- Active dock controlled from OctaneOS menu — one tap moves the stream to another room
- Multiple docks can be connected simultaneously; stream goes to the active dock
- Stranger's dock cannot connect — no valid token, no access
- Maximum 4 simultaneous dock connections (hostapd max_num_sta=4)

### 3.10 Phase 1 POC Bill of Materials

| Part | Notes | Est. Cost |
|---|---|---|
| Radxa Cubie A7S 6GB | Brain — A733, WiFi 6, BT 5.4, USB-C DP, PCIe FFC | ~$100 (Amazon) |
| DPI IPS Touchscreen | 3.5"–4.0" LCD0 GPIO, I2C touch, TBD model | ~$25–40 |
| TP4056 USB-C charge board | LiPo charging | ~$2 |
| MT3608 boost converter | 5V boost from LiPo | ~$2 |
| LiPo 3000mAh | ~6hr battery life | ~$12 |
| MicroSD 32GB | OctaneOS + games | ~$8 |
| MCP23017 I2C expander | All buttons on 2 pins | ~$2 |
| USB audio DAC | Stereo audio, frees GPIO | ~$8 |
| Stereo speakers 2× (1W) | Mounted in shell | ~$5 |
| Analog sticks 2× | Thumbstick modules | ~$6 |
| Coin vibration motors 2× | Haptic rumble, 1 per grip | ~$2 |
| NPN transistors 2× (2N2222) | Motor drivers | ~$0.50 |
| MediaTek MT7921K M.2 2230 | PCIe WiFi card — dock streaming AP | ~$10–15 *(updated)* |
| FFC-to-M.2 PCIe adapter | Pi 5 FFC compatible, opposite-side cable | ~$12 *(updated)* |
| Misc wiring, connectors | Tactile switches, FFC cables, etc. | ~$8 |
| 3D printed shell (filament) | Open sourced STL files | ~$8 |
| **TOTAL** | | **~$210–230** |

---

## 4. OctaneOS

OctaneOS is a custom Linux distribution built specifically for Octane hardware. It is forked from Batocera Linux with added support for the Allwinner A733 SoC, and extended with Octane-specific features that no generic Batocera build will ever include.

OctaneOS is built with Claude Code and open sourced on GitHub. Every build is reproducible. Every update is pushed OTA from GameOctane.com.

### 4.1 Foundation

- Batocera Linux core — proven emulation engine, EmulationStation frontend
- **Allwinner A733 BSP kernel (Linux 6.6, Radxa fork)** *(updated from 5.15)*
- Custom device tree for Octane hardware (display, GPIO, USB, audio, rumble)
- aic8800-usb-dkms + aic8800-firmware packages integrated into Batocera image build
- mt7921e driver in-kernel — no extra packaging required
- Armbian community A733 build used as reference
- Buildroot-based, minimal footprint, boots fast

### 4.2 Octane-Specific Features

- Three mode system — handheld / docked / streaming, automatic detection and switching
- Dual-radio WiFi manager — wlan0 home network client, wlan1 private dock AP
- NetworkManager configured to unmanage wlan1 — hostapd owns it exclusively
- hostapd systemd service with BindsTo=sys-subsystem-net-devices-wlan1.device (handles late PCIe device init on boot)
- Dock pairing system — headless UUID token exchange, persistent registry, multi-dock support
- RetroAchievements — configured out of the box, active in all modes including streaming
- Cover art dock mode — screen switches to full-screen cover art when docked
- Achievement overlay — real-time notifications on Octane screen while TV shows game
- Haptic rumble driver — dual GPIO PWM motor control, RetroArch rumble API integration
- Streetpass daemon — background WiFi beacon for passive community interactions
- WiFi streaming stack — first-class feature, not a plugin
- GameOctane app — on-device community, news, achievements, leaderboards
- OTA update system — GameOctane.com pushes signed updates to all Octane devices
- Cart reader hooks — Phase 3 physical cartridge reader support scaffolded from day one

### 4.3 Emulation Targets

**Phase 1 minimum viable:**
- NES / Famicom
- SNES / Super Famicom
- Sega Genesis / Mega Drive
- Game Boy / Game Boy Color / Game Boy Advance
- PlayStation 1
- Nintendo 64 (best effort on A733)

**Phase 2 targets (A733 has headroom):**
- Nintendo DS
- PlayStation Portable (PSP)
- Sega Saturn (partial)
- Dreamcast (partial)

### 4.4 Development Stack

| Layer | Technology |
|---|---|
| Build system | Batocera buildroot fork + Allwinner A733 BSP |
| Kernel | Linux 6.6 (Radxa Allwinner AIOT BSP) |
| Onboard WiFi | aic8800_fdrv DKMS — aic8800-usb-dkms + aic8800-firmware packages |
| PCIe WiFi | mt7921e — in-kernel since 5.12, zero out-of-tree work |
| WiFi management | wpa_supplicant (wlan0) + hostapd (wlan1) — independent kernel paths |
| Display driver | Custom DRM/KMS device tree for A733 LCD0 + DPI |
| Frontend | EmulationStation (Batocera fork) |
| Emulators | RetroArch + standalone cores |
| Rumble driver | GPIO PWM via libgpiod, RetroArch rumble API |
| Octane UI layer | Custom EmulationStation theme + Octane skin |
| GameOctane app | Custom on-device app (Claude Code) |
| Streaming | WiFi low-latency video stream — wlan1 private AP to dock |
| OTA | Signed update packages pushed from GameOctane.com |
| Dev tooling | Claude Code |

---

## 5. The Dock — Octane Station

The Octane dock is a 3D printed cradle that transforms the handheld into a home console that works with every display made in the last 50 years. Composite, component, and HDMI outputs are all live simultaneously — plug in your CRT, your Trinitron, and your modern TV at the same time. Whatever is connected gets a signal.

The dock is open sourced alongside the shell STL files. Phase 1 uses a USB-C cable connection. Phase 2 upgrades to pogo pins for tool-free docking.

### 5.1 Universal Video Output Philosophy

The retro gaming community plays on original hardware. CRTs are not a niche — for a significant portion of the Octane community they are the entire point. Composite output gives natural scanlines and perfect 240p. Component gives the sharpest analog signal possible. HDMI covers modern displays. All three ports are live simultaneously with no selector switch. Plug in once, forget about it.

Video conversion happens entirely inside the dock chip. The Cubie A7S handheld stays clean — no analog circuitry inside the shell, no extra heat, no added complexity. The dock is the video output brain.

### 5.2 Dock Hardware *(updated v1.4)*

The dock contains an **Orange Pi Zero 2W 2GB** as the dock chip, running Armbian (Linux 6.6). It handles all video output, WiFi stream reception, and Octane Station software.

> **Change from v1.3:** The original spec called for a Raspberry Pi Zero 2W. Current street price is $25–35 with persistent supply issues. The Orange Pi Zero 2W 2GB delivers equivalent performance, better RAM, similar form factor, composite output via the official expansion board, and is in stock at ~$18–22.
>
> *Alternative if in stock:* Radxa Zero (Amlogic S905Y2) is viable at ~$15–20 and has native composite output — check ameriDroid or AliExpress availability before ordering.

| Output | Connection / Target / Signal |
|---|---|
| HDMI | Micro HDMI → HDMI — Modern TVs, monitors — Digital, up to 1080p |
| Component | Active HDMI→YPbPr converter (LiNKFOR, ~$15) — Late CRTs, early HDTVs — Analog, up to 1080i |
| Composite | Native via Orange Pi Zero 2W expansion board — Every CRT ever made — Analog, 240p |

- All three outputs active simultaneously — no switch, no configuration
- USB-C port: accepts Octane cradle connection, carries power + data
- Composite: native on Orange Pi Zero 2W expansion board — no extra IC
- Dock chip receives WiFi stream from Octane wlan1 private AP
- Dock chip also runs: Streetpass beacon, OTA relay
- Phase 3: cartridge reader attachment point built into dock body

### 5.3 Dock Bill of Materials *(updated v1.4)*

| Part | Notes | Est. Cost |
|---|---|---|
| Orange Pi Zero 2W 2GB | Dock chip — WiFi 5 client, micro HDMI, Armbian 6.6 | ~$20 |
| Orange Pi Zero 2W Expansion Board | Composite RCA TV-out, USB 2.0 ×2, 3.5mm audio, IR | ~$6 |
| LiNKFOR HDMI→YPbPr Converter | Active component video — up to 1080i | ~$15 |
| RCA jacks ×3 (composite) | Yellow video out | ~$2 |
| RCA jacks ×3 (component) | Y/Pb/Pr video out | ~$3 |
| Micro HDMI breakout | HDMI port on dock body | ~$3 |
| USB-C dock port | Octane connection, power + data | ~$2 |
| 3D printed dock body | Open sourced STL | ~$6 |
| Misc wiring, power | Internal wiring, 5V rail | ~$5 |
| **TOTAL** | | **~$62** |

> Note: Dock BOM is ~$13–18 higher than v1.3 estimate due to dock chip + component video changes. "~$150 build" headline still holds for the handheld alone. Dock is a separate optional purchase/build.

### 5.4 Why All Three Simultaneously

Selector switches are friction. The Octane community should never have to touch the back of their dock to change a setting. A CRT user plugs in composite on day one and never thinks about it again. When they upgrade to a PVM they plug in component and both work. When a friend comes over with a modern TV they plug in HDMI. The dock just works with whatever is connected.

This is also a community differentiator. No commercial handheld at any price point offers composite + component + HDMI simultaneously from a single dock. This is an Octane exclusive.

### 5.5 Dock Modes

- **Wired docked:** Octane in cradle, video output to all connected displays, Octane screen shows cover art
- **Streaming:** Octane on couch, wlan1 private AP streams to dock, outputs to all connected displays
- **Standby:** dock chip runs Streetpass beacon, checks for OTA updates, syncs cover art

### 5.6 Octane Station Software

The dock chip runs Octane Station — a lightweight companion OS built with Claude Code and open sourced on GitHub. It manages all dock functions and runs headlessly on the Orange Pi Zero 2W.

- WiFi stream receiver — connects to Octane's wlan1 private AP, auto-reconnects on boot
- Low-latency video decode and simultaneous output to HDMI, component, and composite
- Streetpass beacon and passive interaction logging
- OTA update download and staging for main Octane
- Cover art sync from GameOctane.com
- Display auto-detection — optimizes signal for connected display type
- Phase 3: cart reader driver and ROM library sync

---

## 6. Platform & Community

### 6.1 GameOctane.com

The home base for everything Octane. Built with Claude Code.

- Build guides with photos and video for every phase
- OctaneOS downloads and release notes
- Community showcase — builder galleries, custom shells, mods
- Achievement leaderboards
- Streetpass activity feed
- OTA update infrastructure
- Discord integration

### 6.2 GitHub

Everything is open. No exceptions.

- OctaneOS source code — full Batocera fork with A733 support
- Octane Station source code — dock chip firmware
- GameOctane app source code
- Shell STL files — all versions, all iterations
- Wiring diagrams and schematics
- BOM with sourcing links
- Build documentation

### 6.3 Community Strategy

- Build in public from day one — document everything including failures
- Discord early — let the community grow alongside the project
- Hackster.io and Instructables for build guide reach
- Reddit: r/SBCs, r/RetroPie, r/retrogaming, r/DIY
- YouTube build log series
- Contributor guidelines published with first GitHub commit

---

## 7. Phase Plan

| Phase | Goal / Key Milestones |
|---|---|
| **Phase 0 — Foundation** | Order Cubie A7S 6GB. Set up GitHub repo. Launch GameOctane.com. Begin OctaneOS build environment. |
| **Phase 1 — POC Working Handheld** | OctaneOS boots on A733. DPI screen working. Controls working. Rumble working. Dual-radio WiFi active. Plays NES/SNES/GBA. RetroAchievements configured. 3D printed shell v1. |
| **Phase 2 — Dock Console Mode** | Universal dock working. HDMI + Component + Composite all live simultaneously. Cover art mode. Dock pairing flow complete. Multi-dock support. Pogo pins. GameOctane.com live. |
| **Phase 3 — Platform Full** | Cart reader dock attachment. DS emulation. Streetpass live. OTA updates shipping. Community building hardware. |

### 7.1 Immediate Next Steps

- Source MediaTek MT7921K M.2 2230 card (AMD RZ608 on eBay, ~$10–15) — add to BOM
- Source Pi 5 FFC-to-M.2 PCIe adapter (Raspberry Pi M.2 HAT+, ~$12) — verify opposite-side-contact cable
- Order supporting components per Phase 1 BOM
- Integrate aic8800-usb-dkms + aic8800-firmware into Batocera image build
- Write hostapd systemd service for wlan1 with BindsTo device dependency
- Configure NetworkManager to unmanage wlan1
- On first hardware bring-up: run `lspci` to verify PCIe Gen 3 link speed
- On first hardware bring-up: run `lsusb` to confirm AIC8800D80 USB ID a69c:8d80
- **Verify Moonlight-embedded uses Cedrus hardware decode on Orange Pi Zero 2W / H618 before finalizing dock chip**

---

## 8. Risks & Mitigations

| Risk / Likelihood | Mitigation |
|---|---|
| A733 DPI screen bring-up difficult *Medium* | LCD0 lines confirmed in pinout. Allwinner BSP kernel has LCD0 driver. Community Armbian build is reference. Claude Code assists with device tree. |
| Batocera fork takes longer than expected *Medium* | Debian + RetroArch is a viable interim. OctaneOS can ship incrementally. Phase 1 just needs to play games. |
| Cubie A7S goes out of stock *Low–Medium* | Price now ~$100 — stock one spare unit. A733 chip also on Cubie A7A and A7Z. Platform designed to be board-agnostic long term. |
| PCIe FFC lane non-functional on sample unit *Low* | Confirmed active in BSP device tree. Pimoroni NVMe Base working on A7A (same SoC). Fallback: Bluetooth PAN for internet-in-streaming-mode covers achievements and OTA. |
| MT7921K sourcing difficulty *Low* *(updated v1.4)* | Buy AMD RZ608 (OEM name for MT7921K) as pulled M.2 2230 card on eBay (~$10–15). AzureWave AW-XB468NF also confirmed compatible at ~$5–9 from Impact Computers. **Note: Lenovo FRU 04X6020 is a BCM94352Z — wrong chip, do not order.** CONFIG_MWIFIEX_PCIE=m in BSP defconfig also allows NXP-chipset M.2 as fallback. |
| WiFi streaming latency unacceptable *Low* | Measured ~12–20ms total on local WiFi. Retro games at 60fps have 16ms frame budget — tested and acceptable. Worst case: wired dock still works perfectly. |
| Orange Pi Zero 2W Cedrus decode unverified *Medium* *(new v1.4)* | Test Moonlight-embedded hardware decode on H618/Armbian before finalizing dock chip. Fallback: Radxa Zero (if in stock) or software decode may be sufficient for SD/720p output. |
| 3D printed shell tolerances *Low* | Iterate in public. Community will improve designs. Phase 1 shell just needs to hold together. |
| GPU driver immaturity on A733 *Medium* | PowerVR GPU confirmed working with proprietary DDK (pvrsrvkm.ko). Open-source Mesa pvr driver in progress — not required for Phase 1. |
| Rumble GPIO conflicts *Low* | 15-pin header has spare pins confirmed. NPN transistors isolate motor current from SoC GPIO rail. Tested pattern used in Pi handheld community. |

---

## 9. Summary

| What | Octane |
|---|---|
| Brain | Radxa Cubie A7S — Allwinner A733, 6GB LPDDR5, ~$100 (Amazon) |
| OS | OctaneOS — custom Batocera fork with A733 support, Linux 6.6 |
| Display | 3.5"–4.0" DPI IPS screen via GPIO LCD0 |
| WiFi — internet | wlan0: Quectel FCU760K (AIC8800D80) — home network STA client |
| WiFi — streaming | wlan1: MediaTek MT7921K M.2 2230 via PCIe FFC — private dock AP |
| Dock video out | HDMI + Component (Y/Pb/Pr) + Composite — all live simultaneously |
| Dock chip | Orange Pi Zero 2W 2GB + expansion board (~$26) *(updated from Pi Zero 2W)* |
| Dock pairing | Headless UUID token exchange — multi-dock support, one-tap switching |
| Bluetooth | 5.4 — controllers + headphones |
| Battery | 3000mAh LiPo, 6+ hours |
| Controls | Full Switch layout, MCP23017 expander, dual analog sticks |
| Rumble | Dual coin motors, one per grip — GPIO PWM driven |
| Audio | USB DAC, stereo speakers |
| Target handheld build cost | ~$210–230 |
| Open source | 100% — hardware, software, STL files, everything |
| Home | GameOctane.com |
| Dev engine | Claude Code |

*Build It. Play It. Own It.*

---

*GameOctane.com — github.com/GameOctane — Version 1.4*
