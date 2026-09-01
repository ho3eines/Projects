#!/usr/bin/env python3
"""Local Telegram task queue for the Freebuff workspace.

This daemon deliberately does not invoke Claude, an LLM, shell commands, or
repository code. It only receives authorized Telegram messages, turns them
into durable Todo records, and reports queue/approval state. Freebuff reads
~/.telegram-bridge/agent/queue.jsonl in a later workspace session and performs
approved work itself.

Configuration is loaded from environment variables or ~/.telegram-bridge/agent.env:
  TELEGRAM_BOT_TOKEN  bot token
  TELEGRAM_CHAT_ID    authorized chat id
  TELEGRAM_AGENT_ROOT repository root (informational only)

Telegram commands:
  /help
  /status
  /queue
  /approve TASK-ID
  /reject TASK-ID [reason]
  /done TASK-ID [summary]
  /report TASK-ID [summary]

Normal text creates a task in awaiting_approval. No task is executed by this
process. This is intentional: the active Freebuff session is the only executor.
"""

import atexit
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
import uuid
from datetime import datetime, timezone

TOKEN_ENV = "TELEGRAM_BOT_TOKEN"
CHAT_ENV = "TELEGRAM_CHAT_ID"
AUTO_ENV = "TELEGRAM_AUTO_APPROVE"
ROOT = os.path.abspath(os.environ.get("TELEGRAM_AGENT_ROOT", os.path.join(os.path.dirname(__file__), "..")))
STATE_DIR = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "agent")
CONFIG_FILE = os.path.join(ROOT, ".telegram-agent.env")
QUEUE_FILE = os.path.join(STATE_DIR, "queue.jsonl")
OUTBOX_FILE = os.path.join(STATE_DIR, "outbox.jsonl")
OFFSET_FILE = os.path.join(STATE_DIR, "agent-offset")
LOCK_FILE = os.path.join(os.path.dirname(STATE_DIR), "bridge.lock")
STOP_FILE = os.path.join(STATE_DIR, "agent.stop")
LOG_FILE = os.path.join(STATE_DIR, "agent.log")
AUTO_FILE = os.path.join(STATE_DIR, "auto-mode")
LOCK_HANDLE = None


