---
name: No picture, or the wrong picture, on a display
about: The screen stays black, says "no signal", or shows the wrong size or refresh rate
title: "[display] "
labels: display
---

**What do you see?**
(black screen, "no signal", a picture that is the wrong size, flickering, ... and when: at start-up, after sleep, after unplugging)

**Your setup**
- OctaneOS version (Start menu > System information, or `cat /usr/share/batocera/octaneos.version` over SSH):
- Board (Radxa Cubie A7S, other):
- Cable or adapter between the board and the display (USB-C to DisplayPort cable, USB-C dock, USB-C to HDMI adapter): brand and model, and
  whether it is a plain/passive cable or an active one if you know:
- Display (monitor or TV model), and whether anything else is in the chain (an AV receiver, a switch):

**Log lines** (log in over SSH and run the command, then paste the output between the lines below)
```
dmesg | grep -E "TCPM|OctaneOS 1008|phy_switcher|sunxidrm" | tail -60
```

```
(paste here)
```

The line `OctaneOS 1008: SRC_READY pd_capable=... vbus_present=...` tells us whether your cable talks USB power delivery
(`pd_capable=1`) or is a plain cable (`pd_capable=0`). Reports with a plain cable are especially useful.
