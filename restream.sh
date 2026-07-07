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

    echo "[restream] Starting yt-dlp pipe to ffmpeg..."
    yt-dlp -f "best[height<=720]" -o - "$YT_URL" 2>/dev/null | \
    ffmpeg -re -i pipe:0 \
        -c copy -bsf:v h264_mp4toannexb \
        -f tee "$TEE_OUTPUT" \
        -loglevel warning -stats 2>&1

    echo "[restream] Stream ended, restarting in 10s..."
    sleep 10
done
