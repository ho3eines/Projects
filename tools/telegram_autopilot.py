#!/usr/bin/env python3
"""Minutely bridge: Telegram queue.jsonl → Freebuff app queue_items (auto-run).

Why this exists
---------------
Button clicks in Telegram become `ready` tasks in
~/.telegram-bridge/agent/queue.jsonl (written by tools/telegram_agent.py).
The Freebuff desktop app is the only executor of those tasks, but it never
looks at queue.jsonl — it consumes its own `queue_items` table (desktop-v2.db):
rows with delivery='queue' + state='queued' are auto-run as turns in the owning
thread (proven: this very conversation was started by queue item 73d6d44c).

This script bridges the two: run every minute (Task Scheduler), it checks for
`ready` tasks and, when found and no autopilot item is already pending, inserts
one instruction item into the executor thread's queue. The app then auto-runs
it; the executing Freebuff session drains the queue with claim-next/complete.

Config (optional)
-----------------
TELEGRAM_AUTOPILOT_THREAD_ID   explicit thread UUID; default = auto-pick the
                               open thread with the most recent activity that
                               is not the store auto-run campaign (see below).

This script is a one-shot poller. It never executes tasks itself and never
calls Telegram or an LLM — exactly like tools/telegram_queue.py.
"""

import glob
import json
import os
import sqlite3
import sys
import time
import uuid
from datetime import datetime, timezone

if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
QUEUE_FILE = os.path.join(STATE_DIR, "queue.jsonl")
NOTIFY_FILE = os.path.join(STATE_DIR, "pending-notify")
LOG_FILE = os.path.join(STATE_DIR, "autopilot.log")
STATE_FILE = os.path.join(STATE_DIR, "autopilot-thread")   # picked thread (persisted)

# ⚠️ این ترد «executor» گفتگوهای زیرساخت تلگرام است (webhook/auto-claim در آن اجرا
# شده‌اند؛ درخواست فعلی هم queue item 73d6d44c در همین ترد بود). اگر یک گفتگوی
# Freebuff جدید به executor تبدیل شد، این مقدار را با
#   TELEGRAM_AUTOPILOT_THREAD_ID=<uuid ترد>
# بازنویسی کنید (یا فایل state را حذف کنید تا دوباره auto-pick شود).
DEFAULT_THREAD = "9374d03d-2c93-4a32-a4a4-ce75d1bbaf13"

MARKER_SKILL = "telegram-autopilot"   # dedupe marker in queue_items.skill_name
LABEL = "⚡ اجرای خودکار صف تلگرام"

# دستورالعملی که به نشست Freebuff داده می‌شود — کاملاً خودکفا، بدون سؤال در
# Freebuff؛ تصمیم/پیشنهاد فقط از طریق تلگرام.
INSTRUCTION = """چند Task آماده در صف تلگرام است (has-notify=yes). بدون سؤال اضافه اجرا کن:
۱) `python tools/telegram_queue.py claim-next` را بزن و Task JSON (شامل id/request/todos) را بگیر.
۲) دقیقاً همان درخواست کاربر را کامل اجرا کن (الگوهای موجود پروژه را رعایت کن؛ منطق فعلی را نشکن).
۳) اگر در میانهٔ کار به تصمیم/تأیید نیاز شد، آن را با دکمه‌های تلگرام بپرس — نه در این صفحه.
۴) پایان هر Task: `python tools/telegram_queue.py complete T-XXXX "<خلاصه فارسی>"` (خودکار reseed و تست‌ها را اجرا می‌کند؛ در خطا از `fail` استفاده کن).
۵) گزارش کوتاه هر Task را با `python tools/telegram_send.py --priority high --text ...` بفرست و دکمه‌های پیشنهاد مرحلهٔ بعد را هم اضافه کن (--buttons).
تا وقتی `python tools/telegram_queue.py has-notify` خروجی yes می‌دهد همین چرخه را تکرار کن."""


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(message):
    try:
        print(message, flush=True)
    except (UnicodeError, OSError):
        pass
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as handle:
            handle.write(f"{now()} {message}\n")
    except OSError:
        pass


