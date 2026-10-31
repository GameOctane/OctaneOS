# Releasing OctaneOS

How a release is made, start to finish. It was written after the 0.8.0 release (the first signed one), so every step has been done for real.
The rules behind it: [update-signing.md](update-signing.md) (keys and signing), [../UPGRADING.md](../UPGRADING.md) (what players are told),
[release-notes-template.md](release-notes-template.md) (the notes).

Three places are involved, and the private keys never leave the second one:

| where | what happens there |
|---|---|
| the **build server** | build, checks, publish script |
| your **signing PC** (not the server) | holds the private keys, signs one small text file |
| a **test device** | proves the real update works before anyone is told |

**What announces a release is one file:** `ota/cubie-a7s/stable/last/batocera.version` on the `main` branch. Devices show "update available" when it
differs from what they run. The release itself can be public and quiet for as long as you like; merging the version file is the announcement.

## Before you start
- `main` is green, and the changes for this release are merged (see their branches' test notes).
- The two public keys are in `keys/update/` (`primary.pub.pem`, `backup.pub.pem`). The private primary key and its passphrase are within reach.
- `git config user.name` and `user.email` are set on the build server (the publish script now checks this before it publishes anything).
- Decide the version number. Bigger changes or new safety features deserve a new minor number (0.7.x to 0.8.0).

## 1. Prepare the branch
1. `git checkout -b release/X.Y.Z main`
2. In `board/batocera/allwinner/a733/post-build.sh` raise `OCTANE_BUILD_NUMBER`, `OCTANE_RELEASE_TAG` (`vX.Y.Z`) and `OCTANE_VERSION_STRING` (`X.Y.Z`).
3. Write `docs/releases/X.Y.Z.md` from the template: the Compatibility block first, then What changed, Known issues, Files. **Claim only what was
   tested**; say what was not. Leave out the Discord block and any `<placeholder>` (the publish script refuses notes that contain `yes / no`,
   `<version>` or `<link`). Keep the Discord text in a separate file.
4. Commit.

## 2. Build with no developer key
```
cd /srv/data/octaneos
env -u OCTANE_DEV_KEY_FILE ./scripts/build.sh --nohup
```
About 15 minutes (a kernel change makes it longer). When it ends, `./scripts/check-image.sh --release` must say **ALL CHECKS PASSED**, with no
developer SSH key, no unsigned-update marker, and the two update keys equal to `keys/update/`.

## 3. Push the branch
```
git push -u origin release/X.Y.Z
```
GitHub only creates a release at a commit it has. (Without this the publish script stops with "the commit ... is not on GitHub".)

## 4. Dry run, then sign
```
./scripts/publish-release.sh --notes docs/releases/X.Y.Z.md --dry-run
```
It re-runs the checks, writes `boot.tar.xz.manifest` (six short lines) and stops with **NOT SIGNED YET**. On the signing PC:

1. Get the manifest file onto that PC (copy the file itself; do not retype it). **Read it:** `board=cubie-a7s`, `version=X.Y.Z`, `file=boot.tar.xz`, and a
   size and hash that match the build.
2. Sign with the primary key (it asks for the passphrase; nothing shows as you type):
   `openssl pkeyutl -sign -inkey primary.key.pem -rawin -in boot.tar.xz.manifest -out boot.tar.xz.manifest.sig`
3. Check it: `openssl pkeyutl -verify -pubin -inkey primary.pub.pem -rawin -in boot.tar.xz.manifest -sigfile boot.tar.xz.manifest.sig`
   must print `Signature Verified Successfully`.
4. Bring the 64-byte signature back. A signature is not secret, so text is fine: `base64 -w0 boot.tar.xz.manifest.sig`, then on the server
   `echo '<that text>' | base64 -d > <images folder>/boot.tar.xz.manifest.sig`
5. Check on the server that it verifies with the primary key and **not** with the backup (that is correct, the backup did not sign it).

## 5. Publish
```
./scripts/publish-release.sh --notes docs/releases/X.Y.Z.md
```
It creates a draft, checks every file's size and bytes on GitHub, publishes, checks what a device would download, and **commits the version
file locally**. If a step fails before "publishing", the draft is deleted and nothing is public. **Do not push the version commit yet.**

## 6. Test the real update on a device, before announcing
On a test device that runs the previous version, use the public release exactly as a player would. The test below loads the real public keys into
memory and switches off the developer exemption, so it checks your real signature. Run it in the background on the device, so a lost connection
cannot cut an install in half:

```
mkdir -p /tmp/realkeys   # copy keys/update/primary.pub.pem and backup.pub.pem there as primary.pem and backup.pem
nohup sh -c 'OCTANE_KEYS_DIR=/tmp/realkeys OCTANE_ALLOW_UNSIGNED_FLAG=/nonexistent batocera-upgrade > /userdata/system/ota-test.log 2>&1; echo "EXIT CODE: $?" >> /userdata/system/ota-test.log' &
```
Expect `signature valid`, an exit code of 0, and (about 9 minutes later) every file of `boot.tar.xz` identical to the board's `/boot`
(compare checksums). Then reboot: the menu must show the new version, a game must start, picture and sound must be normal.
A release image has no developer key, so you cannot log in over SSH after this; check by eye.

## 7. Announce
1. `git push origin release/X.Y.Z` (this adds the one version-file commit).
2. Open the pull request into `main`, wait for CI, merge. **The merge is the announcement.**
3. Post the Discord text.
4. Check the release page and the download counts; delete merged branches and old draft releases.

## When it goes wrong
| message | meaning and fix |
|---|---|
| `the release notes still contain template placeholders` | remove `<version>`, `<link ...>`, `yes / no` from the notes file |
| `the commit ... is not on GitHub` | push the branch you built from (step 3) |
| `git has no name or email set` | `git config --global user.name ...` and `user.email ...` |
| `NOT SIGNED YET` | expected: sign the manifest (step 4) and run again |
| `the signature does not match any key` | signed with the wrong key, or the manifest was edited; sign again |
| `the manifest ... does not describe this build` | an old manifest is lying next to a new build; delete it and the `.sig`, run the dry run again |
| `the image check failed` | fix what it lists and rebuild; nothing was published |

## Rules that do not bend
- **Never put a private key on the build server, in the repo, in email, or in cloud storage.** Never paste one or a passphrase into a chat.
- **Test images carry a developer key and accept unsigned updates. They are never released** (`check-image.sh --release` refuses them).
- **Never push the version file before the real update has been tested.**
- A first signed release reaches devices that still run the old updater **without** a signature check; say so in the notes.
- Do not print logs that may hold credentials (EmulationStation's debug log writes the RetroAchievements token in clear).
