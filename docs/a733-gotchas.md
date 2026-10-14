# A733 / Cubie A7S gotchas

Things that cost us days or weeks, written down so the next person does not pay twice. Each item says how sure we are:

- **verified**: checked against the code, the image or a measurement (where is given)
- **observed**: seen on hardware more than once, cause not fully proven
- **theory**: our best explanation; do not build on it without testing

State as of October 2026: OctaneOS 0.7.0 on a Radxa Cubie A7S, Radxa 6.6 vendor kernel, Radxa allwinner-bsp v1.4.8.
For the SoC itself see [a733-bring-up-notes.md](a733-bring-up-notes.md); for network defaults see [network-and-security.md](network-and-security.md).

---

## Build and source

### 1. A fix can be correct in git and missing from the image  *(verified)*
The 120 Hz fix (item 4) was committed on 2026-08-10 in v0.5.29, but it only worked on devices from v0.5.32. The commits for v0.5.30, v0.5.31 and
v0.5.32 (`475a83d`, `3df309d`, `90c0623`) changed nothing except version numbers: they were rebuilds, until the stale state was cleared.
The device tree is compiled from a **copy** of the kernel source that Buildroot makes (`LINUX_OVERRIDE_SRCDIR`), and Buildroot reuses
the copy and its stamps when it thinks nothing changed.
**Now:** `scripts/build.sh` hashes every kernel input (device tree, defconfig, both patch folders, the pin file) and redoes the kernel setup from
clean when it changes; `scripts/check-image.sh` checks the finished image (120 Hz line in the compiled device tree, thermal zones, compiled copies
match their sources). Run `check-image.sh` before believing a build.

### 2. Files removed from the overlay stay in the image  *(verified)*
Buildroot keeps `target/` between builds and never deletes a file you removed from `fsoverlay`, so the stale file ships in `rootfs.squashfs`.
**Now:** `scripts/prune-stale-overlay-files.sh` runs before each build; `check-image.sh` looks inside the squashfs.

### 3. Upstream branches move; pin the commits  *(verified)*
`setup-kernel-66.sh` used to clone whatever the Radxa branch tip was. It now fetches the exact commits in
`board/batocera/allwinner/a733/kernel-sources.pin` (`--check-upstream` reports newer ones, `--reset` redoes the setup).
GitHub's **compare API caps its file list at 300 files without saying so**: use `git diff` between two refs of a (blobless, bare) clone instead.

---

## Display and video

### 4. 120 Hz over DisplayPort is one device-tree line  *(verified)*
`fps_limit_60 = <0>;` on the eDP node, `board/batocera/allwinner/a733/dts/sun60i-a733-cubie-a7s.dts` line 1858. The driver reads it in
`bsp/drivers/drm/sunxi_drm_edp.c` (`of_property_read_u32(..., "fps_limit_60", ...)`, around line 1144) and rejects modes above 60 Hz without it.
It took months to find. Our earlier EDID overrides were not needed for it on a normal monitor (item 6).

### 5. HDMI has a separate hard 60 Hz cap  *(verified)*
`bsp/drivers/drm/sunxi_drm_hdmi.c`: `if (rate > 60) { return MODE_BAD; }` (v1.4.8 line 2783, v1.5.0 line 2803). Not touched by any OctaneOS
patch, so HDMI stays at 60 Hz. DisplayPort and HDMI are different drivers with different limits.

### 6. We forced a smart-glasses display profile on every unit  *(verified)*
The boot line carried `drm.edid_firmware=DP-1:edid/smartglasses.bin`, so the board ignored the real monitor's capabilities and told everything it
was a pair of 120 Hz glasses (`board/.../cubie-a7s/boot/extlinux.conf`). On an MSI G32C4W (165 Hz) the real EDID gives 60/120/144/165 Hz and the
board reaches 120 Hz without any override. `labwc-launch` also applies a corrected EDID at runtime for the glasses' maker id (`506c`); the glasses
themselves are **untested** since we do not have them. Do not change this path without someone who owns the glasses.