def find_db():
    """Locate the Freebuff desktop DB for this project (~/.config/freebuff-desktop/projects/*/desktop-v2.db)."""
    pattern = os.path.join(os.path.expanduser("~"), ".config", "freebuff-desktop", "projects", "*", "desktop-v2.db")
    for db in glob.glob(pattern):
        try:
            con = sqlite3.connect(f"file:{db}?mode=ro", uri=True, timeout=3)
            cur = con.cursor()
            cur.execute("SELECT root_path FROM projects LIMIT 1")
            root = (cur.fetchone() or (None,))[0]
            con.close()
        except Exception:
            root = None
        # project root is the repo root (parent of tools/)
        repo_root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        if root and os.path.normcase(os.path.normpath(root)) == os.path.normcase(os.path.normpath(repo_root)):
            return db
    # fallback: any project DB (single-project machine)
    for db in glob.glob(pattern):
        return db
    return None


def pick_thread(con):
    """Thread UUID to inject into: explicit env → persisted state → auto-pick.

    Auto-pick prefers the open, unpaused thread with the most recent activity,
    skipping the store auto-run campaign thread (a2f7f98d) which already has its
    own queued wave items — Telegram tasks should not pollute that stream.
    """
    override = os.environ.get("TELEGRAM_AUTOPILOT_THREAD_ID", "").strip()
    if override:
        return override
    if os.path.exists(STATE_FILE):
        try:
            with open(STATE_FILE, encoding="ascii") as handle:
                saved = handle.read().strip()
            if saved:
                return saved
        except OSError:
            pass
    cur = con.cursor()
    cur.execute("SELECT id, updated_at, queue_paused FROM threads WHERE status='open' ORDER BY updated_at DESC")
    rows = cur.fetchall()
    for thread_id, updated_at, paused in rows:
        if paused:
            continue
        if thread_id == DEFAULT_THREAD:
            return thread_id
    # fall back to most recent open unpaused thread
    for thread_id, updated_at, paused in rows:
        if not paused:
            return thread_id
    return None


def persist_thread(thread_id):
    try:
        with open(STATE_FILE, "w", encoding="ascii") as handle:
            handle.write(thread_id)
    except OSError:
        pass


def ready_tasks():
    try:
        with open(QUEUE_FILE, encoding="utf-8") as handle:
            tasks = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        return []
    return [t for t in tasks if t.get("status") == "ready"]


def pending_autopilot_item(con, thread_id):
    """True if an autopilot instruction item is already queued/running (dedupe)."""
    cur = con.cursor()
    cur.execute(
        "SELECT COUNT(*) FROM queue_items WHERE thread_id=? AND skill_name=? AND state IN ('queued','running')",
        (thread_id, MARKER_SKILL),
    )
    return cur.fetchone()[0] > 0


def inject(con, thread_id, ready_ids):
    now_ms = int(time.time() * 1000)
    cur = con.cursor()
    cur.execute("SELECT COALESCE(MAX(position),0) FROM queue_items WHERE thread_id=?", (thread_id,))
    position = float((cur.fetchone()[0] or 0) + 1)
    item_id = str(uuid.uuid4())
    ready_note = " | ".join(t[:24] for t in ready_ids)
    label = f"{LABEL} ({ready_note})"
    cur.execute(
        """INSERT INTO queue_items
           (id, thread_id, kind, prompt, label, chat_text, note, state, delivery, priority,
            recovery_prompt, claimed_briefs, source, skill_name, attachments_json, position,
            created_at, updated_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (item_id, thread_id, "prompt", INSTRUCTION, label, INSTRUCTION, None,
         "queued", "queue", 0, None, None, "assistant", MARKER_SKILL, "[]",
         position, now_ms, now_ms),
    )
    con.commit()
    return item_id


def main():
    tasks = ready_tasks()
    if not tasks:
        return 0
    db = find_db()
    if not db:
        log("autopilot: Freebuff desktop DB not found; nothing injected")
        return 1
    try:
        con = sqlite3.connect(db, timeout=5)
    except Exception as exc:
        log(f"autopilot: DB open failed: {exc}")
        return 1
    try:
        thread_id = pick_thread(con)
        if not thread_id:
            log("autopilot: no open thread available to inject")
            return 1
        if pending_autopilot_item(con, thread_id):
            log(f"autopilot: instruction already pending in {thread_id[:8]} ({len(tasks)} ready) — skipped")
            return 0
        ready_ids = [t.get("id", "?") for t in tasks]
        item_id = inject(con, thread_id, ready_ids)
        persist_thread(thread_id)
        log(f"autopilot: injected {item_id[:8]} -> thread {thread_id[:8]} for {len(tasks)} ready task(s): {', '.join(ready_ids)}")
        return 0
    finally:
        con.close()


if __name__ == "__main__":
    raise SystemExit(main())
