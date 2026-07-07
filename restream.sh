#!/bin/bash
YT_URL="${YT_URL:-}"
OUTPUT_URLS="${OUTPUT_URLS:-}"

if [ -z "$YT_URL" ]; then exit 1; fi
if [ -z "$OUTPUT_URLS" ]; then exit 1; fi

while true; do
    STREAM_URL=$(yt-dlp -g --live-from-start --wait-for-video 10 "$YT_URL" 2>/dev/null)
    if [ -z "$STREAM_URL" ]; then
        sleep 30
        continue
    fi

    TEE_OUTPUT=""
    IFS=',' read -ra URLS <<< "$OUTPUT_URLS"
    for i in "${!URLS[@]}"; do
        [ "$i" -gt 0 ] && TEE_OUTPUT+="|"
        TEE_OUTPUT+="[f=flv]${URLS[$i]}"
    done

    ffmpeg -re -i "$STREAM_URL" \
        -c copy -bsf:v h264_mp4toannexb \
        -f tee "$TEE_OUTPUT" \
        -loglevel warning

    sleep 10
done
