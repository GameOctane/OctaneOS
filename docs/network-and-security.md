# Network and security on OctaneOS

What your device shares on the network, what is protected, and how to change it. Written for v0.7.0.
Everything here was checked against the built system; where something has not been tested on a device it says so.

## What is on by default

| Service | Default | Who can reach it |
|---|---|---|
| **File share** (`\\octaneos\share`, Windows/Mac/Linux file sharing) | on | anyone on your network, **without a password** |
| **SSH / SFTP / scp** | on | anyone on your network who knows the password. The default login is `root` / `linux` |
| **Syncthing** (folder syncing, web page on port 8384) | on | the **page** is reachable only from the device itself (the sync itself still works) |
| **NFS** (another file-sharing system) | off | nothing is exported, so it does not start |
| **Wi-Fi** | on for fresh installs | joins nothing until you add a network |

Anyone on the same network can read and change what the file share shows. That is how ROM transfer works without any
software, and it is fine on a home network you trust. It is **not** fine on a shared or public network (a dorm, a
convention, hotel Wi-Fi). Use Security mode below, or leave Wi-Fi off, in those places.

## What the file share hides

Guests of the file share do not see:

- the `system` folder, which holds `batocera.conf` (your settings, **including your Wi-Fi password**) and the SSH
  login keys;
- the RetroAchievements credential files (`retroachievements.conf`) in the profile folders.

Saves, ROMs, BIOS files, themes and your profile folders' saves are shared as before.

One limit: this hides things by **name**. If you create a shortcut (symbolic link) that points into `system`, a guest
can read through it. Don't create links into `system`.

## Reaching everything on the device (including `system`)

The file share hides `system`, but SSH does not. With SFTP or `scp` you can see all of `/userdata`:

    sftp root@octaneos
    scp root@octaneos:/userdata/system/batocera.conf .
    scp batocera.conf root@octaneos:/userdata/system/

(`octaneos` can be replaced with the device's IP address.) On Windows, [WinSCP](https://winscp.net) does the same
with a window. The password is `linux` unless you turned on Security mode.

## Setting a real password: Security mode

OctaneOS includes Batocera's Security mode. It does two things:

- The SSH password becomes a random one (or one you choose) instead of `linux`.
- The file share stops allowing guests; you log in as `root` with that password.

To turn it on, set `system.security.enabled=1` in `/userdata/system/batocera.conf`, or use the **ENFORCE SECURITY** entry in EmulationStation's
settings, and reboot.

- The password is stored in `/boot/batocera-boot.conf`; EmulationStation's **ROOT PASSWORD** entry shows it.
- To choose your own: `ssh root@octaneos`, then `batocera-config setRootPassword <your-password>`, then reboot.
- To turn it off again, set `system.security.enabled=0` and reboot (the password goes back to `linux`).

Not tested for this release: ROM transfer from a phone or computer that expects the no-password share. If you rely on
that, test it before you turn Security mode on.

A planned update adds a device password screen on first boot, so you do not have to do this by hand.

## Syncthing's page

Syncthing keeps folders in sync between devices. Its settings page (port 8384) decides what is shared with whom, so by
default only the device itself can open it.

- **From your computer, safely:** `ssh -L 8384:127.0.0.1:8384 root@octaneos`, then open http://127.0.0.1:8384 in your
  browser while that command keeps running.
- **Open it to your whole network again** (only on a network you trust): set `system.syncthing.lan=1` in
  `/userdata/system/batocera.conf` and reboot.

## NFS

NFS only starts if `/etc/exports` has an entry. The system image ships it empty, and the root filesystem is rebuilt
at every boot, so a change to it does **not** survive a restart. We have not written or tested a recipe for a
permanent NFS export. For sharing files, use the file share or SFTP above. If you need NFS, tell us on Discord.

## Switching things off

- File share: `system.samba.enabled=0` in `batocera.conf`.
- Wi-Fi: EmulationStation, Network Settings, or `wifi.enabled=0` in `batocera.conf`.

Set your Wi-Fi country in Network Settings. We do not preset it, because the right value depends on where you are.

## Updates

Updates come from this project's GitHub releases over HTTPS and are refused unless their checksum matches. See
[UPGRADING.md](../UPGRADING.md). Signed updates, which also protect against a tampered release, are written and tested but not released yet:
see [update-signing.md](update-signing.md). (Devices on 0.7.0 do not check signatures, so the first signed release reaches them unprotected.)

## Reporting a problem

If you find a security problem, please do not post it publicly. Contact us through
[GameOctane.com](https://gameoctane.com) or message a maintainer on [Discord](https://discord.gg/pnuamjT) first.