### 7. The display link is negotiated at the monitor's maximum, not what we configured  *(verified, cause of blackouts is theory)*
`edp_update_capacity()` in `sunxi_drm_edp.c` sets the rate to `min(source max, sink max)`; the device tree's `edp_lane_rate` is ignored. A monitor
that advertises 5.4 Gbps gets 5.4 Gbps on 4 lanes although 1080p120 needs about 6.5 Gbps (2.7 Gbps on 4 lanes has about 8.6 usable).
Control files: `/sys/devices/virtual/edp/edp/attr/` (`lane_config_now` current link, `dpcd` the monitor's capability registers, `src_max_rate_debug`
write `270` to cap at 2.7 Gbps, `lane_cfg_debug` + `lane_debug_en`). A cap only takes effect when the driver sees a **new** monitor connection.
*Theory:* the highest rate is marginal on this board and causes the random one-second blackouts that leave **nothing** in the kernel log.

### 8. A sleeping monitor can drop the link without the board noticing  *(observed)*
Switching a monitor off for 10 seconds produced no kernel event and no connector change: the monitor stays "connected". After a long sleep the picture
may not come back. Radxa's v1.5.0 BSP reworks DisplayPort hotplug and adds runtime suspend/resume; see the port patch
`linux_patches_66/0100-radxa-allwinner-bsp-v1.5.0-display-driver.patch` (experimental).

### 9. Link training can fail at the highest rate  *(observed)*
`link training failed at 5400000000, retry at 2700000000` and `swing voltage reach max level` appeared after a display restart. Radxa's v1.5.0
enables the transmitter output **before** training starts; DockSeed's mainline driver makes the same fix independently. Our v1.4.8 does not.

### 10. The boot intro had sound and no picture  *(verified)*
The upstream `S28splash` starts mpv on the bare display before the compositor exists. At that moment the connector is often reported
"disconnected" and mpv's GPU output fails to create GBM buffers, so only the audio plays. Playing it as a Wayland window **inside** the compositor
(`mpv --vo=gpu-next --gpu-context=wayland`) gave a picture the maintainer judged "way better" (not yet tested at boot time). **Testing mpv over SSH misleads** unless you export the compositor's environment:
`LD_LIBRARY_PATH=/usr/local/lib:/usr/lib LIBGL_DRIVERS_PATH=/usr/local/lib/dri GBM_BACKENDS_PATH=/usr/lib/gbm MESA_LOADER_DRIVER_OVERRIDE=pvr
WAYLAND_DISPLAY=wayland-0 XDG_RUNTIME_DIR=/run`. Without it Mesa says `failed to create dri2 screen` and silently renders in software.

### 11. `GBM_BACKENDS_PATH` points at a folder that does not exist  *(verified; the obvious fix made things slower)*
`usr/bin/labwc-launch` sets `GBM_BACKENDS_PATH=/usr/local/lib/gbm`; the image has `/usr/lib/gbm/dri_gbm.so` and no `/usr/local/lib/gbm`, so the
compositor logs `gbm_create_device failed`. Pointing it at `/usr/lib/gbm` makes GBM work, but in one A/B test on the main card ES **idle frame rate went from about 44 to 22 fps** and
Settings from about 12 to 9.8. (A later run with a different change showed idle at 22 too, so idle readings may swing between two values; the
unpatched baseline should be re-measured before concluding.) Do not "fix" it without measuring (item 14).

### 12. The compositor tries direct scan-out on every frame and always fails  *(verified)*
`Failed to import buffer for scan-out` / `drmPrimeFDToHandle failed` about every 25-44 ms while the menu animates: the display driver cannot import
the GPU's buffers. It is logged at DEBUG level and `labwc -d` is always on, so the log grew 2.5 MB in seven minutes (constant SD-card writes).
`WLR_SCENE_DISABLE_DIRECT_SCANOUT=1` (supported by wlroots 0.19) stops it: zero failures, a 38 KB log, and Settings went from about 12 to 17 fps in one
test. Measured once; not shipped yet.

---

## Speed and heat

