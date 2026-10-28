# Release notes template

Copy the block below into the GitHub release description, fill it in, then post the short version
in Discord. Keep the **Compatibility** block first and unchanged in shape, so people always find
it in the same place. See `UPGRADING.md` for the rules behind it.

---

## Compatibility

- **Update over the air:** yes / no
- **Back up first:** yes / no
- **Needs a fresh install:** yes / no  (if yes: from which versions, and why)
- **Tested on:** device(s), and what was tested (boot, display, audio, controller, update path)

If a fresh install is needed, say so here in plain words and link
[UPGRADING.md](../UPGRADING.md#fresh-install-re-flash).

## What changed

- Fixes:
- New:
- Known issues:
- **Settings changed on existing cards** (written once at the first boot after the update; a value the player already set is never touched, and a player who changes it afterwards is not overridden):
  - Nintendo DS: `nds.retroarch.video_vsync=false`. On a 120 Hz screen this removes the audio warble and the 50 fps hover (docs/a733-gotchas.md, item 20). To turn vsync back on: set the line to `nds.retroarch.video_vsync=true` in `/userdata/system/batocera.conf`.

## Files

- `boot.tar.xz` (+ `.md5`, `.sha256`): the over-the-air update. Devices fetch this.
- `boot.tar.xz.manifest` and `boot.tar.xz.manifest.sig`: the signed description of that update (board, version, size, SHA-256). Devices with signature checking refuse an update without a valid signature (docs/update-signing.md).
- `OctaneOS-<version>.img.gz`: a full image for a fresh install.
- `SHA256SUMS`: check downloads with `sha256sum -c SHA256SUMS`.

## Discord post (paste this)

> **OctaneOS <version> is out.**
> Update over the air: <yes/no>. Back up first: <yes/no>. Needs a fresh install: <yes/no>.
> Notes and files: <link to the release>. How to update or re-flash: <link to UPGRADING.md>.

## Publishing

Use the script. It checks everything, publishes in a safe order, and bumps the OTA version file
last, because that file is what tells devices an update exists:

    scripts/publish-release.sh --notes my-notes.md --dry-run     # all checks, publishes nothing
    scripts/publish-release.sh --notes my-notes.md               # the real thing

It never overwrites an existing release, creates a draft first (devices cannot see drafts),
verifies what GitHub holds, publishes, verifies what a device would download, and only then
commits the version bump locally. **You** push that commit to `main`: until you do, no device is
told about the release. Run it from a fully committed tree.

## Before publishing: do not release if any of these is true

- The image was built with the developer SSH key (`OCTANE_DEV_KEY_FILE` was set).
- `scripts/check-image.sh --release` does not pass.
- The release has no `boot.tar.xz.md5` or `.sha256` (devices refuse to install it).
- The release has no `boot.tar.xz.manifest` / `.manifest.sig`, or the signature was not checked by `scripts/publish-release.sh` (devices with signature checking refuse it).
- The update has only been tried on a computer. Try it on a spare card first.
