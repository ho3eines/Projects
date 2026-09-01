#!/usr/bin/env python3
"""Queue a Telegram report/question for tools/telegram_agent.py to deliver.

Usage:
  python tools/telegram_send.py "message"
  python tools/telegram_send.py --chat-id 76937621 "message"
  python tools/telegram_send.py --buttons "message" "دکمه ۱" "دکمه ۲" ...

The command writes an outbox file only; it does not call Telegram directly.
With --buttons, the first argument is the message and every following argument
becomes an inline button (dynamic — Freebuff decides the labels per request).
"""

import json
import os
import sys
import time

STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
OUTBOX = os.path.join(STATE_DIR, "outbox.jsonl")
DEFAULT_CHAT_ID = "76937621"


def callback_data_safe(label, limit=60):
    """Truncate a label to `limit` UTF-8 bytes at a char boundary.

    Telegram rejects callback_data longer than 64 bytes (BUTTON_DATA_INVALID),
    and emoji/Persian text is multi-byte, so len() in characters is wrong.
    """
    encoded = label.encode("utf-8")
    if len(encoded) <= limit:
        return label
    cut = encoded[:limit]
    while cut:
        try:
            return cut.decode("utf-8")
        except UnicodeDecodeError:
            cut = cut[:-1]
    return label[: limit // 2]


def build_keyboard(labels):
    """One inline button per label; callback_data carries the label itself."""
    rows = []
    for label in labels:
        clean = str(label).strip()
        if not clean:
            continue
        callback = callback_data_safe(clean)
        rows.append([{"text": clean, "callback_data": callback}])
    if not rows:
        return None
    return {"inline_keyboard": rows}


def main(args):
    chat_id = DEFAULT_CHAT_ID
    attach_buttons = False
    parsed = []
    i = 0
    while i < len(args):
        if args[i] == "--chat-id" and i + 1 < len(args):
            chat_id = args[i + 1]
            i += 2
        elif args[i] == "--buttons":
            attach_buttons = True
            i += 1
        else:
            parsed.append(args[i])
            i += 1

    if not parsed:
        print(
            "usage: telegram_send.py [--chat-id CHAT_ID] [--buttons] MESSAGE [BUTTON...]",
            file=sys.stderr,
        )
        return 2

    text = parsed[0]
    labels = parsed[1:] if attach_buttons else []

    os.makedirs(STATE_DIR, exist_ok=True)
    payload = {
        "id": f"M-{time.time_ns()}",
        "chat_id": chat_id,
        "text": text,
        "created_at": time.time(),
    }
    if attach_buttons:
        keyboard = build_keyboard(labels)
        if keyboard:
            payload["reply_markup"] = keyboard

    with open(OUTBOX, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    print(payload["id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))