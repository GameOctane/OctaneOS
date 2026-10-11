# Network and password defaults: design (phase 1)

Status: **proposed, not built.** Written 2026-10-11 after the audit of the running system. Nothing
here changes a device until the decisions at the end are made.

## Where we are today (checked on a real board)

| Door | State today | Why it matters |
|---|---|---|
| SSH | on; `root` / `linux` for everyone | anyone on the network can log in as root |
| File share | `[share]` = all of `/userdata`, guests allowed, files owned by root | anyone on the network can read and write everything, including `system/.ssh/authorized_keys` (permanent root) and `system/batocera.conf` (holds the Wi-Fi password) |
| Syncthing | web page on port 8384 on every network address, no login, no encryption | anyone on the network can share any folder to themselves |
| NFS | server running, nothing exported | unused service listening |
| RetroAchievements | username, password and token in plain text in `retroachievements.conf` per profile (copied from `batocera.conf` when a profile is created) | readable through the open share |

Stock Batocera ships the same SSH and share defaults. We are not worse than Batocera, but we can
be better where it costs the tinkerer nothing.

## Principles (from the decisions made so far)

1. The audience is tinkerers: **SSH and file transfer stay on by default.** Nobody should have to
   pull the SD card to copy a ROM.
2. Console-like: profiles are the accounts. **Switching profile needs no password.** Profiles share
   the games and keep their own saves.
3. **One device password** for the things that can change the device: SSH, the protected files,
   the Syncthing page. It replaces the shared `linux`.
4. Anything that can change the device needs either the password or a local connection.
5. No release may require a wipe (see `UPGRADING.md`): everything below must arrive over the air.

## What changes

### Phase 1: configuration only, low risk, no user action needed

- **File share:** keep the guest share for what people copy (roms, bios, saves, themes, music,
  screenshots), but guests can no longer see or touch:
  - the `system` folder (SSH keys, `batocera.conf` with the Wi-Fi password, configs);
  - the per-profile RetroAchievements credential files (`retroachievements.conf` in each profile
    folder, and the hidden `.default-retroachievements.conf`; both hold the username, password and
    token in plain text).
  Saves stay reachable, so backing up a profile still works. How: Samba `veto files` (or a second,
  password-protected share for `system`). To verify before building: how it behaves with Windows,
  macOS and Linux clients, and that a ROM folder that happens to be called `system` is not hidden.
- **Syncthing web page:** bind to `127.0.0.1` (reachable only from the device itself) until a
  device password exists. With a password it becomes reachable, with the same password and TLS.
- **Stop the unused NFS server** (nothing is exported).

### Phase 2: the device password

- **First boot:** an EmulationStation screen "Set a device password (used for SSH and the Syncthing
  page)". It can be skipped; until it is set, the device behaves as today for SSH, but phase 1
  protections already apply.
- **Stored properly:** a modern password hash (today's root hash is an old MD5). To verify before
  building: how Batocera persists the root password across reboots, so we reuse its mechanism and
  do not invent one.
- **Existing devices** get the same screen once, on the first boot after the update (a migration
  step, like the one that already adds `updates.url`).
- **Forgotten password:** from any computer, create an empty file called `reset-password` on the
  boot partition (it is a normal FAT disk). On the next boot the password is reset and the file is
  removed. Anyone with the card could change the system anyway, so this adds no new exposure.
- Advanced users can still add an SSH key and turn password login off. Documented, not the default.

### Phase 3: profile syncing (later)

Each profile folder (saves, states) can be shared with another device through Syncthing, nothing
shared by default, matching `batocera-profiles-spec-v0.1.md`. A "sync this profile to another
device" menu entry with a short pairing code is the friendly version. Not designed in detail yet.

## What this does not protect against

- Someone who has the SD card or the device in their hands.
- Someone who knows the device password: they can read the Wi-Fi password and the profile files.
- A hostile device on the same network that guesses a weak password. Hence: ask for a good one.

## Tests we will write first

Same approach as the updater: run against a throw-away copy of the configuration, then on a real
board. Cases: guest cannot list or open `system` or the credential files; guest can still copy a
ROM in and a save out; the Syncthing page refuses non-local connections until a password is set;
the first-boot migration runs once; the reset file works and is removed; an update from the current
image keeps everything.

## Decisions needed

1. **Hide `system` and the RetroAchievements credential files from guests** on the file share. Yes?
2. **If the user skips the password,** leave SSH on `linux` as today (my suggestion, with a visible
   reminder in the menu), or generate a random one?
3. **The reset-by-file method** on the boot partition. Acceptable?
4. **Once a password is set,** keep SSH password login on (my suggestion) or require a key?

## Unknowns to verify before building

- How Batocera persists the root password (and whether its "security" option can be reused).
- Samba behaviour of `veto files` across client operating systems.
- Editing Syncthing's configuration without breaking existing pairings.
- Resolved: the profile code (`batocera-profiles`) writes `retroachievements.conf`, not the
  `retroarch.cfg.override` that the spec names, so the spec is out of date on that point. The
  RetroAchievements password is also still in `batocera.conf`. A later improvement is to store
  RetroAchievements' login token and not the password.
