#!/usr/bin/env python3
"""Queue a Telegram report/question for tools/telegram_agent.py to deliver.

Usage:
  python tools/telegram_send.py "message"
  python tools/telegram_send.py --chat-id 76937621 "message"
  python tools/telegram_send.py --buttons "message"

The command writes an outbox file only; it does not call Telegram directly.
When --buttons is passed, phase selection buttons are attached.
"""

import json
import os
import sys
import time

STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
OUTBOX = os.path.join(STATE_DIR, "outbox.jsonl")

PHASE_BUTTONS = {
    "inline_keyboard": [
        [{"text": "🚀 فاز ۳ — UI صفحات", "callback_data": "phase:3"}],
        [{"text": "🔒 فاز ۴ — Permissions", "callback_data": "phase:4"}],
        [{"text": "🧪 فاز ۵ — Testing", "callback_data": "phase:5"}],
        [{"text": "📊 وضعیت صف", "callback_data": "status"}]
    ]
}


def main(args):
    chat_id = "76937621"
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
    text = " ".join(parsed).strip()
    if not text:
        print("usage: telegram_send.py [--chat-id CHAT_ID] [--buttons] MESSAGE", file=sys.stderr)
        return 2
    os.makedirs(STATE_DIR, exist_ok=True)
    payload = {
        "id": f"M-{time.time_ns()}",
        "chat_id": chat_id,
        "text": text,
        "created_at": time.time(),
    }
    if attach_buttons:
        payload["reply_markup"] = PHASE_BUTTONS
    with open(OUTBOX, "a", encoding="utf-8") as handle:
        handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
    print(payload["id"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
