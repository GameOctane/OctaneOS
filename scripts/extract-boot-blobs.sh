#!/bin/bash
# extract-boot-blobs.sh
#
# Downloads the first 32MB of the Radxa A733 CLI image and extracts
# the Allwinner boot0 and boot_package blobs needed for SD card boot.
#
# These blobs are written to fixed raw offsets on the SD card by genimage:
#   boot0        → offset 8KB   (Allwinner BROM secondary loader / DRAM init)
#   boot_package → offset ~16MB (U-Boot package)
#
# Output goes to board/batocera/allwinner/a733/boot/
# Commit the blobs and uncomment the genimage.cfg partition entries.

set -euo pipefail

IMAGE_URL="https://github.com/radxa-build/radxa-a733/releases/download/rsdk-r2/radxa-a733_bullseye_cli_r2.output_512.img.xz"
BLOB_DIR="$(cd "$(dirname "$0")/.." && pwd)/board/batocera/allwinner/a733/cubie-a7s/boot"
TMP_IMG="/tmp/radxa-a733-first32m.img"
STREAM_BYTES=$((32 * 1024 * 1024))  # 32MB — covers boot0 @ 8K and boot_package @ ~16MB

BOOT0_OFFSET=$((128 * 1024))            # 128KB (sun60iw2 confirmed offset)
BOOT0_SIZE=$((240 * 1024))             # 240KB (from eGON.BT0 header length field)
BOOT_PKG_OFFSET=$((12 * 1024 * 1024))  # 12MB (sun60iw2 confirmed offset)

echo "=== Radxa A733 boot blob extractor ==="
echo "Output dir: $BLOB_DIR"
mkdir -p "$BLOB_DIR"

echo ""
echo "Streaming first 32MB of image (skips downloading ~1GB of rootfs)..."
# Disable pipefail for this pipeline — dd exits after 32MB which sends SIGPIPE
# upstream to xz and curl; that's expected and not an error.
set +o pipefail
curl -fL --progress-bar "$IMAGE_URL" | xz -d | dd bs=1M count=32 iflag=fullblock of="$TMP_IMG" 2>/dev/null
set -o pipefail
echo "Done. Saved to $TMP_IMG"

echo ""
echo "=== Partition table ==="
sgdisk -p "$TMP_IMG" 2>/dev/null || fdisk -l "$TMP_IMG" 2>/dev/null || echo "(could not read partition table — may be truncated, that's OK)"

echo ""
echo "=== Extracting boot0 (offset ${BOOT0_OFFSET} bytes, size ${BOOT0_SIZE} bytes) ==="
dd if="$TMP_IMG" of="$BLOB_DIR/boot0_sdcard.fex" \
    bs=1 skip="$BOOT0_OFFSET" count="$BOOT0_SIZE" 2>/dev/null
echo "Saved: $BLOB_DIR/boot0_sdcard.fex ($(wc -c < "$BLOB_DIR/boot0_sdcard.fex") bytes)"

# Verify it looks like a real boot0 (Allwinner magic bytes "eGON.BT0")
if xxd "$BLOB_DIR/boot0_sdcard.fex" | head -2 | grep -q "65 47 4f 4e"; then
    echo "✓ boot0 magic verified (eGON.BT0)"
else
    echo "⚠ WARNING: boot0 magic not found — blob may be wrong offset or corrupt"
    xxd "$BLOB_DIR/boot0_sdcard.fex" | head -4
fi

echo ""
echo "=== Extracting boot_package (offset ${BOOT_PKG_OFFSET} bytes) ==="
# boot_package size: read 8MB which is more than enough for U-Boot
BOOT_PKG_SIZE=$((8 * 1024 * 1024))
dd if="$TMP_IMG" of="$BLOB_DIR/boot_package.fex" \
    bs=1M skip=$((BOOT_PKG_OFFSET / 1024 / 1024)) count=8 2>/dev/null
echo "Saved: $BLOB_DIR/boot_package.fex ($(wc -c < "$BLOB_DIR/boot_package.fex") bytes)"

# Check for Allwinner boot_package magic ("BOOT_PKG" or similar)
echo "First bytes of boot_package:"
xxd "$BLOB_DIR/boot_package.fex" | head -4

echo ""
echo "=== Done ==="
echo "Next steps:"
echo "  1. Verify the blobs look correct (magic bytes above)"
echo "  2. git add $BLOB_DIR/"
echo "  3. Uncomment the boot0/boot_package partition entries in genimage.cfg"
echo ""
echo "Cleaning up $TMP_IMG..."
rm -f "$TMP_IMG"