### 13. The 80 degree throttle is our setting, and it slows the small cores most  *(verified)*
`&cpul_target` / `&cpub_target` in the device tree set 80 C; the vendor default is 90 C (Radxa's own images use 60 C, which they call "consistency, not tuned").
There is no `devfreq`, so the kernel cannot throttle the GPU or memory. On a bare board with a DS game, the six small cores were held at 408 MHz
(maximum throttle) while the two big cores ran at about 1200 MHz: menus and the compositor run on the small ones. The GPU runs at 600 MHz.

**Measured (2026-10-13, same board, same script `thermal-load-test.sh`, 5 minutes with all 8 cores busy):**

| | bare board | with a 14x14x7 pin-fin on the SoC and a 14x10x5 on the memory |
|---|---|---|
| idle at the menu, 10 min after power-on | 72-73 C | 62-63 C |
| time to reach 80 C under load | 15 s | 15 s (the die heats fast whatever the heatsink) |
| temperature after 5 minutes | **90 C and still rising** at the minimum 408 MHz | **80-82 C, held by the throttle** |
| big-core speed during the load | 408 MHz (the floor) | about 900-1000 MHz on average |
| temperature 90 s after the load | 79 C | 68 C |

A bare board idles only about 8 C below the throttle trip, so everyday use sits on a performance cliff; with the throttle already at its floor the heat still climbed to 90 C,
which is consistent with the shutoffs of the build that had no throttle at all. With heatsinks the idle headroom is about 17 C and the throttle regulates instead of running away.
A fan and the sealed case are still untested.

### 14. Measure the UI frame rate instead of feeling it  *(verified)*
`DrawFramerate` in `es_settings.cfg` (`<bool name="DrawFramerate" value="true" />`, set while EmulationStation is stopped) draws a frame counter. Readings on
the same monitor: idle 22-45 fps, scrolling 43-47, opening Settings 6-17 depending on the setup (single readings read by eye: use them as orders of magnitude). GPU load and clock:
`/sys/kernel/debug/pvr/status`, `clk_summary` (mount debugfs first: `mount -t debugfs none /sys/kernel/debug`).

### 15. Opening Settings is slow because of two helper scripts  *(verified)*
`batocera-resolution listModes` takes about 730 ms and `batocera-info` about 720 ms (everything else 6-80 ms). EmulationStation waits for them, so the
frame rate collapses while the menu opens.

---

## Device behaviour

### 16. Edits over SSH can silently vanish  *(verified)*
The root file system is an overlay on tmpfs: changes under `/etc` and `/usr` are lost at the next boot, `/boot` is read-only FAT, and only `/userdata` persists.
`S14labwc` copies `rc.xml` and `autostart` into `/userdata/system/.config/labwc/` on **every** boot, so card-side edits to them do not stick.

### 17. The old updater deletes your files in `/boot`  *(verified)*
The updater in v0.6.9 and earlier unpacks straight over `/boot` and removes files that are not in the update (including `boot-custom.sh`); the new
updater does not. See [UPGRADING.md](../UPGRADING.md).

### 18. Settings files can hold secrets in plain text  *(verified)*
`es_settings.cfg` stores scraper account names and passwords, and the RetroAchievements token and password live in plain text in the profile folders.
Keep them out of logs and screenshots; since 0.7.0 the file share hides the `system` folder from guests.

---

## Things we believed that were wrong

| We believed | Reality |
|---|---|
| The intro file is too heavy to decode | It decodes in 1.3 s for a 4 s clip (3 times faster than needed) |
| Fixing the GBM path would speed the compositor up | In one test it made idle frame rate worse (see item 11) |
| 120 Hz needed the EDID override | One device-tree line, plus a build that really contained it |
| The cable is the problem | Nothing pointed at it; the link is simply run at the monitor's maximum rate |
| Replacing the fixed display wait with "wait until modes appear" is cleaner | It broke wake-up in v0.5.33 and was reverted in v0.5.34 (`44397c1`): "modes appeared" does **not** mean "link is ready" |
