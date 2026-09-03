#!/usr/bin/env python3
"""Send a photo to the Telegram bot chat via sendPhoto (multipart).

Reuses the same transport configuration as tools/telegram_agent.py:
  - config file  <project>/.telegram-agent.env  (TELEGRAM_BOT_TOKEN / TELEGRAM_CHAT_ID / TELEGRAM_PROXY)
  - proxy support (TELEGRAM_PROXY), direct when empty

Usage:
  python tools/telegram_photo.py <image-path> [caption-text]
"""

import json
import os
import sys
import time
import urllib.request
import uuid

ROOT = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(os.path.dirname(ROOT), ".telegram-agent.env")

TOKEN_ENV = "TELEGRAM_BOT_TOKEN"
CHAT_ENV = "TELEGRAM_CHAT_ID"
PROXY_ENV = "TELEGRAM_PROXY"


def read_config():
    cfg = {}
    if os.path.exists(CONFIG_FILE):
        for line in open(CONFIG_FILE, encoding="utf-8"):
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                cfg[k.strip()] = v.strip()
    return cfg


def build_opener(proxy):
    if proxy:
        return urllib.request.build_opener(
            urllib.request.ProxyHandler({"http": proxy, "https": proxy}))
    return urllib.request.build_opener()


def multipart(fields, files):
    boundary = "----tz" + uuid.uuid4().hex
    body = bytearray()
    for key, value in fields.items():
        body += f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"\r\n\r\n{value}\r\n".encode("utf-8")
    for key, (filename, content, ctype) in files.items():
        body += (f"--{boundary}\r\nContent-Disposition: form-data; name=\"{key}\"; "
                 f"filename=\"{filename}\"\r\nContent-Type: {ctype}\r\n\r\n").encode("utf-8")
        body += content
        body += b"\r\n"
    body += f"--{boundary}--\r\n".encode("utf-8")
    return body, f"multipart/form-data; boundary={boundary}"


def main():
    if len(sys.argv) < 2 or sys.argv[1] in ("-h", "--help"):
        print("usage: telegram_photo.py <image-path> [caption]", file=sys.stderr)
        return 2
    image_path = sys.argv[1]
    caption = " ".join(sys.argv[2:]) if len(sys.argv) > 2 else ""
    if not os.path.exists(image_path):
        print(f"image not found: {image_path}", file=sys.stderr)
        return 2

    cfg = read_config()
    token = cfg.get(TOKEN_ENV, "")
    chat_id = cfg.get(CHAT_ENV, "76937621")
    proxy = cfg.get(PROXY_ENV, "")
    if not token:
        print(f"{TOKEN_ENV} not set in {CONFIG_FILE}", file=sys.stderr)
        return 2

    opener = build_opener(proxy)
    url = f"https://api.telegram.org/bot{token}/sendPhoto"
    fields = {"chat_id": chat_id}
    if caption:
        fields["caption"] = caption[:1024]
    with open(image_path, "rb") as fh:
        content = fh.read()
    body, ctype = multipart(fields, {"photo": (os.path.basename(image_path), content, "image/png")})

    last = None
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, data=bytes(body), method="POST")
            req.add_header("Content-Type", ctype)
            with opener.open(req, timeout=60) as resp:
                data = json.loads(resp.read().decode("utf-8"))
            if data.get("ok"):
                print(f"photo sent (chat {chat_id}, proxy={proxy or 'direct'})")
                return 0
            last = data
        except Exception as exc:  # noqa: BLE001 - network retries
            last = str(exc)
        time.sleep(2 ** attempt)
    print(f"FAILED: {last}", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
