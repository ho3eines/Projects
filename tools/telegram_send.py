#!/usr/bin/env python3
"""Queue a Telegram report/question for tools/telegram_agent.py to deliver.

Usage:
  python tools/telegram_send.py "message"
  python tools/telegram_send.py --chat-id 76937621 "message"
  python tools/telegram_send.py --buttons "message" "دکمه ۱" "دکمه ۲" ...
  python tools/telegram_send.py --priority high "message"

The command writes an outbox file only; it does not call Telegram directly.
With --buttons, the first argument is the message and every following argument
becomes an inline button (dynamic — Freebuff decides the labels per request).
--priority high: مهم‌ترین گزارش‌ها — agent این‌ها را قبل از گزارش‌های عادی تحویل می‌دهد.
"""

import json
import os
import sys
import time

STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
OUTBOX = os.path.join(STATE_DIR, "outbox.jsonl")
DEFAULT_CHAT_ID = "76937621"

_last_msg_seq = 0


def _new_message_id():
    """شناسهٔ یکتای رکورد: زمان + شمارنده.

    ویندوز برای فراخوانی‌های پشت‌سرهم time.time_ns() مقدار یکسان برمی‌گرداند؛
    بدون شمارنده، دو فراخوانی جدا در یک تیک می‌توانند ID یکسان بسازند و agent
    هنگام پاک‌کردن رکورد تحویل‌شده، رکورد دیگر را هم حذف کند.
    """
    global _last_msg_seq
    _last_msg_seq += 1
    return f"M-{time.time_ns()}-{_last_msg_seq}"



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


def usage():
    print(
        "usage: telegram_send.py [-h|--help] [--chat-id CHAT_ID] [--priority high|normal] [--buttons] [--text] MESSAGE [BUTTON...]",
        file=sys.stderr,
    )
    print("  --chat-id CHAT_ID   chat to deliver to (default " + DEFAULT_CHAT_ID + ")", file=sys.stderr)
    print("  --priority P        high|normal (default normal) — high is delivered first", file=sys.stderr)
    print("  --text              (alias) explicitly marks the next argument as the message", file=sys.stderr)
    print("  --buttons           treat every arg after MESSAGE as an inline button", file=sys.stderr)
    print("  MESSAGE             text to queue in the outbox for the agent to deliver", file=sys.stderr)


def main(args):
    if any(a in ("-h", "--help") for a in args):
        usage()
        return 0
    chat_id = DEFAULT_CHAT_ID
    attach_buttons = False
    priority = "normal"
    parsed = []
    i = 0
    while i < len(args):
        if args[i] in ("--text",) and i + 1 < len(args):
            # صریح‌سازی پیام: تلگرام‌ها/اسکریپت‌ها گاهی --text می‌دهند؛
            # بدون این شاخه، خودِ رشتهٔ "--text" به‌جای پیام ارسال می‌شد.
            parsed.append(args[i + 1])
            i += 2
        elif args[i] == "--chat-id" and i + 1 < len(args):
            chat_id = args[i + 1]
            i += 2
        elif args[i] == "--buttons":
            attach_buttons = True
            i += 1
        elif args[i] == "--priority" and i + 1 < len(args):
            priority = args[i + 1].lower()
            if priority not in ("high", "normal"):
                print(f"--priority فقط high یا normal می‌پذیرد (دریافت شد: {priority})", file=sys.stderr)
                return 2
            i += 2
        else:
            parsed.append(args[i])
            i += 1

    if not parsed:
        usage()
        return 2

    text = parsed[0]
    labels = parsed[1:] if attach_buttons else []

    os.makedirs(STATE_DIR, exist_ok=True)
    payload = {
        "id": _new_message_id(),
        "chat_id": chat_id,
        "text": text,
        "created_at": time.time(),
        "priority": priority,
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