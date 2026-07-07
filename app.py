import subprocess
import threading
import os
from flask import Flask

app = Flask(__name__)

def start_restream():
    yt_url = os.environ.get('YT_URL', '')
    output_urls = os.environ.get('OUTPUT_URLS', '')
    if not yt_url or not output_urls:
        return
    env = os.environ.copy()
    while True:
        proc = subprocess.Popen(
            ['/restream.sh'],
            env=env,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL
        )
        proc.wait()
        import time
        time.sleep(10)

@app.route('/')
def index():
    return 'Restream running', 200

@app.route('/health')
def health():
    return 'OK', 200

if __name__ == '__main__':
    t = threading.Thread(target=start_restream, daemon=True)
    t.start()
    app.run(host='0.0.0.0', port=8080)