def read_local_config():
    values = {}
    try:
        with open(CONFIG_FILE, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    values[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        pass
    return values


LOCAL_CONFIG = read_local_config()
TOKEN = os.environ.get(TOKEN_ENV, LOCAL_CONFIG.get(TOKEN_ENV, ""))
CHAT_ID = str(os.environ.get(CHAT_ENV, LOCAL_CONFIG.get(CHAT_ENV, "76937621")))


def auto_approve_enabled():
    """Check runtime auto-mode flag (file-based so /auto can toggle without restart)."""
    env_val = os.environ.get(AUTO_ENV, LOCAL_CONFIG.get(AUTO_ENV, "")).strip().lower()
    if env_val in ("1", "true", "yes", "on"):
        return True
    try:
        with open(AUTO_FILE, encoding="ascii") as handle:
            return handle.read().strip().lower() in ("1", "true", "yes", "on")
    except OSError:
        return False

if not TOKEN:
    raise SystemExit(f"{TOKEN_ENV} is not set; configure {CONFIG_FILE}")

os.makedirs(STATE_DIR, exist_ok=True)


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def log(message):
    line = f"{now()} {message}"
    try:
        print(line, flush=True)
    except (UnicodeError, OSError):
        # stdout may be redirected to a non-UTF-8 sink (Task Scheduler,
        # Windows console codepage) — logging must never crash the daemon.
        pass
    try:
        with open(LOG_FILE, "a", encoding="utf-8") as handle:
            handle.write(line + "\n")
    except OSError:
        pass


def read_offset():
    try:
        with open(OFFSET_FILE, encoding="ascii") as handle:
            return int(handle.read().strip() or 0)
    except (OSError, ValueError):
        # Start after updates already consumed by the old bridge.
        old_offset = os.path.join(os.path.dirname(STATE_DIR), "offset")
        try:
            with open(old_offset, encoding="ascii") as handle:
                return int(handle.read().strip() or 0)
        except (OSError, ValueError):
            return 0


def write_offset(value):
    temp = f"{OFFSET_FILE}.{os.getpid()}.tmp"
    with open(temp, "w", encoding="ascii") as handle:
        handle.write(str(value))
    os.replace(temp, OFFSET_FILE)


def pid_exists(pid):
    """Robust process-existence check.

    On Windows, os.kill(pid, 0) can raise OSError 22 (ERROR_INVALID_PARAMETER)
    even for live processes spawned through launcher shims (e.g. a uv re-exec
    parented by the hermes venv python). That made the lock check treat the
    running agent as dead, so a second instance stole the lock and the two
    pollers fought over getUpdates (Telegram 409). OpenProcess with
    PROCESS_QUERY_LIMITED_INFORMATION is reliable for same-user processes and
    returns ERROR_INVALID_PARAMETER (87) only for really dead PIDs.
    """
    if os.name == "nt":
        import ctypes

        PROCESS_QUERY_LIMITED_INFORMATION = 0x1000
        handle = ctypes.windll.kernel32.OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, False, pid)
        if handle:
            ctypes.windll.kernel32.CloseHandle(handle)
            return True
        return ctypes.windll.kernel32.GetLastError() != 87
    try:
        os.kill(pid, 0)
        return True
    except (OSError, ProcessLookupError, SystemError):
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
            with open(LOCK_FILE, encoding="ascii") as handle:
                pid = int(handle.read().strip())
        except (OSError, ValueError):
            pid = 0
        if pid and pid_exists(pid):
            log(f"another Telegram consumer is running (pid {pid})")
            return False
        try:
            os.remove(LOCK_FILE)
        except OSError:
            return False
        return acquire_lock()


# ────────────────────────────────────────────
# API primitives
# ────────────────────────────────────────────

def callback_data_safe(label, limit=60):
    """Truncate a label to `limit` UTF-8 bytes at a char boundary.

    Telegram rejects callback_data > 64 bytes (BUTTON_DATA_INVALID); emoji and
    Persian text are multi-byte, so character-length checks are not enough.
    """
    label = str(label)
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


def api(method, params, timeout=25):
    query = urllib.parse.urlencode(params)
    request = urllib.request.Request(
        f"https://api.telegram.org/bot{TOKEN}/{method}?{query}",
        headers={"User-Agent": "Tarazin-Freebuff-Queue/1.0"},
    )
    with urllib.request.urlopen(request, timeout=timeout) as response:
        payload = json.load(response)
    if not payload.get("ok"):
        raise RuntimeError(str(payload))
    return payload.get("result", [])


def send(text, reply_markup=None):
    text = str(text)
    if len(text) > 3900:
        text = text[:3800] + "\n[پیام کوتاه شد؛ رکورد کامل در صف محلی است]"
    params = {"chat_id": CHAT_ID, "text": text}
    if reply_markup:
        # Sanitize stale records: clamp every callback_data to the 64-byte limit.
        markup = json.loads(json.dumps(reply_markup))
        for row in markup.get("inline_keyboard", []):
            for button in row:
                if "callback_data" in button:
                    button["callback_data"] = callback_data_safe(button["callback_data"])
        params["reply_markup"] = json.dumps(markup)
    try:
        api("sendMessage", params)
        return True
    except Exception as exc:
        log(f"send failed: {exc}")
        return False


def answer_callback(callback_query_id, text=""):
    try:
        api("answerCallbackQuery", {"callback_query_id": callback_query_id, "text": text})
    except Exception as exc:
        log(f"answer_callback failed: {exc}")


def dynamic_buttons():
    """Build suggestion buttons from the current queue state — dynamic, not fixed phases.

    Replaces the old fixed phase:3/4/5 buttons. Suggestions follow the actual
    state of the queue (pending ready tasks, running task, or empty).
    """
    tasks = load_tasks()
    ready_count = sum(1 for task in tasks if task.get("status") == "ready")
    running = next((task for task in reversed(tasks) if task.get("status") == "in_progress"), None)

    buttons = []
    if ready_count:
        buttons.append({"text": f"▶️ اجرای صف ({ready_count} آماده)", "callback_data": "queue:run"})
    if running:
        buttons.append({"text": f"🔄 وضعیت {running['id']}", "callback_data": "status"})
    buttons.append({"text": "📊 وضعیت صف", "callback_data": "status"})
    buttons.append({"text": "🧹 پاک‌سازی صف", "callback_data": "queue:clean"})
    if not buttons:
        buttons.append({"text": "📊 وضعیت صف", "callback_data": "status"})
    safe = []
    for button in buttons:
        safe.append({"text": button["text"], "callback_data": callback_data_safe(button["callback_data"])})
    return {"inline_keyboard": [[button] for button in safe]}


def send_with_dynamic_buttons(text, buttons_fn=dynamic_buttons):
    send(text, reply_markup=buttons_fn())


def send_pending():
    """Deliver reports queued by the active Freebuff session, retaining failures."""
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            records = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        return
    except (OSError, json.JSONDecodeError) as exc:
        log(f"outbox read failed: {exc}")
        return
    remaining = []
    for record in records:
        markup = record.get("reply_markup")
        if not send(record.get("text", ""), reply_markup=markup):
            remaining.append(record)
    if remaining:
        temp = f"{OUTBOX_FILE}.{os.getpid()}.tmp"
        with open(temp, "w", encoding="utf-8") as handle:
            for record in remaining:
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        os.replace(temp, OUTBOX_FILE)
    else:
        try:
            os.remove(OUTBOX_FILE)
        except OSError:
            pass


def load_tasks():
    tasks = []
    try:
        with open(QUEUE_FILE, encoding="utf-8") as handle:
            for line in handle:
                try:
                    tasks.append(json.loads(line))
                except json.JSONDecodeError:
                    log("ignored malformed queue record")
    except OSError:
        pass
    return tasks


def save_tasks(tasks):
    temp = f"{QUEUE_FILE}.{os.getpid()}.tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        for task in tasks:
            handle.write(json.dumps(task, ensure_ascii=False) + "\n")
    os.replace(temp, QUEUE_FILE)


def update_task(task_id, **changes):
    tasks = load_tasks()
    for task in tasks:
        if task.get("id") == task_id:
            task.update(changes)
            task["updated_at"] = now()
            save_tasks(tasks)
            return task
    return None


def find_task(task_id):
    return next((task for task in load_tasks() if task.get("id") == task_id.upper()), None)


def make_todos(request):
    """Create transparent local Todos; planning remains visible to Freebuff."""
    clean = re.sub(r"\s+", " ", request).strip()
    return [
        {
            "title": "بررسی معماری و وضعیت فعلی مرتبط با درخواست",
            "acceptance": "Freebuff فایل‌ها، سرویس‌ها و تست‌های موجود را بررسی و مسیر تغییر را مشخص کند.",
        },
        {
            "title": f"پیاده‌سازی درخواست کاربر: {clean[:180]}",
            "acceptance": "تغییرات با الگوهای فعلی پروژه انجام شود و منطق موجود شکسته نشود.",
        },
        {
            "title": "اجرای build و تست‌های مرتبط",
            "acceptance": "نتیجهٔ build/test و ریسک‌های باقی‌مانده در گزارش نهایی ثبت شود.",
        },
    ]


NOTIFY_FILE = os.path.join(STATE_DIR, "pending-notify")


def notify_freebuff():
    """Write a flag file so the active Freebuff session knows to call claim-next."""
    try:
        with open(NOTIFY_FILE, "w", encoding="ascii") as handle:
            handle.write(now())
    except OSError:
        pass


def create_task(request, update_id=None):
    auto = auto_approve_enabled()
    task = {
        "id": "T-" + uuid.uuid4().hex[:8].upper(),
        "request": request,
        "todos": make_todos(request),
        "status": "ready" if auto else "awaiting_approval",
        "execution_owner": "freebuff-session",
        "auto_approved": auto,
        "created_at": now(),
        "updated_at": now(),
        "telegram_update_id": update_id,
        "result": None,
    }
    tasks = load_tasks()
    tasks.append(task)
    save_tasks(tasks)
    if auto:
        notify_freebuff()
    return task


def format_task(task):
    todos = "\n".join(f"{i + 1}. {item['title']}" for i, item in enumerate(task["todos"]))
    if task.get("auto_approved"):
        return (
            f"📋 Task {task['id']} در صف اجرای Freebuff قرار گرفت.\n\n"
            f"درخواست:\n{task['request']}\n\n"
            f"Todo:\n{todos}\n\n"
            "حالت خودکار فعال است؛ نشست Freebuff باید claim-next بزند."
        )
    return (
        f"📋 Task {task['id']} در صف Todo ثبت شد.\n\n"
        f"درخواست:\n{task['request']}\n\n"
        f"Todo:\n{todos}\n\n"
        "این daemon فقط صف می‌سازد؛ اجرا توسط نشست فعال Freebuff انجام می‌شود.\n"
        f"برای ورود به صف اجرای Freebuff:\n/approve {task['id']}\n"
        f"برای رد کردن:\n/reject {task['id']} دلیل"
    )


def handle_command(text):
    parts = text.strip().split(maxsplit=2)
    command = parts[0].lower()
    if command in ("/start", "/help"):
        send("دستورات:\n/help\n/status\n/queue\n/auto on|off\n/approve TASK-ID\n/reject TASK-ID دلیل\n/done TASK-ID گزارش\n/report TASK-ID گزارش")
        return
    if command == "/auto":
        arg = parts[1].lower() if len(parts) > 1 else ""
        if arg in ("on", "1", "true", "yes"):
            with open(AUTO_FILE, "w", encoding="ascii") as handle:
                handle.write("1")
            send("✅ حالت خودکار روشن شد. پیام‌های جدید مستقیماً ready می‌شوند.")
        elif arg in ("off", "0", "false", "no"):
            try:
                os.remove(AUTO_FILE)
            except OSError:
                pass
            send("⛔ حالت خودکار خاموش شد. پیام‌های جدید نیاز به /approve دارند.")
        else:
            state = "روشن" if auto_approve_enabled() else "خاموش"
            send(f"حالت خودکار: {state}\nفرمت: /auto on یا /auto off")
        return
    if command == "/status":
        tasks = load_tasks()
        counts = {}
        for task in tasks:
            counts[task.get("status", "unknown")] = counts.get(task.get("status", "unknown"), 0) + 1
        summary = "\n".join(f"{key}: {value}" for key, value in sorted(counts.items())) or "صف خالی است."
        send(f"🟢 صف محلی فعال است؛ executor: Freebuff\n{summary}")
        return
    if command == "/queue":
        tasks = load_tasks()[-10:]
        send("\n".join(f"{t['id']} — {t['status']} — {t['request'][:90]}" for t in tasks) if tasks else "صف خالی است.")
        return
    if command not in ("/approve", "/reject", "/done", "/report"):
        send("دستور ناشناخته است؛ /help را ارسال کنید.")
        return
    if len(parts) < 2:
        send(f"فرمت صحیح: {command} TASK-ID متن اختیاری")
        return
    task_id = parts[1].upper()
    task = find_task(task_id)
    if not task:
        send(f"Task پیدا نشد: {task_id}")
        return
    if command == "/approve":
        if task["status"] not in ("awaiting_approval", "queued"):
            send(f"Task {task_id} قابل تأیید نیست؛ وضعیت: {task['status']}")
            return
        update_task(task_id, status="ready")
        send(f"✅ Task {task_id} در صف اجرای Freebuff قرار گرفت. نشست Freebuff باید آن را بخواند.")
    elif command == "/reject":
        update_task(task_id, status="rejected", rejection_reason=parts[2] if len(parts) > 2 else "بدون دلیل")
        send(f"Task {task_id} رد شد.")
    else:
        summary = parts[2] if len(parts) > 2 else ""
        update_task(task_id, status="completed" if command == "/done" else "reported", result=summary, completed_at=now())
        send(f"گزارش Task {task_id} ثبت شد.")


def handle_callback(update):
    cb = update.get("callback_query") or {}
    cb_chat_id = str((cb.get("message") or {}).get("chat", {}).get("id", ""))
    if cb_chat_id != CHAT_ID:
        log(f"ignored unauthorized callback chat {cb_chat_id}")
        return
    data = (cb.get("data") or "").strip()
    cb_id = cb.get("id", "")
    if not data:
        return
    answer_callback(cb_id, "در حال پردازش...")

    # Legacy fixed phase buttons still work for already-sent messages.
    if data.startswith("phase:"):
        phase = data.split(":", 1)[1]
        phase_map = {"3": "فاز ۳ — UI صفحات Blazor برای فاکتور خرید/فروش/انتقال/برگشت با EntityPickerField و MudBlazor",
                     "4": "فاز ۴ — Permissions و Audit Log برای ماژول انبار",
                     "5": "فاز ۵ — تست‌های سناریو: خرید/فروش/برگشت/هدیه/مالیات/انتقال"}
        request = phase_map.get(phase, f"فاز {phase}")
        task = create_task(request, update.get("update_id"))
        send(format_task(task), reply_markup=dynamic_buttons())
        log(f"created {task['id']} from callback {data}")
        return

    tasks = load_tasks()
    if data == "status":
        counts = {}
        for task in tasks:
            counts[task.get("status", "unknown")] = counts.get(task.get("status", "unknown"), 0) + 1
        summary = "\n".join(f"{key}: {value}" for key, value in sorted(counts.items())) or "صف خالی است."
        send(f"🟢 وضعیت صف:\n{summary}", reply_markup=dynamic_buttons())
        return
    if data == "queue:run":
        ready = [task for task in tasks if task.get("status") == "ready"]
        if ready:
            notify_freebuff()
            send(f"▶️ {len(ready)} Task آمادهٔ اجراست؛ Freebuff باید آن‌ها را claim کند. (has-notify تنظیم شد)",
                 reply_markup=dynamic_buttons())
        else:
            send("صف اجرایی خالی است.", reply_markup=dynamic_buttons())
        return
    if data == "queue:clean":
        count = sum(1 for task in tasks if task.get("status") in ("ready", "in_progress", "awaiting_approval"))
        for task in tasks:
            if task.get("status") in ("ready", "in_progress", "awaiting_approval"):
                task["status"] = "completed"
                task.setdefault("result", "پاک‌سازی دستی توسط کاربر")
        save_tasks(tasks)
        send(f"🧹 {count} Task به وضعیت completed منتقل شد.", reply_markup=dynamic_buttons())
        return

    # Any other button label becomes a task request (dynamic custom buttons).
    task = create_task(data, update.get("update_id"))
    send(format_task(task), reply_markup=dynamic_buttons())
    log(f"created {task['id']} from callback {data}")


def process_update(update):
    # Handle inline button callbacks
    if update.get("callback_query"):
        handle_callback(update)
        return
    message = update.get("message") or update.get("edited_message") or {}
    chat_id = str((message.get("chat") or {}).get("id", ""))
    if chat_id != CHAT_ID:
        log(f"ignored unauthorized chat {chat_id}")
        return
    text = (message.get("text") or "").strip()
    if not text:
        return
    if text.startswith("/"):
        handle_command(text)
        return
    task = create_task(text, update.get("update_id"))
    send(format_task(task), reply_markup=dynamic_buttons())
    log(f"created {task['id']}")


def poll(offset):
    try:
        updates = api("getUpdates", {"timeout": 8, "offset": offset, "limit": 20, "allowed_updates": '["message", "callback_query"]'}, timeout=18)
        for update in updates:
            process_update(update)
            offset = max(offset, update["update_id"] + 1)
        return offset
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            log("Telegram 409: another consumer is polling; retrying in 20s")
            time.sleep(20)
        elif exc.code == 429:
            log("Telegram 429: rate limited; retrying in 10s")
            time.sleep(10)
        else:
            log(f"Telegram HTTP error: {exc}")
            time.sleep(5)
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        log(f"Telegram network error: {exc}; retrying in 5s")
        time.sleep(5)
    except Exception as exc:
        log(f"Telegram poll error: {exc}; retrying in 5s")
        time.sleep(5)
    return offset


def main():
    if not acquire_lock():
        return 2
    log(f"local Telegram queue started; root={ROOT}; no Claude executor")
    offset = read_offset()
    try:
        while True:
            if os.path.exists(STOP_FILE):
                os.remove(STOP_FILE)
                log("stop file seen; exiting")
                return 0
            send_pending()
            offset = poll(offset)
            write_offset(offset)
            send_pending()
    except KeyboardInterrupt:
        return 0
    finally:
        release_lock()


if __name__ == "__main__":
    raise SystemExit(main())
