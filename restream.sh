#!/bin/bash
YT_URL="${YT_URL:-}"
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

    echo "[restream] Getting stream URL via yt-dlp (android client)..."
    STREAM_URL=$(yt-dlp -g -f "best[height<=720]" \
        --extractor-args "youtube:player_client=android" \
        --socket-timeout 15 \
        "$YT_URL" 2>/tmp/yt-dlp.log | tail -1)
    if [ -z "$STREAM_URL" ] || echo "$STREAM_URL" | grep -qi "error\|warn"; then
        echo "[restream] Failed to get URL: $(tail -3 /tmp/yt-dlp.log)"
        sleep 30
        continue
    fi
    echo "[restream] Got stream URL, starting ffmpeg..."
    ffmpeg -re -timeout 30000000 -i "$STREAM_URL" \
        -c copy -bsf:v h264_mp4toannexb \
        -f tee "$TEE_OUTPUT" \
        -loglevel warning -stats 2>&1

    echo "[restream] Stream ended, restarting in 10s..."
    sleep 10
done
