FROM alpine:latest

RUN apk add --no-cache ffmpeg bash python3 py3-pip py3-flask curl socat && \
    pip3 install --break-system-packages yt-dlp

COPY restream.sh /restream.sh
COPY app.py /app.py
RUN chmod +x /restream.sh

EXPOSE 8080
CMD ["python3", "/app.py"]
