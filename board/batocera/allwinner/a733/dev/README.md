Developer-only notes. Nothing here is part of a normal image.

To let your own SSH key log in as root on a TEST device, build with the path to a public key:

    OCTANE_DEV_KEY_FILE=$HOME/.ssh/id_ed25519.pub ./scripts/build.sh --nohup

post-build.sh passes it to scripts/install-dev-key.sh, which puts the key (type and key only; the
comment becomes "octaneos-dev") into the image. On boot, S13octane-init installs it in
/userdata/system/.ssh/authorized_keys, replacing any earlier developer key.

No key is stored in the repo. An image built this way gives whoever holds the matching private key
root SSH on every device that runs it, so it must never be released:
scripts/check-image.sh --release fails if the key is present, and a normal build makes the device
remove any "octaneos-dev" key from authorized_keys on boot.

Tests: scripts/test-dev-key.sh.
