import subprocess
import threading
import os
import sys
import base64
import json
from flask import Flask

app = Flask(__name__)

def log(msg):
    print(f"[restream] {msg}", flush=True)

def setup_cookies():
    cookies_b64 = os.environ.get('COOKIES_B64', '')
    if cookies_b64:
        try:
            data = json.loads(base64.b64decode(cookies_b64).decode())
            with open('/cookies.json', 'w') as f:
                json.dump(data, f)
            log("Cookies saved to /cookies.json")
        except Exception as e:
            log(f"Failed to decode cookies: {e}")

def start_restream():
    yt_url = os.environ.get('YT_URL', '')
    output_urls = os.environ.get('OUTPUT_URLS', '')
    if not yt_url or not output_urls:
        log("Missing YT_URL or OUTPUT_URLS")
        return
    env = os.environ.copy()
    log(f"Starting restream: {yt_url}")
    while True:
        log("Launching restream.sh...")
        proc = subprocess.Popen(
            ['/restream.sh'],
            env=env,
            stdout=sys.stdout,
            stderr=sys.stderr
        )
        proc.wait()
        log(f"restream.sh exited (code {proc.returncode}), restarting in 10s...")
        import time
        time.sleep(10)

@app.route('/')
def index():
    return 'Restream running', 200

@app.route('/health')
def health():
    return 'OK', 200

if __name__ == '__main__':
    setup_cookies()
    t = threading.Thread(target=start_restream, daemon=True)
    t.start()
    app.run(host='0.0.0.0', port=8080)
