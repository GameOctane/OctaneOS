#!/usr/bin/env python3
"""Tighten the network defaults of the image being built (phase 1 of docs/security-design-phase1.md).

Patches three files that come from upstream Batocera, in the image's target folder:

  1. etc/samba/smb.conf: guests of the file share can no longer see or open the `system` folder (SSH
     keys, batocera.conf with the Wi-Fi password, configs) or the RetroAchievements credential files
     (`retroachievements.conf`, `.default-retroachievements.conf`).  Saves, states, roms, bios, themes
     and so on stay reachable.  (smb-secure.conf, used when system.security.enabled=1, does not allow
     guests at all, so it needs no change.)
  2. etc/init.d/S60nfs: do not run an NFS server when /etc/exports exports nothing.
  3. usr/share/batocera/services/syncthing: the web page listens on 127.0.0.1 only, unless
     system.syncthing.lan=1 is set in batocera.conf (upstream listens on every address with no login
     unless system.security.enabled=1).

  4. usr/share/batocera/datainit/system/batocera.conf: Wi-Fi is on by default on a fresh card.  The
     radio joins nothing by itself (only networks the user saves), and the country is deliberately NOT
     set here: a wrong country is a legal problem, so the user picks it.  Existing devices keep their
     own setting.

Each edit looks for the exact upstream text and FAILS if it is not there (an upstream change must be
looked at, not silently skipped).  Running it twice is fine: text that is already patched is left alone.

Usage: harden-network-defaults.py <target-dir>
Exit status: 0 = all patched (or already patched), 1 = expected text not found, 2 = bad arguments.
"""
import sys
from pathlib import Path

VETO_OLD = "veto files = /._*/.DS_Store/\n"
VETO_NEW = (
    "# OctaneOS: guests must not see the system folder (SSH keys, the Wi-Fi password, configs) or the\n"
    "# RetroAchievements credential files.  See docs/security-design-phase1.md.\n"
    "veto files = /._*/.DS_Store/system/retroachievements.conf/.default-retroachievements.conf/\n"
)

NFS_OLD = "start() {\n\t# Start daemons.\n"
NFS_NEW = (
    "start() {\n"
    "\t# OctaneOS: nothing exported means nothing to serve; do not run an NFS server for nobody.\n"
    "\tif ! grep -qsE '^[[:space:]]*[^#[:space:]]' /etc/exports; then\n"
    "\t\techo \"NFS: nothing exported in /etc/exports, not starting\"\n"
    "\t\treturn 0\n"
    "\tfi\n"
    "\t# Start daemons.\n"
)

SYNC_OLD = '\t\tSYNCTHING_GUI="http://0.0.0.0:8384"\n'
SYNC_NEW = (
    "\t\t# OctaneOS: the page decides which folders are shared with whom, so by default only the device\n"
    "\t\t# itself can open it (from another computer: ssh -L 8384:127.0.0.1:8384 root@octaneos).\n"
    "\t\t# Set system.syncthing.lan=1 in batocera.conf to open it to the network again.\n"
    '\t\tif [ "$(/usr/bin/batocera-settings-get system.syncthing.lan)" = "1" ]; then\n'
    '\t\t\tSYNCTHING_GUI="http://0.0.0.0:8384"\n'
    "\t\telse\n"
    '\t\t\tSYNCTHING_GUI="http://127.0.0.1:8384"\n'
    "\t\tfi\n"
)


WIFI_OLD = "wifi.enabled=0\n"
WIFI_NEW = "# OctaneOS: Wi-Fi on by default; no network is joined until the user adds one.\nwifi.enabled=1\n"


def patch(path: Path, old: str, new: str, what: str) -> str:
    text = path.read_text()
    if new in text:
        return f"already patched: {what}"
    if text.count(old) != 1:
        raise SystemExit(
            f"ERROR: expected exactly one occurrence of the upstream text for '{what}' in {path}, "
            f"found {text.count(old)}. Upstream changed? Look at the file and update this script."
        )
    path.write_text(text.replace(old, new))
    return f"patched: {what}"


def main(argv):
    if len(argv) != 1:
        print(__doc__)
        return 2
    target = Path(argv[0])
    if not target.is_dir():
        print(f"ERROR: {target} is not a folder", file=sys.stderr)
        return 2
    steps = [
        (target / "etc/samba/smb.conf", VETO_OLD, VETO_NEW, "file share veto list (smb.conf)"),
        (target / "etc/init.d/S60nfs", NFS_OLD, NFS_NEW, "NFS only when something is exported"),
        (target / "usr/share/batocera/services/syncthing", SYNC_OLD, SYNC_NEW, "Syncthing page local-only by default"),
        (target / "usr/share/batocera/datainit/system/batocera.conf", WIFI_OLD, WIFI_NEW, "Wi-Fi on by default on a fresh card"),
    ]
    try:
        for path, old, new, what in steps:
            if not path.is_file():
                raise SystemExit(f"ERROR: {path} not found (is {target} a finished target folder?)")
            print(f"[network] {patch(path, old, new, what)}")
    except SystemExit as e:
        print(e, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
