#!/usr/bin/env python3
"""Reliable two-way Telegram bridge for the local development session.

Incoming messages are appended to ~/.telegram-bridge/inbox.jsonl.
Outgoing messages are read from ~/.telegram-bridge/send.json.
Only one local bridge process may poll the bot at a time.

Run:  python tools/telegram_bridge.py
Stop: create ~/.telegram-bridge/stop
"""

import atexit
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request

# Windows consoles default to a legacy codepage; keep Persian output readable.
sys.stdout = open(sys.stdout.fileno(), mode="w", encoding="utf-8", errors="replace", buffering=1)
sys.stderr = open(sys.stderr.fileno(), mode="w", encoding="utf-8", errors="replace", buffering=1)

TOKEN = os.environ.get("TELEGRAM_BOT_TOKEN", "")
BASE = f"https://api.telegram.org/bot{TOKEN}"
STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge")
INBOX = os.path.join(STATE_DIR, "inbox.jsonl")
OUTBOX = os.path.join(STATE_DIR, "send.json")
OFFSET_FILE = os.path.join(STATE_DIR, "offset")
STOP_FILE = os.path.join(STATE_DIR, "stop")
LOCK_FILE = os.path.join(STATE_DIR, "bridge.lock")
LOCK_HANDLE = None

os.makedirs(STATE_DIR, exist_ok=True)


def read_offset():
    try:
        with open(OFFSET_FILE, encoding="ascii") as f:
            return int(f.read().strip() or 0)
    except (OSError, ValueError):
        return 0


def write_offset(offset):
    temp_file = f"{OFFSET_FILE}.{os.getpid()}.tmp"
    with open(temp_file, "w", encoding="ascii") as f:
        f.write(str(offset))
    os.replace(temp_file, OFFSET_FILE)


def _process_exists(pid):
    if pid <= 0:
        return False
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError):
        return False


def release_lock():
    global LOCK_HANDLE
    if LOCK_HANDLE is not None:
        try:
            LOCK_HANDLE.close()
        except OSError:
            pass
        LOCK_HANDLE = None
    try:
        os.remove(LOCK_FILE)
    except OSError:
        pass


def acquire_lock():
    global LOCK_HANDLE
    try:
        LOCK_HANDLE = open(LOCK_FILE, "x", encoding="ascii")
        LOCK_HANDLE.write(str(os.getpid()))
        LOCK_HANDLE.flush()
        atexit.register(release_lock)
        return True
    except FileExistsError:
        try:
            with open(LOCK_FILE, encoding="ascii") as f:
                pid = int(f.read().strip())
        except (OSError, ValueError):
            pid = 0
        if not _process_exists(pid):
            try:
                os.remove(LOCK_FILE)
            except OSError:
                return False
            return acquire_lock()
        print(f"bridge already running (pid {pid}); exiting", flush=True)
        return False


def api_request(method, params, timeout):
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(
        f"{BASE}/{method}?{query}",
        headers={"User-Agent": "Tarazin-Telegram-Bridge/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        return json.load(response)


def poll_once(offset):
    try:
        # Short polling windows work more reliably through the local HTTPS proxy.
        result = api_request(
            "getUpdates",
            {"timeout": 8, "offset": offset, "limit": 20, "allowed_updates": '["message"]'},
            18,
        )
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            print("poll: 409 conflict; another consumer is polling, retrying in 20s", flush=True)
            time.sleep(20)
        elif exc.code == 429:
            retry_after = 10
            try:
                body = json.loads(exc.read().decode("utf-8"))
                retry_after = int(body.get("parameters", {}).get("retry_after", retry_after))
            except (OSError, ValueError, TypeError, json.JSONDecodeError):
                pass
            print(f"poll: rate limited; retrying in {retry_after}s", flush=True)
            time.sleep(max(1, retry_after))
        else:
            print(f"poll HTTP error: {exc}", flush=True)
            time.sleep(5)
        return offset
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        print(f"poll network error: {exc}; retrying in 5s", flush=True)
        time.sleep(5)
        return offset
    except Exception as exc:
        print(f"poll error: {exc}; retrying in 5s", flush=True)
        time.sleep(5)
        return offset

    if not result.get("ok"):
        print(f"poll rejected: {result}", flush=True)
        time.sleep(5)
        return offset

    for update in result.get("result", []):
        offset = max(offset, update["update_id"] + 1)
        message = update.get("message") or update.get("edited_message")
        if not message:
            continue
        entry = {
            "update_id": update["update_id"],
            "date": message.get("date"),
            "chat_id": (message.get("chat") or {}).get("id"),
            "from_id": (message.get("from") or {}).get("id"),
            "from_username": (message.get("from") or {}).get("username"),
            "text": message.get("text", ""),
        }
        with open(INBOX, "a", encoding="utf-8") as f:
            f.write(json.dumps(entry, ensure_ascii=False) + "\n")
        print(f"inbox: {entry['from_username']}: {entry['text'][:80]}", flush=True)
    return offset


def send_pending():
    if not os.path.exists(OUTBOX):
        return
    try:
        with open(OUTBOX, encoding="utf-8") as f:
            payload = json.load(f)
    except (OSError, ValueError, json.JSONDecodeError):
        return

    chat_id = payload.get("chat_id")
    text = payload.get("text", "")
    if not chat_id or not text:
        return

    try:
        result = api_request("sendMessage", {"chat_id": chat_id, "text": text}, 20)
        if result.get("ok"):
            os.remove(OUTBOX)
            print("sent: True", flush=True)
        else:
            print(f"send rejected: {result}", flush=True)
    except Exception as exc:
        print(f"send error: {exc}; keeping outbox for retry", flush=True)


def main():
    if not acquire_lock():
        return 2
    print("telegram bridge started", flush=True)
    offset = read_offset()
    try:
        while True:
            if os.path.exists(STOP_FILE):
                os.remove(STOP_FILE)
                print("stop file seen; exiting", flush=True)
                return 0
            send_pending()
            offset = poll_once(offset)
            write_offset(offset)
            sys.stdout.flush()
    except KeyboardInterrupt:
        print("interrupted; exiting", flush=True)
        return 0
    finally:
        release_lock()


if __name__ == "__main__":
    raise SystemExit(main())
