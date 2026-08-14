# Wireless Dock Hardware Research
*Researched 2026-08-13. Verify prices before ordering — eBay/AliExpress listings change frequently.*

---

## 1. WiFi Card — MediaTek MT7921K (AMD RZ608)

### Role
wlan1 — private 5 GHz access point for dock streaming. The handheld acts as the AP; the dock chip connects as a client.

### What to Buy

| Card | Price | Source | Notes |
|---|---|---|---|
| AMD RZ608 (MT7921K) pull | ~$10–15 | eBay — search "RZ608 M.2 2230" | Multiple sellers. MSI listing: ebay.com/itm/375899017087 |
| AzureWave AW-XB468NF | ~$5–9 | Impact Computers, Ascend Tech (ascendtech.com wifi0c01100250b) | MT7921-class. 2.4/5 GHz. Fine for dock AP (no 6 GHz needed). |

### ⚠️ Critical Correction — FRU 04X6020 is the WRONG CARD
Spec doc v1.3 listed Lenovo FRU 04X6020 as a confirmed MT7921K variant. **This is incorrect.**
FRU 04X6020 is a **Broadcom BCM94352Z** — an 802.11ac WiFi 5 card from 2014 ThinkPad Yoga 11e.
Do not buy it. Update the Platform Spec to remove this part number.

### M.2 Adapter (FFC → M.2)

The A7S PCIe FFC port is Pi 5 standard (16-pin, 0.5mm pitch). The FFC carries **5V only — no 3.3V**. M.2 cards need 3.3V. Off-the-shelf adapter boards include an onboard regulator — no extra wiring needed.

| Adapter | Price | Source |
|---|---|---|
| Raspberry Pi M.2 HAT+ (official) | $12 | raspberrypi.com/products/m2-hat-plus/ |
| Waveshare PCIe to M.2 Adapter Board (D) | ~$12–16 | PiShop.us |

**Cable:** FFC must be **opposite-side contact**. Same-side contact shorts the connector.

### Linux Driver Status (Kernel 6.6)

