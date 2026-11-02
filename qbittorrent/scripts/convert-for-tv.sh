#!/usr/bin/env bash
#
# convert-for-tv.sh — normalize finished torrent downloads to H.264/AAC MP4
# so they play reliably on a Sony Bravia (and most DLNA clients/browsers).
#
# Hook into qBittorrent:
#   Options -> Downloads -> "Run external program on torrent completion"
#   /path/to/convert-for-tv.sh "%F"
#
# %F = content path qBittorrent passes (a single file OR a folder for
# multi-file torrents). Always quote it — paths can contain spaces.
#
# Non-video torrents are ignored automatically: the script only finds
# files with known video extensions, so anything else (zips, books,
# music, etc.) simply matches nothing and nothing happens.

set -uo pipefail

TARGET="${1:?Usage: $0 <content path from qBittorrent>}"
LOG="/config/convert-for-tv.log"
LOCK="/tmp/convert-for-tv.lock"

# TV is HD-ready (1366x768) — no point encoding above 720p; also keeps
# transcode time sane on a Pi 4's CPU. Set to 0 to disable downscaling.
MAX_HEIGHT="${MAX_HEIGHT:-720}"

# Delete the original file after a successful conversion/remux.
# Set to 0 if you'd rather keep both and clean up manually.
DELETE_ORIGINAL="${DELETE_ORIGINAL:-1}"

VIDEO_EXTS="mkv avi mp4 mov wmv flv m4v ts webm mpg mpeg"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG"; }

# Serialize jobs: a Pi 4's CPU will choke if two transcodes overlap
# (e.g. two torrents finish close together). Each run waits its turn.
exec 200>"$LOCK"

process_one() {
    local in="$1"
    local dir base ext out
    dir="$(dirname "$in")"
    base="$(basename "$in")"
    ext="${base##*.}"
    base="${base%.*}"
    out="${dir}/${base}.tv.mp4"

    if [[ -e "$out" ]]; then
        log "SKIP (output already exists): $in"
        return
    fi

    # Inspect the first video and audio stream.
    local vcodec pixfmt height acodec
    vcodec=$(ffprobe -v error -select_streams v:0 -show_entries stream=codec_name \
        -of csv=p=0 "$in" 2>>"$LOG")
    pixfmt=$(ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt \
        -of csv=p=0 "$in" 2>>"$LOG")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height \
        -of csv=p=0 "$in" 2>>"$LOG")
    acodec=$(ffprobe -v error -select_streams a:0 -show_entries stream=codec_name \
        -of csv=p=0 "$in" 2>>"$LOG")

    if [[ -z "$vcodec" ]]; then
        log "SKIP (no video stream, not a real video file): $in"
        return
    fi

    local needs_scale=0
    if [[ "$MAX_HEIGHT" -gt 0 && -n "$height" && "$height" -gt "$MAX_HEIGHT" ]]; then
        needs_scale=1
    fi

    local already_compatible=0
    if [[ "$vcodec" == "h264" && "$pixfmt" == "yuv420p" && "$acodec" == "aac" && "$needs_scale" -eq 0 ]]; then
        already_compatible=1
    fi

    if [[ "$already_compatible" -eq 1 && "$ext" == "mp4" ]]; then
        log "SKIP (already compatible mp4): $in"
        return
    fi

    log "START: $in  (video=$vcodec pix=$pixfmt h=$height audio=$acodec)"

    local vf_args=()
    [[ "$needs_scale" -eq 1 ]] && vf_args=(-vf "scale=-2:${MAX_HEIGHT}")

    local status
    if [[ "$already_compatible" -eq 1 ]]; then
        # Right codecs, wrong container (e.g. mkv/avi with h264+aac) — just remux, no re-encode.
        ffmpeg -nostdin -y -i "$in" -map 0:v:0 -map 0:a:0? \
            -c copy -movflags +faststart "$out" >>"$LOG" 2>&1
        status=$?
    else
        # Re-encode to a TV-safe baseline: H.264 (High, 4.1) + AAC, yuv420p.
        ffmpeg -nostdin -y -i "$in" -map 0:v:0 -map 0:a:0? \
            "${vf_args[@]}" \
            -c:v libx264 -profile:v high -level 4.1 -pix_fmt yuv420p \
            -crf 21 -preset veryfast \
            -c:a aac -b:a 192k \
            -movflags +faststart "$out" >>"$LOG" 2>&1
        status=$?
    fi

    if [[ $status -eq 0 && -s "$out" ]]; then
        log "DONE: $out"
        if [[ "$DELETE_ORIGINAL" -eq 1 ]]; then
            rm -f -- "$in"
            log "DELETED original: $in"
        fi
    else
        log "FAILED ($status): $in — leaving original in place"
        rm -f -- "$out"
    fi
}

flock 200
log "=== Run started for: $TARGET ==="

if [[ -d "$TARGET" ]]; then
    find_expr=()
    for e in $VIDEO_EXTS; do
        find_expr+=(-iname "*.${e}" -o)
    done
    unset 'find_expr[${#find_expr[@]}-1]'   # drop trailing -o

    while IFS= read -r -d '' f; do
        process_one "$f"
    done < <(find "$TARGET" -type f \( "${find_expr[@]}" \) -print0)
elif [[ -f "$TARGET" ]]; then
    ext="${TARGET##*.}"
    ext_lc="$(echo "$ext" | tr '[:upper:]' '[:lower:]')"
    if echo " $VIDEO_EXTS " | grep -qi " $ext_lc "; then
        process_one "$TARGET"
    else
        log "IGNORED (not a video extension): $TARGET"
    fi
else
    log "ERROR: path does not exist: $TARGET"
fi

log "=== Run finished for: $TARGET ==="