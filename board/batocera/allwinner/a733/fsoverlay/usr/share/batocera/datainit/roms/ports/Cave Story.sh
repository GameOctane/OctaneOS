#!/bin/bash
# Cave Story (NXEngine) — freeware PC version auto-downloader and launcher.
# On first run: downloads the freeware English release from cavestory.org (~1.6 MB)
# and extracts it to /userdata/roms/cavestory/. Subsequent runs launch immediately.

CAVE_DIR="/userdata/roms/cavestory"
CAVE_EXE="${CAVE_DIR}/Doukutsu.exe"
NXENGINE="/usr/lib/libretro/nxengine_libretro.so"
RETROARCH="/usr/bin/retroarch"
DOWNLOAD_URL="http://www.cavestory.org/downloads/cavestoryen.zip"
TMPZIP="/tmp/cavestory-freeware.zip"

if [ ! -f "${CAVE_EXE}" ]; then
    mkdir -p "${CAVE_DIR}"
    echo "Downloading Cave Story freeware (1.6 MB)..."
    if ! curl -L --retry 3 --connect-timeout 10 "${DOWNLOAD_URL}" -o "${TMPZIP}"; then
        echo "Download failed. Connect to WiFi and try again."
        sleep 4
        exit 1
    fi
    unzip -o "${TMPZIP}" -d "${CAVE_DIR}"
    rm -f "${TMPZIP}"
    echo "Cave Story ready."
fi

exec "${RETROARCH}" -L "${NXENGINE}" "${CAVE_EXE}"