- Driver: `mt7921e` (in-kernel, part of mt76 series — no out-of-tree build needed)
- **5 GHz AP mode: confirmed working on kernel 6.6.** Early kernels (pre-6.1) had firmware issues; fixed.
- **No LAR enforcement** — Intel AX210 was ruled out because LAR blocks 5 GHz AP mode. MT7921K has no such restriction.
- 6 GHz: works on 6.6 (regression introduced in 6.8, doesn't affect us).
- Max channel width: 80 MHz — sufficient for dock streaming.
- **Start hostapd with `ieee80211ax=0`** (plain 802.11ac AP) to validate before attempting WiFi 6 HE mode. Full HE mode requires a recent hostapd build.
- ARM64: no architecture-specific issues found.

### PCIe Power Rails (Summary)

- FFC connector: **5V only** (500 mA per pin, 1A total).
- M.2 slot needs 3.3V — handled by onboard regulator on commercial adapter boards.
- If custom adapter: add AMS1117-3.3 LDO (~$0.10) fed from 5V FFC. WiFi cards draw 300–700 mA at 3.3V, within spec.
- A7S GPIO header also provides 3.3V as an alternative supply point.

### Action Items
- [ ] Confirm A7S PCIe FFC pinout matches Pi5 standard before ordering adapters
- [ ] Run `lspci` on first hardware bring-up to verify PCIe Gen3 link speed
- [ ] Test hostapd with `ieee80211ax=0` first, then attempt HE AP mode
- [ ] Update Platform Spec v1.3 to remove FRU 04X6020, replace with RZ608 / AW-XB468NF

---

## 2. Dock Chip — Orange Pi Zero 2W (replaces Pi Zero 2W)

### Why Not Pi Zero 2W Anymore
- Official MSRP: $15. Current street: **$25–35**, frequently out of stock.
- Supply risk for a product going into hardware design.

### Recommendation: Orange Pi Zero 2W 2GB

**~$18–22 on AliExpress / Amazon**

| Requirement | How it's covered |
|---|---|
| WiFi client (connect to MT7921K AP) | Built-in WiFi 5 (802.11ac) — more than sufficient for 1080p H.264 streaming |
| HDMI out | Micro HDMI, native, up to 4K signal |
| Composite video | Official expansion board (~$6) — composite RCA TV-out, native |
| Linux | Armbian (Debian/Ubuntu), kernel 6.6. Mature support. |
| SoC | Allwinner H618 — same Allwinner family as A733. Familiar build environment. |
| Form factor | 65×30 mm — small enough for 3D printed dock body |

### Dock Chip BOM

| Component | Price |
|---|---|
| Orange Pi Zero 2W 2GB | ~$20 |
| Orange Pi Zero 2W Expansion Board | ~$6 (Amazon B0CHMTT4XP) |
| LiNKFOR HDMI → YPbPr Active Converter | ~$15 (Amazon B07PMGBVV8) |
| **Total** | **~$41** |

This is comparable to current Pi Zero 2W street pricing, but in stock, with better specs and native composite out.

### Video Output Matrix

| Output | Method | Cost |
|---|---|---|
| HDMI | Native micro-HDMI | $0 extra |
| Composite (RCA, 480i/576i) | Orange Pi Zero 2W expansion board | Included above |
| Component (YPbPr, up to 1080i) | LiNKFOR active HDMI→YPbPr converter | Included above |

### Alternatives Considered

| Board | Price | Verdict |
|---|---|---|
| Radxa Zero 3W (RK3566) | ~$42+ | Out of stock, overkill, too expensive |
| Raspberry Pi Zero 2W | $25–35 street | Supply risk, no composite expansion ecosystem |
| Android TV sticks | ~$15–20 | Locked bootloaders, too much hacking |

### ⚠️ Blocker — Verify Before Committing

**Hardware video decode on H618 with Armbian must be verified.** The H618 has a VPU with Cedrus/Hantro driver support (mainline kernel). If Moonlight-embedded uses hardware decode correctly, Cortex-A53 ×4 handles the stream easily. If it falls back to software decode, 1080p60 H.264 may be marginal on Cortex-A53. **Test this before finalizing the dock chip selection.**

---

## 3. Wireless Streaming Feasibility

**Architecture:** MT7921K (wlan1, private 5 GHz AP on handheld) ↔ Orange Pi Zero 2W (WiFi client on dock) → receive H.264 stream via Moonlight → HDMI + Composite + Component output.

**Latency breakdown:**
- WiFi LAN (point-to-point, private AP): ~5–6 ms
- H.264 hardware encode on A733: ~2–5 ms
- H.264 hardware decode on H618: ~5–8 ms
- **Total system: ~12–20 ms**

One frame at 60fps = 16.7 ms. You are targeting approximately 1 frame of total lag — consistent with what Moonlight achieves on local WiFi 6. Well within playable range for retro titles.

**Private AP advantage:** Single client (the dock), no WiFi contention, deterministic latency. This is the correct architecture.

**Protocol:** Moonlight/Sunshine. ARM64 Linux client builds exist (moonlight-embedded, moonlight-qt). GStreamer is viable but requires significantly more engineering.

---

## 4. Platform Spec Corrections Required (v1.3 → v1.4)

| Section | Current (Wrong) | Correct |
|---|---|---|
| 3.8 Dual-Radio WiFi | Lenovo FRU 04X6020 listed as MT7921K variant | Remove FRU 04X6020. Use AMD RZ608 or AzureWave AW-XB468NF |
| 5.2 Dock Hardware | Raspberry Pi Zero 2W @ $15 | Orange Pi Zero 2W 2GB + expansion board (~$26 total board+expansion) |
| 5.3 Dock BOM | Pi Zero 2W line item | Update to Orange Pi Zero 2W + expansion board |
