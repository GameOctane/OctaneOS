Files here are NOT part of normal images.

octaneos-dev-ssh.pub is the developer's public SSH key. It is copied into an image only when the
build is started with OCTANE_DEV_KEY=1 (see post-build.sh), for example:

    OCTANE_DEV_KEY=1 ./scripts/build.sh --nohup

An image built that way gives whoever holds the matching private key root SSH access on every
device that runs it, so it must never be released. scripts/check-image.sh --release fails if the
key is present, and scripts/release-ota-version.sh runs that check.

A normal image removes the key from /userdata/system/.ssh/authorized_keys on boot (S13octane-init),
so updating a device that an older image had given the key to takes it out again.
