#!/bin/bash
YT_URL="${YT_URL:-https://www.twitch.tv/inoxtag}"
OUTPUT_URL="${OUTPUT_URL:-}"

BACKUP_STREAMERS=(
    "https://hello.1yallashoot.com/splayer/Live1.php"
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

echo "[kick] Starting..."
echo "[kick] PRIMARY_URL=$YT_URL"
echo "[kick] OUTPUT_URL=$OUTPUT_URL"

if [ -z "$YT_URL" ]; then echo "Missing YT_URL"; exit 1; fi
if [ -z "$OUTPUT_URL" ]; then echo "Missing OUTPUT_URL"; exit 1; fi

echo "[kick] Checking ffmpeg protocols for SRT..."
ffmpeg -hide_banner -protocols 2>&1 | grep -i srt || echo "[kick] WARNING: SRT protocol NOT found!"
echo "[kick] Checking ffmpeg version..."
ffmpeg -version 2>&1 | head -3

extract_yallashoot() {
    local base_url="https://hello.1yallashoot.com/splayer/Live1.php"
    echo "[kick] Fetching 1yallashoot page..." >&2
    local embed_urls
    embed_urls=$(curl -sL "$base_url" 2>/dev/null | grep -oP 'https://player\.simokora\.com/embed\.php\?stream=[^"'"'"'&]+' | sort -u)
    if [ -z "$embed_urls" ]; then
        echo "[kick] No embed URLs found on 1yallashoot" >&2
        return 1
    fi
    while IFS= read -r embed; do
        [ -z "$embed" ] && continue
        echo "[kick] Checking embed: $embed" >&2
        local m3u8
        m3u8=$(curl -sL "$embed" 2>/dev/null | grep -oP 'https?://[^"'"'"'<>]+\.m3u8[^"'"'"'<>]*' | head -1)
        if [ -n "$m3u8" ]; then
            echo "$m3u8"
            return 0
        fi
    done <<< "$embed_urls"
    return 1
}

try_stream() {
    local url="$1"
    echo "[kick] Trying: $url" >&2

    if echo "$url" | grep -qi "1yallashoot"; then
        local m3u8
        m3u8=$(extract_yallashoot)
        if [ -n "$m3u8" ]; then
            echo "$m3u8"
            return 0
        fi
        return 1
    fi

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
    echo "[kick] Looking for a live stream..."
    source_url=$(get_live_url)
    if [ -z "$source_url" ]; then
        echo "[kick] No live streams found, retrying in 30s..."
        sleep 30
        continue
    fi
    echo "[kick] Stream URL: $source_url"
    echo "[kick] Starting ffmpeg..."

    retries=0
    max_retries=30
    while [ $retries -lt $max_retries ]; do
        fresh_url=$(get_live_url)
        if [ -z "$fresh_url" ]; then
            echo "[kick] No live source for retry $retries" >&2
            sleep 10
            retries=$((retries + 1))
            continue
        fi
        obfuscated_output="${OUTPUT_URL%%\?*}"
        echo "[kick] ffmpeg command: ffmpeg -re -timeout 30000000 -analyzeduration 50M -probesize 50M -protocol_whitelist file,http,https,tcp,tls,crypto,srt -fflags +discardcorrupt -seekable 0 -max_reload 999 -i \"...\" -map 0:v -map 0:a -c copy -f mpegts \"${obfuscated_output}?...\" -loglevel info -stats"
        ffmpeg -re -timeout 30000000 -analyzeduration 50M -probesize 50M \
            -protocol_whitelist "file,http,https,tcp,tls,crypto,srt" \
            -fflags +discardcorrupt -seekable 0 \
            -max_reload 999 \
            -i "$fresh_url" \
            -map 0:v -map 0:a -c copy \
            -f mpegts "$OUTPUT_URL" \
            -loglevel info -stats 2>&1
        rc=$?
        echo "[kick] ffmpeg exited with code $rc" >&2
        if [ $rc -eq 0 ]; then
            echo "[kick] Stream finished cleanly" >&2
            break
        fi
        retries=$((retries + 1))
        echo "[kick] ffmpeg error (retry $retries/$max_retries), waiting 10s..." >&2
        sleep 10
    done
    if [ $retries -ge $max_retries ]; then
        echo "[kick] Gave up after $max_retries retries" >&2
    fi

    echo "[kick] Stream ended, finding next in 5s..."
    sleep 5
done
