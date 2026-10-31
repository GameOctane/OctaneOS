#!/usr/bin/env python3
"""Make the default emulator of GameCube and Wii one that exists in this image.

Batocera's generic configgen-defaults.yml says `gamecube` and `wii` run the STANDALONE Dolphin (`emulator: dolphin`).  This image builds
only the libretro Dolphin core (BR2_PACKAGE_LIBRETRO_DOLPHIN), so a GameCube game failed at launch with
"env: 'dolphin-emu-nogui': No such file or directory" (exit 127), and EmulationStation had no menu entry to pick another emulator because
only one is offered.

The per-board file usr/share/batocera/configgen/configgen-defaults-arch.yml overrides the generic one, so this script sets both systems
there to `emulator: libretro, core: dolphin`.  (The Batocera fork stays untouched; this is done to the finished target folder.)

NOT WIRED INTO THE BUILD (decision 2026-10-31).  libretro Dolphin on the Cubie A7S stalls at start-up in the GPU driver (docs/a733-gotchas.md
item 21); this script would only turn an instant launch error into a freeze with dead hotkeys.  It is kept, tested, so it can be switched on
(one line in post-build.sh, and remove gamecube/wii from scripts/default-emulators-accepted.txt) once Dolphin works on this GPU.

Running it twice is fine.  It FAILS if the arch defaults file is missing, so an upstream change gets looked at, not skipped.

Usage: fix-default-emulators.py <target-dir>
Exit status: 0 = set (or already set), 1 = the file was not found, 2 = bad arguments.
"""
import re
import sys
from pathlib import Path

REL = "usr/share/batocera/configgen/configgen-defaults-arch.yml"
SYSTEMS = ("gamecube", "wii")
EMULATOR, CORE = "libretro", "dolphin"
MARK = "# OctaneOS: the standalone Dolphin is not in this image; use the libretro core (scripts/fix-default-emulators.py).\n"


def block(system):
    return f"{system}:\n  emulator: {EMULATOR}\n  core:     {CORE}\n"


def strip_system(text, system):
    """Remove an existing top-level `<system>:` block (the key line and every indented line under it)."""
    return re.sub(rf"^{re.escape(system)}:[ \t]*\n(?:[ \t]+.*\n|[ \t]*\n)*", "", text, flags=re.M)


def apply(text):
    wanted = "".join(block(s) for s in SYSTEMS)
    if MARK + wanted in text:
        return text, False
    for s in SYSTEMS:
        text = strip_system(text, s)
    if text and not text.endswith("\n"):
        text += "\n"
    return text + MARK + wanted, True


def main(argv):
    if len(argv) != 1:
        print(__doc__)
        return 2
    target = Path(argv[0])
    if not target.is_dir():
        print(f"ERROR: {target} is not a folder", file=sys.stderr)
        return 2
    path = target / REL
    if not path.is_file():
        print(f"ERROR: {path} not found (is {target} a finished target folder? did upstream rename the file?)", file=sys.stderr)
        return 1
    new, changed = apply(path.read_text())
    if changed:
        path.write_text(new)
    print(f"[emulators] {'set' if changed else 'already set'}: gamecube and wii default to {EMULATOR}/{CORE}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
