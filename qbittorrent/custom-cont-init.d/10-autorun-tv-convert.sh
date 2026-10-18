#!/usr/bin/with-contenv bash

# Runs automatically on every container start (linuxserver s6-overlay
# convention), before qBittorrent itself starts.
#
# If qBittorrent.conf has no [AutoRun] section yet (fresh install, or
# a wiped /config volume), write one pointing at the conversion
# script. If a section already exists -- meaning you (or a previous
# boot of this image) already configured it -- leave it alone, so
# manual changes made later in the Web UI are never clobbered.

set -e

CONF_DIR="/config/qBittorrent"
CONF="${CONF_DIR}/qBittorrent.conf"

mkdir -p "$CONF_DIR"
touch "$CONF"

if ! grep -q '^\[AutoRun\]' "$CONF"; then
    printf '\n[AutoRun]\nenabled=true\nprogram=/scripts/convert-for-tv.sh "%%F"\n' >> "$CONF"
    echo "[10-autorun-tv-convert] Added [AutoRun] section to qBittorrent.conf"
else
    echo "[10-autorun-tv-convert] [AutoRun] section already present, leaving as-is"
fi