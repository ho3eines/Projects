#!/usr/bin/env python3
"""Read and claim tasks created by tools/telegram_agent.py.

This helper is for the active Freebuff session. It never runs a task and never
calls Telegram or an LLM. The Freebuff agent remains the only executor.

Examples:
  python tools/telegram_queue.py list
  python tools/telegram_queue.py next
  python tools/telegram_queue.py claim-next
  python tools/telegram_queue.py claim T-1234ABCD
  python tools/telegram_queue.py complete T-1234ABCD "summary"

`claim-next` is the automatic handoff point for the active Freebuff session:
it claims the oldest `ready` task atomically. `--include-awaiting` is available
only when the user has explicitly chosen no-approval mode.
"""

import json
import os
import sys
from datetime import datetime, timezone

# Windows terminals in this workspace may use cp1256/cp1252. Queue output is
# JSON and must remain readable when Telegram requests contain Persian text.
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
QUEUE_FILE = os.path.join(STATE_DIR, "queue.jsonl")
NOTIFY_FILE = os.path.join(STATE_DIR, "pending-notify")


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def load():
    try:
        with open(QUEUE_FILE, encoding="utf-8") as handle:
            return [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        return []


def save(tasks):
    temp = f"{QUEUE_FILE}.{os.getpid()}.tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        for task in tasks:
            handle.write(json.dumps(task, ensure_ascii=False) + "\n")
    os.replace(temp, QUEUE_FILE)


def find(tasks, task_id):
    return next((task for task in tasks if task.get("id") == task_id.upper()), None)


def main(args):
    tasks = load()
    command = args[0] if args else "list"
    if command in ("list", "next"):
        selected = [task for task in tasks if task.get("status") in ("ready", "in_progress", "awaiting_approval", "analyzing")]
        if command == "next":
            selected = selected[:1]
        for task in selected:
            print(json.dumps(task, ensure_ascii=False))
        return 0
    if command == "has-notify":
        has_ready = any(t.get("status") == "ready" for t in tasks)
        has_file = os.path.exists(NOTIFY_FILE)
        if has_ready and has_file:
            try:
                os.remove(NOTIFY_FILE)
            except OSError:
                pass
            print("yes")
            return 0
        if has_ready:
            print("yes")
            return 0
        print("no")
        return 1
    if command == "claim-next":
        include_awaiting = "--include-awaiting" in args[1:]
        allowed = ("ready", "awaiting_approval") if include_awaiting else ("ready",)
        task = next((item for item in tasks if item.get("status") in allowed), None)
        if not task:
            print("no executable Telegram task is ready", file=sys.stderr)
            return 1
        task.update({"status": "in_progress", "claimed_by": "freebuff-session", "claimed_at": now(), "updated_at": now()})
        save(tasks)
        print(json.dumps(task, ensure_ascii=False))
        return 0
    if command not in ("claim", "complete", "fail") or len(args) < 2:
        print("usage: list | next | claim-next [--include-awaiting] | claim TASK-ID | complete TASK-ID SUMMARY | fail TASK-ID REASON", file=sys.stderr)
        return 2
    task = find(tasks, args[1])
    if not task:
        print(f"task not found: {args[1]}", file=sys.stderr)
        return 1
    if command == "claim":
        if task.get("status") != "ready":
            print(f"task is not ready: {task.get('status')}", file=sys.stderr)
            return 1
        task.update({"status": "in_progress", "claimed_by": "freebuff-session", "claimed_at": now(), "updated_at": now()})
    elif command == "complete":
        task.update({"status": "completed", "result": " ".join(args[2:]), "completed_at": now(), "updated_at": now()})
    else:
        task.update({"status": "failed", "result": " ".join(args[2:]) or "بدون دلیل", "updated_at": now()})
    save(tasks)
    print(json.dumps(task, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
