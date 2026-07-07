#!/bin/bash
YT_URL="${YT_URL:-}"
STREAM_URL="${STREAM_URL:-}"
OUTPUT_URLS="${OUTPUT_URLS:-}"

echo "[restream] Starting..."
echo "[restream] YT_URL=$YT_URL"
echo "[restream] STREAM_URL=$STREAM_URL"
echo "[restream] OUTPUT_URLS=$OUTPUT_URLS"

if [ -z "$STREAM_URL" ] && [ -z "$YT_URL" ]; then echo "Missing YT_URL or STREAM_URL"; exit 1; fi
if [ -z "$OUTPUT_URLS" ]; then echo "Missing OUTPUT_URLS"; exit 1; fi

while true; do
    if [ -z "$STREAM_URL" ] && [ -n "$YT_URL" ]; then
        echo "[restream] Getting stream URL via yt-dlp..."
        STREAM_URL=$(yt-dlp -g --socket-timeout 10 "$YT_URL" 2>&1)
        echo "[restream] yt-dlp result: $STREAM_URL"
        if [ -z "$STREAM_URL" ] || echo "$STREAM_URL" | grep -qi "error\|fail\|unavailable"; then
            echo "[restream] No valid stream URL, retrying in 30s..."
            sleep 30
            continue
        fi
    fi

    TEE_OUTPUT=""
    IFS=',' read -ra URLS <<< "$OUTPUT_URLS"
    for i in "${!URLS[@]}"; do
        [ "$i" -gt 0 ] && TEE_OUTPUT+="|"
        TEE_OUTPUT+="[f=flv]${URLS[$i]}"
    done

    echo "[restream] Starting ffmpeg..."
    timeout 300 ffmpeg -re -timeout 15000000 -i "$STREAM_URL" \
        -c copy -bsf:v h264_mp4toannexb \
        -f tee "$TEE_OUTPUT" \
        -loglevel warning -stats 2>&1

    echo "[restream] ffmpeg exited, restarting in 10s..."
    sleep 10
done
