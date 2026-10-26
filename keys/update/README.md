# Update signing keys (public halves only)

This folder holds the **public** keys that devices use to check the signature on an update:

- `primary.pub.pem`: the key releases are normally signed with
- `backup.pub.pem`: a second key, kept separately, so a lost or stolen primary key can be replaced

Both are baked into every image (`/usr/share/octane/update-keys/`), and `scripts/publish-release.sh`
refuses to publish unless at least two are here and the release signature matches one of them.

**Never put a private key here.** How to create the keys offline and how to sign a release:
[docs/update-signing.md](../../docs/update-signing.md). Until the real keys are added, release builds
and `publish-release.sh` fail on purpose.
