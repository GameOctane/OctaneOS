# Upgrading OctaneOS

Most releases update over the air (OTA) from the menu. Once in a while you may be asked to
start over with a fresh image. This page says which is which, how to back up first, and what to
do if an update goes wrong.

## The rule

**A release should never need a wipe.** A fresh install is reserved for the few changes that an
update cannot reach: the bootloader or the layout of the SD card. If a release ever needs one,
its release notes say so in the first lines (see "Compatibility" below), and this page lists it
under "Releases that need a fresh install".

Everything else (kernel, system, EmulationStation, emulators, settings migrations) goes over the
air and keeps your games, saves and profiles.

## Updating over the air

1. Make sure the device is charged or plugged in, and on Wi-Fi.
2. Main menu, **Updates & Downloads**, then **Start Update**.
3. Wait. The download is about 2 GB and the install takes a few minutes. **Do not switch the
   device off while it says it is installing.**
4. When it says it is done, restart.

From the release that introduced the checking updater onward, the updater refuses to install an
update that has no valid checksum, is for a different board, or is damaged. In those cases
nothing on the device is changed, and it tells you why. (Devices on older versions install their
first update with the older, less strict updater.)

## Back up before a risky update

Your saves and profiles live on the SD card, so back them up before any update you are unsure
about, and always before a fresh install.

With the file share (Windows, `\\OCTANEOS\share`; Linux and macOS, `smb://octaneos/share`), copy
these folders to your computer:

- `saves`
- `profiles` (one folder per profile, including its RetroAchievements settings)

With SSH, for example:

    scp -r root@octaneos:/userdata/saves .
    scp -r root@octaneos:/userdata/profiles .

Optional: `/userdata/system/batocera.conf` holds your settings. **It also contains your Wi-Fi
password**, so keep any copy private.

## Fresh install (re-flash)

1. Back up as above.
2. Download the `.img.gz` from the [latest release](../../releases/latest).
3. Flash it as described in the README (section "Download"): Balena Etcher on Windows, `dd` on
   Linux.
4. If the release includes a `SHA256SUMS` file, check the download first:
   `sha256sum -c SHA256SUMS` in the folder you downloaded to.
5. Boot, then copy `saves` and `profiles` back to the same places.

Flashing replaces everything on the card, including your games folder, so back that up too if
you copied games onto the card.

## If an update goes wrong

- **It says the update failed:** nothing was changed. Try again, or check your connection.
- **The download stops part-way:** run the update again. It resumes where it stopped.
- **The device will not start after an update:** re-flash it (above) and restore your backup.
  Please also open an issue and say which version you came from and what you saw.

## Compatibility

Every release's notes start with a block like this (copy it from
`docs/release-notes-template.md`):

    Update over the air: yes / no
    Back up first: yes / no
    Needs a fresh install: yes / no   (from which versions)

## Releases that need a fresh install

None recorded in this file yet.
