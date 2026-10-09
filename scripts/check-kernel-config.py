#!/usr/bin/env python3
"""Compare the kernel options we ask for with the kernel config that was actually built.

Kconfig silently drops an option whose dependencies are not met, so a line in
linux-defconfig.config or linux-defconfig-fragment.config can do nothing and nobody notices.
This happened to CONFIG_THERMAL (every thermal option was dropped) and to CONFIG_CPU_IDLE.

An option that was asked for (=y or =m) fails the check when it is missing from the built
.config, or is "not set", unless board/.../kernel-config-accepted.txt lists it:
    accepted OPTION  reason        a known, harmless drop (silent)
    gap      OPTION  reason        a real gap we have not fixed yet (printed every run)
Asking for y and getting m, or m and getting y, is fine.

Usage: scripts/check-kernel-config.py <built .config> [requested file ...]
Exit status: 0 = nothing new is missing, 1 = something new is missing.
"""
import re
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
A733 = REPO / "board/batocera/allwinner/a733"


def parse(path):
    opts = {}
    for line in Path(path).read_text().splitlines():
        line = line.strip()
        if m := re.match(r"CONFIG_(\w+)=(.*)", line):
            opts[m.group(1)] = m.group(2)
        elif m := re.match(r"# CONFIG_(\w+) is not set", line):
            opts[m.group(1)] = "n"
    return opts


def main(argv):
    if not argv:
        print(__doc__)
        return 2
    built = parse(argv[0])
    requested_files = argv[1:] or [str(A733 / "linux-defconfig.config"),
                                   str(A733 / "linux-defconfig-fragment.config")]
    accepted, gaps = {}, {}
    listing = A733 / "kernel-config-accepted.txt"
    if listing.exists():
        for line in listing.read_text().splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            kind, opt, *reason = line.split(None, 2)
            (accepted if kind == "accepted" else gaps)[opt] = " ".join(reason)

    new, total = [], 0
    for f in requested_files:
        for opt, want in parse(f).items():
            if want == "n":
                continue
            total += 1
            got = built.get(opt, "missing")
            if got in ("missing", "n") and opt not in accepted and opt not in gaps:
                new.append((opt, want, got, Path(f).name))
    print(f"checked {total} requested kernel options against {argv[0]}")
    for opt, reason in sorted(gaps.items()):
        state = built.get(opt, "missing")
        if state in ("missing", "n"):
            print(f"  NOTE  known gap CONFIG_{opt} ({state}): {reason}")
        else:
            print(f"  NOTE  CONFIG_{opt} is now {state} but is still listed as a known gap; remove it from the list")
    for opt, want, got, src in new:
        print(f"  FAIL  CONFIG_{opt}={want} requested in {src} but the built kernel has it as: {got}")
    if new:
        print("  A dropped option usually means a parent option is missing; find it with")
        print("  'grep -n -B3 -A8 \"config OPTION\"' in the kernel's Kconfig files.")
    return 1 if new else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
