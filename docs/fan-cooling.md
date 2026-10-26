# Fan cooling for the Cubie A7S

Status: **software written, fan not yet tested on hardware** (October 2026). Heatsinks alone are not enough for a heavy game: with
the two pin-fin heatsinks a DS game still averaged 77 C and touched the 80 C throttle (see item 13 in [a733-gotchas.md](a733-gotchas.md)).

## How it works

```
temperature sensors -> kernel thermal code -> "cooling device" (the fan) -> PWM controller -> pin PJ27 -> fan's control wire
 (5 zones on the chip)  compares each zone's      pwm-fan driver turns a        makes the on/off signal
                        temperature with the      level (0..4) into a duty
                        trip points in the        cycle (0..255)
                        device tree
```

- The trip points and the fan description are in `board/batocera/allwinner/a733/dts/sun60i-a733-cubie-a7s.dts`.
- Every zone that has fan steps asks for a level; the fan runs at the **highest** level any zone asks for.
- The fan is meant to run **all the time**: level 0 is a base speed (duty 100/255), not off, so it never has to restart from a stop.
- The thermal governor is `step_wise`. At boot the `pwm-fan` driver starts at its highest level until the thermal code picks one, so a failure is loud, not hot.
- No script is involved; `cat /sys/class/thermal/cooling_device*/type` shows the fan as `pwm-fan` and `cur_state` its level.

| trip (C) | fan level | duty (of 255) |
|---|---|---|
| below 55 | 0 (base speed) | 100 |
| 55 | 1 | 140 |
| 60 | 2 | 180 |
| 66 | 3 | 220 |
| 72 | 4 (full) | 255 |
| 80 | CPU throttle (unchanged) | |

Each trip has 3 C of hysteresis. **These numbers are starting values**, to be tuned from heat logs with the fan fitted.

## What changed in the code

- `linux-defconfig-fragment.config`: `CONFIG_PWM`, `CONFIG_AW_PWM`, `CONFIG_SENSORS_PWM_FAN` on, `CONFIG_AW_DISP2` explicitly off.
- `linux_patches_66/1014-sunxi-aw-disp2-default-n.patch`: the legacy display driver no longer defaults to `y`.
- The device tree: the `fan0` node (no supply, base-speed levels), four active trips and four cooling maps in each of `cpub`, `cpul` and `gpu` zones.
- `scripts/check-image.sh`: fails a build if the PWM or fan driver is missing, the legacy display driver is on, the fan node names a supply, or the fan steps are missing.

## Hardware (the plan; nothing is bought into the design yet)

Header J7, 0.8 mm pitch, on the **same face as the SoC**. Pin 1 (square pad) is ground, pin 2 the control signal (3.3 V logic, through 1 kOhm), pin 3 the system 5 V rail.

| fan wire | J7 pin |
|---|---|
| black (ground) | 1 |
| blue (control) | 2 |
| red (5 V) | 3 |

- First fan to test: GeeekPi 4010 (40 x 40 x 10 mm, 5 V, 3 wires, control wire, 2-pack with M3 x 16 screws and nuts). Listing figures, unverified: 4000 rpm maximum, 4.27 CFM, 20 dB; the seller's photo shows about 60 mA at 5.25 V.
- A printed bracket (4 posts on the board's own holes, 43.8 mm square, plate, fan on top) is being designed; it is not in the repository until a test print has been fitted.
- The mating plug for J7 is not confirmed. A JST SUR 3-way receptacle (03SUR-32S) is a candidate; check against the real connector first.

### First test, before this software is on a board (always on, full speed)
Do not plug the fan's 3-pin plug onto the 40-pin header pins 2/4/6: black would land on a 5 V pin. Pin 8 is the serial console, not a free pin.
Cut the blue wire free, put **red on pin 4 (5 V)** and **black on pin 6 (ground)** after checking the pin numbers on the board, and run the same heat test as in item 13.

## Test plan with this software
1. `scripts/check-image.sh` passes on the new build.
2. On a test card: `cat /sys/class/thermal/cooling_device*/type`, find the `pwm-fan` entry, read `cur_state`, write the hwmon `pwm1` by hand and listen.
3. Find the lowest duty at which the fan spins from a stop and from running; raise level 0 if needed.
4. Try the PWM period (25000 ns now): if the speed does not follow the duty, try about 1 ms.
5. Re-run the 10-minute DS game log and the 5-minute all-core heat test; compare with the 2026-10-13 tables; then tune the trips.

## Open questions
- Does the fan's control wire change speed smoothly with duty, or only on and off?
- Which PWM frequency does it want?
- Does the fan stall at duty 100/255?
