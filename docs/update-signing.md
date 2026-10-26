# Signed updates

Status: **implemented and tested with throw-away keys; the real keys do not exist yet.** Until the two public keys are in
`keys/update/`, a release build and `scripts/publish-release.sh` fail on purpose.

## What it protects, and what it does not

Before this, an update was protected by HTTPS and a checksum, but the checksum was published **next to the file**. Anyone who could
replace the file on GitHub (a stolen token, a hijacked account) could replace the checksum too, and every device would install it as root.

Now every update must carry a **signature** made with a private key that never touches GitHub or the build server. The device holds the
matching public keys in its read-only system image and installs nothing that does not verify.

It does **not** protect against: a stolen private key (hence the passphrase, the offline machine and the backup key), you signing something
bad, or a device that is still on a version that predates signing: **0.7.0 does not check signatures**, so the first signed release reaches
those devices unprotected; protection starts from the next update. The "update available" notice (the version file on GitHub) is not signed;
it only prompts the player, and the install itself is what is checked.

## How it works

```
build server                          your offline machine                 GitHub               device
------------                          --------------------                 ------               ------
boot.tar.xz  ->  make-manifest   ->   release manifest (text)
                                      sign with the PRIVATE key  -> .sig
publish-release.sh checks the .sig against keys/update/*.pub.pem, then uploads: boot.tar.xz, .manifest, .manifest.sig
                                                                                         ->   downloads the small manifest + signature first
                                                                                              checks the signature with the public keys in the image
                                                                                              checks board, version (no downgrade), size
                                                                                              downloads the archive, checks its sha256 against the manifest
                                                                                              only then installs, exactly as before
```

The **manifest** is five lines (`scripts/make-manifest.sh`): format number, board, version, the archive's file name, size and SHA-256. One signature covers all of them,
so a valid signature cannot be moved onto a different file, board or version. The signature is a 64-byte Ed25519 signature made with OpenSSL (already in the image).

Rules the device applies (`fsoverlay/usr/bin/batocera-upgrade`):
- **No valid signature, no install.** A signature that is present but wrong is always refused. A missing one is refused on a normal image.
- **No downgrades.** A validly signed *older* release is refused (it could bring back a fixed bug). Someone who really wants to go back runs
  `batocera-upgrade --allow-downgrade` by hand; the menu never does.
- **Developer images only** (built with `OCTANE_DEV_KEY_FILE`; they carry `/usr/share/octane/allow-unsigned`) may install an update with *no* signature. `check-image.sh --release` rejects such an image.
- **Two keys:** an update is accepted if **either** the primary or the backup key signed it.

## One-time setup: create the keys (on your OFFLINE machine)

Use a computer you control, not the build server. OpenSSL 3 is needed. Choose a long passphrase for each key and write it down somewhere safe.

```
umask 077
openssl genpkey -algorithm ED25519 -aes-256-cbc -out primary.key.pem      # asks for a passphrase twice
openssl genpkey -algorithm ED25519 -aes-256-cbc -out backup.key.pem
openssl pkey -in primary.key.pem -pubout -out primary.pub.pem             # asks for the passphrase
openssl pkey -in backup.key.pem  -pubout -out backup.pub.pem
openssl pkey -pubin -in primary.pub.pem -outform DER | sha256sum          # the fingerprint; write it down
openssl pkey -pubin -in backup.pub.pem  -outform DER | sha256sum
```

- **Keep the two `.key.pem` files in different places** (for example the primary on an encrypted drive you use for signing, the backup on a separate
  drive or paper copy in a safe). Never put a `.key.pem` file in the repo, on the build server, in e-mail or in cloud storage.
- Only the two `.pub.pem` files go to the repo: copy them to `keys/update/primary.pub.pem` and `keys/update/backup.pub.pem` and commit them.
  Check the fingerprints match the ones you wrote down.

## Every release

1. Build the image as usual, then run `scripts/publish-release.sh --notes <file>`. On the first run it writes
   `boot.tar.xz.manifest` next to the archive and **stops**, printing the commands below.
2. Copy `boot.tar.xz.manifest` (a 5-line text file) to the offline machine and sign it with the **primary** key:
   ```
   scripts/sign-release.sh boot.tar.xz.manifest primary.key.pem            # shows the manifest, asks for the passphrase
   ```
   (`sign-release.sh` needs only `openssl`; copy that one script along with the manifest, or sign by hand with
   `openssl pkeyutl -sign -inkey primary.key.pem -rawin -in boot.tar.xz.manifest -out boot.tar.xz.manifest.sig`.)
3. Look at the manifest it printed: the **version** and **board** must be the ones you mean to release.
4. Copy `boot.tar.xz.manifest.sig` back into the same folder as the archive and run `scripts/publish-release.sh` again. It refuses to publish
   unless the signature matches a key in `keys/update/` and the manifest describes exactly this build.

## If a key is lost or stolen

- **Primary key stolen or its passphrase forgotten:** sign the next release with the **backup** key (the images carry both keys, so devices accept it). That release should replace
  the primary key with a new one (put the new `primary.pub.pem` in `keys/update/` before building it). Devices that update to it then trust the new set.
  Tell people which releases were signed during the exposure.
- **Backup key lost:** nothing breaks. Make a new backup key and ship it in the next release.
- **Both lost:** devices cannot be updated over the air any more; people would have to flash a new image. That is why they are stored apart.

## Testing

`scripts/test-update-signing.sh` (56 checks, no hardware, throw-away keys) covers: a good signature from either key, a wrong key, a tampered manifest, a swapped archive of the
same size, a wrong size, a missing signature, an image with no keys, downgrades and the override, a manifest for another board or file or with a missing or doubled field,
manual mode, developer images, and the build rules for the keys and the developer marker. `scripts/test-publish-release.sh` covers the publish side. Both run in CI.
Each rule was also checked by breaking the code on purpose and confirming a test fails.

## Open points
- The real keys have to be created (above) and committed before the first signed release.
- A real end-to-end run on a device (published release, ES menu, a signed update from a test card) is still to be done; so far the updater was tested against a fake `/boot` and a fake network.
