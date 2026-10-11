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

## Files

- `boot.tar.xz` (+ `.md5`, `.sha256`): the over-the-air update. Devices fetch this.
- `OctaneOS-<version>.img.gz`: a full image for a fresh install.
- `SHA256SUMS`: check downloads with `sha256sum -c SHA256SUMS`.

## Discord post (paste this)

> **OctaneOS <version> is out.**
> Update over the air: <yes/no>. Back up first: <yes/no>. Needs a fresh install: <yes/no>.
> Notes and files: <link to the release>. How to update or re-flash: <link to UPGRADING.md>.

## Before publishing: do not release if any of these is true

- The image was built with the developer SSH key (`OCTANE_DEV_KEY=1`).
- `scripts/check-image.sh --release` does not pass.
- The release has no `boot.tar.xz.md5` or `.sha256` (devices refuse to install it).
- The update has only been tried on a computer. Try it on a spare card first.
