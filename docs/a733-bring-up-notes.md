# A733 Bring-Up Research Notes

Reference notes compiled during initial board config setup. Sources verified April 2026.

---

## SoC Identity

| Field | Value |
|---|---|
| Chip | Allwinner A733 |
| Kernel codename | `sun60i` |
| Board family (Armbian) | `sun60iw2` |
| CPU | 2× Cortex-A76 + 6× Cortex-A55 @ 2.0GHz |
| GPU | Imagination PowerVR BXM-4-64 MC1 |
| WiFi | AIC8800 (USB-attached on Radxa boards) |

**Important:** The A733 is `sun60i`, NOT `sun55i`. The T527 (used in Orange Pi 4A) is `sun55i` / `sun55iw3`. They are related but different SoCs. Do not mix up kernel configs or device trees between them.

---

## Kernel

- **Repo:** https://github.com/radxa/kernel
- **Branch:** `allwinner-aiot-linux-5.15`
- **Base defconfig:** `arch/arm64/configs/defconfig` (only one defconfig in the branch)
- **Kernel version:** 5.15.x

The BSP defconfig is the starting point. OctaneOS requirements are layered on top via `linux-defconfig-fragment.config`.

---

## Device Tree

- **Expected DTB for Cubie A7S:** `sun60i-a733-cubie-a7s.dtb`
- **Status:** Does NOT exist in the Radxa BSP kernel as of April 2026.
- **Closest existing DTS:** `sun60i-a733-cubie-a7a.dtb` (Armbian Radxa-A7A branch)
  - Source: https://github.com/NickAlilovic/build/tree/Radxa-A7A
  - Armbian board file: `config/boards/radxa-cubie-a7a.csc`

The A7A and A7S are different Radxa Cubie boards. The A7A uses A733 and has a confirmed DTS. For early bring-up, use the A7A DTS as a stand-in. A proper A7S DTS must be created once we have hardware and can verify the peripheral map (display connector, GPIO, battery gauge I2C address, etc.).

Armbian A7A board config fields of note:
```
BOARDFAMILY="sun60iw2"
BOOT_FDT_FILE="allwinner/sun60i-a733-cubie-a7a.dtb"
KERNEL_TARGET="legacy,vendor"
enable_extension "radxa-aic8800"
AIC8800_TYPE="usb"
```

---

## Bootloader

- Allwinner-style boot uses two blobs: `boot0_sdcard.fex` (SPL) and `boot_package.fex` (U-Boot + ATF)
- Radxa U-Boot repo: https://github.com/radxa/u-boot
- **Status:** Exact branch and defconfig for Cubie A7S not yet confirmed. Research needed when hardware arrives.
- Partition layout mirrors the T527/Orange Pi 4A: boot0 @ 8K, boot-pkg @ 16793600, boot partition @ 20M.

---

## GPU — Critical Known Issue

The A733's GPU is **Imagination PowerVR BXM-4-64 MC1**. This is NOT a Mali GPU.

- **Panfrost will NOT work** — Panfrost is the open-source Mali driver.
- **PowerVR open-source Mesa driver** (`pvr` / `rogue`) is in active development upstream in Mesa. BXM series support is not yet production-ready as of April 2026.
- **Short-term:** Software rendering via llvmpipe (slow but functional for UI). EmulationStation runs on the CPU; RetroArch with software cores will work but no GPU acceleration for games.
- **Track:** https://gitlab.freedesktop.org/mesa/mesa — search for `pvr` driver / PowerVR BXM.
- When Mesa PVR BXM support lands, a new `BR2_PACKAGE_BATOCERA_POWERVR_MESA3D` package will need to be added to the Batocera build.

This is the single biggest technical risk for OctaneOS performance targets.

---

## Batocera Build System Reference

Batocera uses Buildroot with a custom `.board` file format. Key files for the T527 (closest existing Allwinner board in Batocera) were used as templates:

- `board/batocera/allwinner/t527/` — T527 board files structure
- `board/batocera/allwinner/t527/orangepi-4a/` — per-board boot scripts
- `configs/batocera-t527.board` — T527 build config

The `.board` file format uses Buildroot `BR2_` variables and Batocera-specific `include batocera-board.common`. All OctaneOS board files live in the OctaneOS repo and are symlinked into the Batocera submodule at build time by `scripts/setup-build-env.sh`.

---

## UART Console

- T527 UART0 base: `0x02500000` (Allwinner convention)
- A733 UART0 base: assumed `0x02500000` — **verify against A733 TRM if serial output is silent on first boot**
- Console device: `ttyAS0` (Allwinner serial naming convention)
- Baud: 115200

---

## Power Button & Volume Controls

Both are handled by existing in-kernel drivers — no new driver work needed.

**Power button**
- Use a spare GPIO pin on the 15-pin header
- Driver: `gpio-keys` (standard kernel driver, in BSP defconfig)
- Implementation: device tree entry only — add a `gpio-keys` node pointing at the chosen pin
- Long-press shutdown is handled by a userspace daemon (e.g. `gpio-power-button` or custom script) watching the input event

**Volume controls**
- Route up/down buttons through the existing MCP23017 I2C GPIO expander (TWI3, pins 3/5)
- MCP23017 has 16 GPIO pins; game controls use ~12, leaving headroom for 2 volume buttons
- Driver chain: `mcp23017` → `gpio-keys` → standard Linux key events (KEY_VOLUMEUP / KEY_VOLUMEDOWN)
- EmulationStation and RetroArch both respond to standard key events natively
- Physical volume hardware is optional — software volume via ALSA/USB DAC works without it

Both require only device tree additions. Add during hardware bring-up once pin assignments are confirmed.

---

## Audio Output

Handled by the existing Allwinner audio driver stack — no new driver work needed.

- **SoC codec:** Allwinner A733 has a built-in audio codec; driver is `snd-soc-sunxi` (in BSP defconfig)
- **Physical jack:** Cubie A7S likely routes the codec output to a 3.5mm jack — verify against board schematic during bring-up
- **Driver stack:** `sunxi-codec` + `sunxi-codec-machine` → ALSA sound card; RetroArch and EmulationStation use ALSA natively
- **Implementation:** device tree node for the codec DAI link only — no kernel or build changes required
- **Fallback:** if the jack routing is unclear at first boot, USB DAC (class-compliant) works out of the box with zero DTS changes

Add the codec DTS node when creating `sun60i-a733-cubie-a7s.dts`. Reference: `sun60i-a733-cubie-a7a.dts` will have a working codec node to copy from.

---

## Open TODOs Before First Boot

1. Create `sun60i-a733-cubie-a7s.dts` (derive from A7A DTS, map Octane-specific hardware)
2. Confirm Radxa U-Boot branch/defconfig for Cubie A7S and update `genimage.cfg`
3. Verify UART base address against A733 TRM
4. Investigate Mesa PVR BXM support timeline
5. AIC8800 USB WiFi — confirm kernel module is included in BSP defconfig or add to fragment
