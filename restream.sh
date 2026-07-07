#!/bin/bash
YT_URL="${YT_URL:-https://www.twitch.tv/kaicenat}"
OUTPUT_URLS="${OUTPUT_URLS:-}"

echo "[restream] Starting..."
echo "[restream] YT_URL=$YT_URL"
echo "[restream] OUTPUT_URLS=$OUTPUT_URLS"

if [ -z "$YT_URL" ]; then echo "Missing YT_URL"; exit 1; fi
if [ -z "$OUTPUT_URLS" ]; then echo "Missing OUTPUT_URLS"; exit 1; fi

while true; do
    TEE_OUTPUT=""
    IFS=',' read -ra URLS <<< "$OUTPUT_URLS"
    for i in "${!URLS[@]}"; do
        [ "$i" -gt 0 ] && TEE_OUTPUT+="|"
        TEE_OUTPUT+="[f=flv]${URLS[$i]}"
    done

    echo "[restream] Getting stream URL via yt-dlp..."
    for attempt in 1 2 3 4 5; do
        STREAM_URL=$(yt-dlp -g --socket-timeout 15 --retries 3 \
            "$YT_URL" 2>/tmp/yt-dlp.log | tail -1)
        if [ -n "$STREAM_URL" ] && ! echo "$STREAM_URL" | grep -qi "error\|warn"; then
            break
        fi
        echo "[restream] Attempt $attempt failed, retrying in 5s..."
        sleep 5
    done
    if [ -z "$STREAM_URL" ] || echo "$STREAM_URL" | grep -qi "error\|warn"; then
        echo "[restream] All attempts failed: $(tail -3 /tmp/yt-dlp.log)"
        sleep 15
        continue
    fi
    echo "[restream] Stream URL: $STREAM_URL"
    echo "[restream] Starting ffmpeg..."
    ffmpeg -re -timeout 30000000 -analyzeduration 50M -probesize 50M \
        -protocol_whitelist "file,http,https,tcp,tls,crypto" \
        -fflags +discardcorrupt -seekable 0 \
        -max_reload 999 \
        -i "$STREAM_URL" \
        -c copy -bsf:v h264_mp4toannexb \
        -f flv "$OUTPUT_URLS" \
        -loglevel info -stats 2>&1

    echo "[restream] Stream ended, restarting in 5s..."
    sleep 5
done
