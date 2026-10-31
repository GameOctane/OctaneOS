#!/usr/bin/env python3
"""Check that every system's DEFAULT emulator and core actually exist in a built image.

Batocera picks the emulator for a system from configgen-defaults.yml (overridden per board by configgen-defaults-arch.yml) unless the
user chose another one.  EmulationStation's menu only lists what the image really contains (es_systems.cfg).  If the default names an
emulator that is not in that list, the game fails at launch ("env: 'dolphin-emu-nogui': No such file or directory", exit 127) and the
menu cannot even offer another choice when only one exists.  The GameCube and Wii entries had exactly this fault in 0.8.0.

Checks, per system that is present in es_systems.cfg:
  1. the default (emulator, core) pair appears in that system's emulator list in es_systems.cfg;
  2. when the emulator is libretro and the cores are visible in the target folder, the core library
     /usr/lib/libretro/<core>_libretro.so exists.  (The image keeps most cores in a second filesystem layer, "rufomaculata", which is
     not in the target folder; then this check is skipped and says so, because a missing file there would prove nothing.)
A system with no entry in the defaults is skipped (EmulationStation then uses the core marked default="true").

Usage: scripts/audit-default-emulators.py [TARGET_DIR] [--accepted FILE]
  TARGET_DIR   the image's target folder (default: the last build's)
  --accepted   a list of systems whose mismatch we have looked at and accept (scripts/default-emulators-accepted.txt); they are listed
               as ACCEPTED and do not fail.  An accepted system that no longer has a problem is reported, so the list stays honest.
Exit status: 0 = no unaccepted problems, 1 = at least one system's default cannot work, 2 = the files could not be read.
"""
import os
import sys
import xml.etree.ElementTree as ET

try:
    import yaml
except ImportError:
    print("this script needs PyYAML (python3 -c 'import yaml')", file=sys.stderr)
    sys.exit(2)

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_TARGET = os.path.join(REPO_ROOT, "batocera", "output", "a733-cubie-a7s", "target")


def load_defaults(target):
    base = os.path.join(target, "usr", "share", "batocera", "configgen")
    merged = {}
    for name in ("configgen-defaults.yml", "configgen-defaults-arch.yml"):  # the arch file overrides the generic one
        path = os.path.join(base, name)
        with open(path) as fh:
            data = yaml.safe_load(fh) or {}
        for system, entry in data.items():
            if isinstance(entry, dict):
                merged.setdefault(system, {}).update(entry)
    return merged


def load_systems(target):
    """{system: {emulator: [cores]}} as EmulationStation will offer it."""
    tree = ET.parse(os.path.join(target, "usr", "share", "emulationstation", "es_systems.cfg"))
    systems = {}
    for sysnode in tree.getroot().iter("system"):
        name = (sysnode.findtext("name") or "").strip()
        emus = {}
        for emu in sysnode.iter("emulator"):
            emus[emu.get("name")] = [(c.text or "").strip() for c in emu.iter("core")]
        if name:
            systems[name] = emus
    return systems


def audit(target):
    defaults = load_defaults(target)
    systems = load_systems(target)
    libretro_dir = os.path.join(target, "usr", "lib", "libretro")
    cores_visible = os.path.isdir(libretro_dir) and any(f.endswith("_libretro.so") for f in os.listdir(libretro_dir))
    problems = []
    checked = 0
    for system, emus in sorted(systems.items()):
        entry = defaults.get(system)
        if not entry:
            continue
        checked += 1
        emulator, core = entry.get("emulator"), entry.get("core")
        if emulator not in emus:
            problems.append((system, "default emulator '%s' is not offered (the image offers: %s)" % (emulator, ", ".join(sorted(emus)) or "nothing")))
            continue
        if core not in emus[emulator]:
            problems.append((system, "default core '%s' is not offered for emulator '%s' (offered: %s)" % (core, emulator, ", ".join(emus[emulator]) or "nothing")))
            continue
        if emulator == "libretro" and cores_visible:
            lib = os.path.join(libretro_dir, "%s_libretro.so" % core.replace("-", "_"))
            lib_alt = os.path.join(libretro_dir, "%s_libretro.so" % core)
            if not (os.path.exists(lib) or os.path.exists(lib_alt)):
                problems.append((system, "default libretro core '%s' has no library in /usr/lib/libretro" % core))
    return checked, len(systems), problems, cores_visible


def load_accepted(path):
    accepted = set()
    with open(path) as fh:
        for line in fh:
            word = line.split("#", 1)[0].strip()
            if word:
                accepted.add(word.split()[0])
    return accepted


def main(argv):
    args = argv[1:]
    accepted_file = None
    if "--accepted" in args:
        i = args.index("--accepted")
        if i + 1 >= len(args):
            print("--accepted needs a file name", file=sys.stderr)
            return 2
        accepted_file = args[i + 1]
        del args[i:i + 2]
    target = args[0] if args else DEFAULT_TARGET
    try:
        accepted = load_accepted(accepted_file) if accepted_file else set()
        checked, total, problems, cores_visible = audit(target)
    except (OSError, ET.ParseError, yaml.YAMLError) as exc:
        print("cannot read the image files under %s: %s" % (target, exc), file=sys.stderr)
        return 2
    print("%d systems in es_systems.cfg, %d with a default emulator checked" % (total, checked))
    if not cores_visible:
        print("note: no libretro cores in %s/usr/lib/libretro (they are in the second layer), so the core-library check was skipped" % target)
    new_problems = [(s, t) for s, t in problems if s not in accepted]
    for system, text in problems:
        print("  %-8s %-16s %s" % ("ACCEPTED" if system in accepted else "PROBLEM", system, text))
    still = {s for s, _ in problems}
    for system in sorted(accepted - still):
        print("  note: '%s' is in the accepted list but has no problem any more; remove it from %s" % (system, accepted_file))
    if new_problems:
        print("%d system(s) have a default that cannot work in this image" % len(new_problems))
        return 1
    print("every default emulator and core exists in the image%s" % (" (apart from %d accepted)" % len(problems) if problems else ""))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
