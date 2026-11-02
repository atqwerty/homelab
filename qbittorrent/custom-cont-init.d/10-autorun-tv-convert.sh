#!/usr/bin/with-contenv bash
# Runs automatically on every container start (linuxserver s6-overlay
# convention), before qBittorrent itself starts.
#
# qBittorrent pre-creates an empty, disabled [AutoRun] section on its
# own first boot (enabled=false, program=). A naive "does the section
# exist" check sees that and backs off forever, leaving autorun dead.
# So instead we check whether it's actually enabled=true with our
# program set, and fix it if not -- self-healing on every boot,
# without touching anything else you've configured by hand.

set -e

CONF_DIR="/config/qBittorrent"
CONF="${CONF_DIR}/qBittorrent.conf"
WANT_PROGRAM='/scripts/convert-for-tv.sh "%F"'

mkdir -p "$CONF_DIR"
touch "$CONF"

if awk '/^\[AutoRun\]/{f=1;next} /^\[/{f=0} f && /^enabled=true/{found=1} END{exit !found}' "$CONF" \
   && grep -q "^program=${WANT_PROGRAM//\//\\/}$" "$CONF"; then
    echo "[10-autorun-tv-convert] Already correctly configured, leaving as-is"
    exit 0
fi

echo "[10-autorun-tv-convert] [AutoRun] missing, disabled, or pointing elsewhere -- fixing"

if grep -q '^\[AutoRun\]' "$CONF"; then
    # Section exists (possibly disabled/empty) -- rewrite just its
    # enabled/program lines, add them if absent, leave everything else
    # in the file untouched.
    awk -v prog="$WANT_PROGRAM" '
        /^\[AutoRun\]/ { print; in_section=1; seen_enabled=0; seen_program=0; next }
        /^\[/ && in_section {
            if (!seen_enabled) print "enabled=true"
            if (!seen_program) print "program=" prog
            in_section=0
        }
        in_section && /^enabled=/ { print "enabled=true"; seen_enabled=1; next }
        in_section && /^program=/ { print "program=" prog; seen_program=1; next }
        { print }
        END {
            if (in_section) {
                if (!seen_enabled) print "enabled=true"
                if (!seen_program) print "program=" prog
            }
        }
    ' "$CONF" > "${CONF}.tmp" && mv "${CONF}.tmp" "$CONF"
else
    printf '\n[AutoRun]\nenabled=true\nprogram=%s\n' "$WANT_PROGRAM" >> "$CONF"
fi

echo "[10-autorun-tv-convert] [AutoRun] now enabled, pointing at ${WANT_PROGRAM}"