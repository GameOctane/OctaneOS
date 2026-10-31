# Cubie A7S fan bracket (40 mm fan)

A printable bracket that holds a **40 x 40 x 10 mm fan 15 mm above the SoC heatsinks** of the Radxa Cubie A7S. It bolts to the board's own four
mounting holes (no glue, no drilling, nothing on the board is modified). Licence: [CC BY-NC-SA 4.0](LICENSE.md).

| file | what |
|---|---|
| `a7s-fan-bracket-40mm.stl` | the bracket (plate flat on the bed, posts up) |
| `a7s-fan-gauge.stl` | a 10-minute thin plate to check the four hole positions on your board before printing the bracket |
| `a7s-fan-bracket.scad` | the OpenSCAD source (heights, fan size and window are parameters) |

## Measured with this bracket
Nintendo DS, 10 minutes, fan at full speed: **peak 45 C, average 42 C, no CPU throttling**. The same load with heatsinks only reached 80-81 C and
throttled hard. Details and the other runs: [docs/fan-cooling.md](../../docs/fan-cooling.md).

## What you need
- Radxa Cubie A7S with heatsinks on the SoC and the memory (tested with a 14 x 14 x 7 mm pin-fin on the SoC and a 14 x 10 x 5 mm on the memory)
- A 40 x 40 x 10 mm, 5 V fan (tested with the GeeekPi 4010: 3 wires, comes with M3 x 16 screws and nuts)
- 4 x M2.5 screws, 25 mm, with nuts and washers; the fan's own 4 x M3 x 16 screws and nuts
- Optional: two male-to-female jumper wires if the fan cable is too short for the route to the header

## Print
- **PETG or ASA** for anything left on a running board. PLA / PLA+ softens at roughly 55-65 C. (The tested bracket was PLA+ and stayed rigid
  through a 10-minute run with the fan; that does not make it a long-term material choice.)
- Plate flat on the bed, posts pointing up, no supports. 0.2 mm layers, 4 walls, 30-40% infill.

## Assemble
1. Power the board off and **unplug it** (the 5 V pins stay live while the cable is in).
2. Drop an M3 nut into each hex pocket **under** the plate (masking tape holds them), put the fan on top with its air flowing **down**, and
   drive the M3 screws through the fan into the nuts. Turn the fan so its wires leave toward the header edge.
3. Lower the assembly onto the board; an M2.5 x 25 screw goes down through each corner post and the board, with a washer and nut underneath.
   Snug, not tight.
4. Wiring (full speed, no software needed), on the **30-pin header**: red wire to **pin 4 (5 V)**, black wire to **pin 6 (ground)**. Take the blue
   (control) wire out of the plug and tape its end. **Pin 8 is the serial console: keep it empty.** More on the header: [docs/fan-cooling.md](../../docs/fan-cooling.md).

The fan keeps running after shutdown while the USB-C cable is plugged in (pin 4 is on the always-on 5 V input).

## Not tested
Other heatsink sizes and other fans, long-term behaviour of the plastic near a hot heatsink, and the 30 mm fan option in the source file.
If your heatsink is taller than 9 mm to the fin tips, raise `heat_top` in the OpenSCAD file.
