#!/bin/bash
YT_URL="${YT_URL:-https://www.twitch.tv/kaicenat}"
OUTPUT_URLS="${OUTPUT_URLS:-}"

BACKUP_STREAMERS=(
    "https://www.twitch.tv/xqc"
    "https://www.twitch.tv/summit1g"
    "https://www.twitch.tv/lirik"
    "https://www.twitch.tv/timthetatman"
    "https://www.twitch.tv/sodapoppin"
    "https://www.twitch.tv/asmongold"
    "https://www.twitch.tv/cohhcarnage"
    "https://www.twitch.tv/chlorinequeen"
    "https://www.twitch.tv/itmejp"
    "https://www.twitch.tv/towelliee"
    "https://www.twitch.tv/sacriel"
    "https://www.twitch.tv/avoidingthepuddle"
    "https://www.twitch.tv/quinngabletv"
    "https://www.twitch.tv/gamesdonequick"
    "https://www.twitch.tv/twitchrivals"
)

echo "[restream] Starting..."
echo "[restream] PRIMARY_URL=$YT_URL"
echo "[restream] OUTPUT_URLS=$OUTPUT_URLS"

if [ -z "$YT_URL" ]; then echo "Missing YT_URL"; exit 1; fi
if [ -z "$OUTPUT_URLS" ]; then echo "Missing OUTPUT_URLS"; exit 1; fi

try_stream() {
    local url="$1"
    echo "[restream] Trying: $url"
    local result
    result=$(yt-dlp -g --socket-timeout 15 --retries 2 "$url" 2>/dev/null | tail -1)
    if [ -n "$result" ] && ! echo "$result" | grep -qi "error\|warn"; then
        echo "$result"
        return 0
    fi
    return 1
}

get_live_url() {
    local result
    result=$(try_stream "$YT_URL") && { echo "$result"; return 0; }

    local shuffled=("${BACKUP_STREAMERS[@]}")
    for i in "${!shuffled[@]}"; do
        local j=$((RANDOM % (i + 1)))
        local tmp="${shuffled[$i]}"
        shuffled[$i]="${shuffled[$j]}"
        shuffled[$j]="$tmp"
    done

    for backup in "${shuffled[@]}"; do
        result=$(try_stream "$backup") && { echo "$result"; return 0; }
    done
    return 1
}

while true; do
    echo "[restream] Looking for a live stream..."
    source_url=$(get_live_url)
    if [ -z "$source_url" ]; then
        echo "[restream] No live streams found, retrying in 30s..."
        sleep 30
        continue
    fi
    echo "[restream] Stream URL: $source_url"
    echo "[restream] Starting ffmpeg..."
    ffmpeg -re -timeout 30000000 -analyzeduration 50M -probesize 50M \
        -protocol_whitelist "file,http,https,tcp,tls,crypto" \
        -fflags +discardcorrupt -seekable 0 \
        -max_reload 999 \
        -i "$source_url" \
        -c copy -bsf:v h264_mp4toannexb \
        -f flv "$OUTPUT_URLS" \
        -loglevel info -stats 2>&1

    echo "[restream] Stream ended, finding next in 5s..."
    sleep 5
done
