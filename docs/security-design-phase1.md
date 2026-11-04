# Network and password defaults: design (phase 1)

Status: **phase 1 implemented (2026-10-11), phases 2 and 3 not built.** Written after the audit of the
running system. The four decisions at the end were made on 2026-10-11 (see there).

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

## Live test of the share veto (real board, 2026-10-11, Samba 4.20.6)

Applied to the running board in memory only, then reverted. As an anonymous guest, before and after:

| Attempt | Before | After |
|---|---|---|
| list `system` | listed | not listed |
| read `system/.ssh/authorized_keys` and `system/batocera.conf` | readable | not found |
| write into `system/` | allowed | not found |
| `System`, `SYSTEM` spellings | n/a | not found |
| read `retroachievements.conf`, `.default-retroachievements.conf` | n/a | hidden, not found |
| read, write and delete a save | allowed | still allowed |
| create a symlink (SMB3) | n/a | refused, nothing created |
| create a symlink (SMB1) | n/a | the server refuses SMB1 entirely |

**Known limit:** the veto works on names. If a symlink INTO `system` already exists (an administrator
made it), a guest can read through it: the test read `batocera.conf` that way. Guests cannot create
symlinks, and the card has none pointing there, so the default layout is protected, but this is not
absolute. `follow symlinks = no` would close it but breaks people who link ROM folders elsewhere, so it
is left for phase 2 after checking how common that is.

## Decisions (made 2026-10-11)

1. Hide `system` and the RetroAchievements credential files from guests: **yes** (done in phase 1).
2. A skipped password leaves SSH on `linux`, with a visible reminder: **yes** (phase 2).
3. Reset a forgotten password by a file on the boot partition: **yes** (phase 2).
4. SSH password login stays on once a password is set: **yes**.
5. Wi-Fi on by default on fresh cards, country not set: **yes** (done in phase 1).

## Decisions that were open

1. **Hide `system` and the RetroAchievements credential files from guests** on the file share. Yes?
2. **If the user skips the password,** leave SSH on `linux` as today (my suggestion, with a visible
   reminder in the menu), or generate a random one?
3. **The reset-by-file method** on the boot partition. Acceptable?
4. **Once a password is set,** keep SSH password login on (my suggestion) or require a key?

## Unknowns to verify before building

- Resolved (2026-11-04, by reading the Batocera code in the fork; **not yet run on a board**): how Batocera persists the root password.
  See "How Batocera stores the root password today" below.
- Samba behaviour of `veto files` across client operating systems.
- Editing Syncthing's configuration without breaking existing pairings.
- Resolved: the profile code (`batocera-profiles`) writes `retroachievements.conf`, not the
  `retroarch.cfg.override` that the spec names, so the spec is out of date on that point. The
  RetroAchievements password is also still in `batocera.conf`. A later improvement is to store
  RetroAchievements' login token and not the password.

## How Batocera stores the root password today (read from the code, 2026-11-04)
Batocera already has a "security" option. We should reuse it and not invent a second mechanism.

- **The switch:** `system.security.enabled` in `batocera.conf`. Off (the default): the root password is the fixed word `linux`, for SSH and for the
  file share. On: a password is used instead.
- **Where it is kept:** in `/boot/batocera-boot.conf` (the FAT boot partition) as `rootshadowpassword=enc:...`. If the line is empty the first boot
  makes a random 8-character password. `batocera-config setRootPassword <word>` stores a chosen one and `getRootPassword` reads it back.
- **How it is "protected":** `batocera-encode` encrypts it with AES-128-CBC using a key made from the CPU serial number plus the ethernet MAC address.
  That is **reversible**, and the key comes from the device, so anyone with the card (or SSH access) can read it back. It hides the word from a quick
  look, nothing more. This is the real answer to "is today's password stored as a hash": it is not hashed at all.
- **How it is applied:** `/etc/init.d/S35securepasswd` runs at every boot. It reads the stored word, writes `/run/batocera.shadow` (in memory only)
  with `openssl passwd -1` (this is the old MD5 crypt), and sets the Samba password with `smbpasswd`. So the login hash is rebuilt at each boot.
- **EmulationStation** already has a Security entry that toggles `system.security.enabled` and shows the password on screen.

### What this means for our phase 2 design
1. **No new storage mechanism.** The first-boot screen only has to call `setRootPassword <chosen word>` and set `system.security.enabled=1`.
2. **A strong hash is easy for SSH:** change `openssl passwd -1` to `-6` (SHA-512) in S35securepasswd. This is a one-word change in a patch.
3. **Samba is the catch.** Samba needs the password itself (or its NT hash, which is weak). So the word must still be recoverable at boot, which
   is why Batocera stores it reversibly. A real one-way hash is possible for SSH only. We should accept this, or drop Samba password login
   (the file share is already narrowed in phase 1). **Decision needed.**
4. **The reset file** (`reset-password` on the boot partition) fits: S35 can look for it at boot, clear `rootshadowpassword`, and delete the file.
5. **The key depends on the board.** The encryption key uses the CPU serial and the ethernet MAC. We have not checked whether the A7S has a
   `Serial` line in `/proc/cpuinfo` or an `eth*` interface that is always present. If either is missing or changes (for example a USB ethernet
   dongle), the stored password could fail to decode and a new one would be generated. **To verify on the board** before relying on this.
6. **The Syncthing page** is not covered by any of this: it needs its own setting (its GUI password) set from the same screen.
