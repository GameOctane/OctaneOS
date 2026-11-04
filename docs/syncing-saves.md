# Syncing your saves with Syncthing

Syncthing is a program that copies a folder between two devices directly, with no cloud account. OctaneOS (Batocera) already includes it.
This page is what we tested on a real board on 2026-11-03: a Cubie A7S as one device and a Linux server as the other, on the same home network.

**Short version:** sync each profile's `saves` folder, one way (board to your computer) as a backup. That is tested and works. Two-way sync and
syncing other profiles' folders are not tested yet (see the end).

## Before you start
- **Only sync `saves` and `states`. Never the whole profile folder.** Each profile folder also holds `retroachievements.conf`, which has the
  player's RetroAchievements password and Web API key in plain text. Syncing it would copy those to every device.
- **Back up first** (copy `/userdata/profiles` off the card). Syncing is not a backup by itself unless you also keep old versions (below).
- **In-game saves matter most.** RetroAchievements hardcore mode turns save states off, so a hardcore player's progress is the in-game save
  (`.sav`, `.srm`, memory cards), not a state.
- The board's Syncthing page is only reachable from the board itself (by design). To open it from your computer, make a tunnel:
  `ssh -L 8384:127.0.0.1:8384 root@<board-ip>` and then browse to `http://127.0.0.1:8384`. Syncthing is enabled in Batocera's services
  (it was already on in our image).
- **There is no password on that page yet** (a device password is planned). The tunnel keeps it from the rest of the network, but anyone with
  access to the board can open it.

## Where the saves are
| Profile | Saves folder |
|---|---|
| Main (default) | `/userdata/profiles/.default/saves` |
| A named profile | `/userdata/profiles/<name>/saves` |

The folder of the **active** profile is the one games write to. Switching profile changes which folder games use; it does not move any file.

## Setting up a one-way backup (what we tested)
1. Install Syncthing on the other device (we used the Debian package, version 1.27.2; the board runs 2.0.15; they work together).
2. Open each device's Syncthing page and **add the other device** (paste its Device ID). Accept the request on the other side.
3. On the board: **Add Folder**, path `/userdata/profiles/.default/saves`, type **Send Only**. Share it with the other device.
4. On the other device: accept the folder, choose a path, and set the type **Receive Only**.
5. On the receiving side set **File Versioning**. We used **Staggered**, which keeps old copies of a changed file, thinning them out over time.

A send-only folder means the board is the truth: changes on the other side are not pushed back. If someone edits the copy there, Syncthing shows
it as "locally changed" and leaves the board alone.

### The four versioning types
| Type | What it does |
|---|---|
| Trash Can | keeps the old copy for N days after a file is replaced or deleted |
| Simple | keeps the last N versions of each file |
| Staggered | keeps many recent versions and fewer older ones, up to a maximum age |
| External | runs a command you give it |

Versions are kept **by the device that receives a change**. A backup device that only receives is the one that needs versioning.

## What we saw
- **A normal save** (a Chrono Trigger in-game save, `nds/*.sav`) reached the other device in about 10 seconds. The old version was kept in
  `.stversions`.
- **21 save files** from the main profile matched a separately verified backup byte for byte.
- **A delete** on one side reached the other side, with the deleted file kept as a version (in a two-way test folder).
- **A conflict** (the same file edited on both sides at once, two-way test folder): both files were kept. The newer edit won and the other became
  a `.sync-conflict-<date>` file. Nothing was lost.
- **Switching profile** (to another profile and back) did not change, delete or re-send anything in the synced folder.

## Privacy and network settings (do these)
Syncthing also, by default, talks to the internet: it uses UPnP/NAT to open a port on your router, relay servers, and a global discovery server to
find devices. For two devices on the same home network you do not need any of them.
- On each device open **Actions > Settings > Connections** and untick **Enable NAT traversal**, **Global Discovery** and **Enable Relaying**.
- We did this on the server. On the board it is **still on** in our test and has to be unticked in its page.
- Without global discovery you add the other device by its LAN address (for example `tcp://192.168.1.51:22000`) or rely on local discovery.

## Keeping Syncthing running on the other device
On a Linux computer that is not logged in all the time, run it as a user service and enable "linger" so it starts at boot:
```
systemctl --user enable --now syncthing.service
sudo loginctl enable-linger $USER
```
We set this up on the test server (the Debian package ships the user unit, and linger is on). We have not rebooted the server to prove it comes back by itself.

## Not tested yet
- **Two-way sync of real saves** (so two OctaneOS devices share progress). The test above is board to computer only.
- **Other profiles' `saves` folders**, and a second device with its own profiles.
- **Switching profile while a game is running**, and savestates between devices or versions.
- **Encrypted folders** (so a hub that stores your saves cannot read them) and **device passwords**.
- **Downgrading** after saves have moved into profiles: the notes on going back to an older version are in a separate change (`docs/profiles-downgrade.md`, not merged yet).

Treat anything on this list as unproven until it is tested, and keep your backup.
