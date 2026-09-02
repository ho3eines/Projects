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
import random
import re
import subprocess
import sys
import threading
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
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
STATUS_FILE = os.path.join(STATE_DIR, "status.json")

# شناسهٔ یکتای رکوردهای صف: زمان + شمارنده. در ویندوز، فراخوانی‌های پشت‌سرهمِ
# time.time_ns() می‌توانند مقدار یکسان برگردانند (مشاهده در تست — دو رکورد با یک
# شناسه) که باعث حذف اشتباهی رکوردِ تحویل‌نشده توسط _drop_outbox_record می‌شود.
_last_msg_seq = 0

def _new_message_id():
    global _last_msg_seq
    _last_msg_seq += 1
    return f"M-{time.time_ns()}-{_last_msg_seq}"

HISTORY_FILE = os.path.join(STATE_DIR, "history.jsonl")
HISTORY_SAMPLE_SECONDS = 60      # فاصلهٔ نمونه‌گیری روند (۲۴h = ۱۴۴۰ نمونه)
HISTORY_MAX_LINES = 6000         # حداکثر خطوط فایل روند (پوشش ~۳۰ روز با دو سطح رزولوشن)
HISTORY_HOT_SECONDS = 24 * 3600  # ۲۴ ساعتِ آخر با رزولوشن ۶۰ ثانیه نگه داشته می‌شود
HISTORY_COARSE_SECONDS = 600     # قدیمی‌ترها به باکت ۱۰ دقیقه‌ای فشرده می‌شوند (۳۰ روز ≈ ۴۲۰۰ خط)
_last_history_ts = 0.0
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

# ── پروکسی تلگرام (اختیاری) ─────────────────────────────────────
# خالی/حذف = اتصال مستقیم؛ مثال: TELEGRAM_PROXY=http://127.0.0.1:3067
# برای تغییر پورت فقط مقدار را عوض کنید؛ برای غیرفعال کردن مقدار را خالی کنید.
# ⚠ تغییر TELEGRAM_PROXY در فایل config → ری‌استارت خودکار agent (گام دستی لازم نیست).
PROXY_ENV = "TELEGRAM_PROXY"
PROXY = os.environ.get(PROXY_ENV, LOCAL_CONFIG.get(PROXY_ENV, "")).strip()
_OPENER = None
if PROXY:
    try:
        _OPENER = urllib.request.build_opener(
            urllib.request.ProxyHandler({"http": PROXY, "https": PROXY}))
    except Exception as exc:  # pragma: no cover
        log(f"telegram proxy setup failed: {exc}; falling back to direct")
        _OPENER = None

# ── ترنسپورت دریافت: long-poll یا webhook ─────────────────────────
# TELEGRAM_TRANSPORT: poll | webhook | auto (پیش‌فرض auto)
#   auto    → اگر TELEGRAM_WEBHOOK_URL ست شده باشد webhook، وگرنه poll
#   poll    → getUpdates (fallback فعلی؛ پروکسی در همین حالت حفظ می‌شود)
#   webhook → setWebhook + گیرندهٔ محلی؛ آپدیت‌ها فوری و بدون 409 می‌رسند
#
# برای webhook باید آدرس HTTPS عمومی در TELEGRAM_WEBHOOK_URL داده شود که
# تلگرام بتواند به گیرندهٔ محلی TELEGRAM_WEBHOOK_LISTEN (مثلاً از طریق تونل)
# برسد. TELEGRAM_WEBHOOK_SECRET به‌عنوان secret_token ثبت می‌شود تا فقط
# پیام‌های واقعی تلگرام پذیرفته شوند.
TRANSPORT_ENV = "TELEGRAM_TRANSPORT"
WEBHOOK_URL_ENV = "TELEGRAM_WEBHOOK_URL"
WEBHOOK_SECRET_ENV = "TELEGRAM_WEBHOOK_SECRET"
WEBHOOK_LISTEN_ENV = "TELEGRAM_WEBHOOK_LISTEN"
WEBHOOK_LISTEN_DEFAULT = "127.0.0.1:8443"
ALLOWED_UPDATES_JSON = '["message", "callback_query"]'
WEBHOOK_CHECK_INTERVAL = 300

TRANSPORT = (os.environ.get(TRANSPORT_ENV, LOCAL_CONFIG.get(TRANSPORT_ENV, "auto"))
             or "auto").strip().lower()
WEBHOOK_URL = os.environ.get(WEBHOOK_URL_ENV, LOCAL_CONFIG.get(WEBHOOK_URL_ENV, "")).strip()
WEBHOOK_SECRET = os.environ.get(WEBHOOK_SECRET_ENV, LOCAL_CONFIG.get(WEBHOOK_SECRET_ENV, "")).strip()
WEBHOOK_LISTEN = (os.environ.get(WEBHOOK_LISTEN_ENV, LOCAL_CONFIG.get(WEBHOOK_LISTEN_ENV, ""))
                  or WEBHOOK_LISTEN_DEFAULT).strip()
_webhook_registered = False
_effective_transport = "poll"   # در main با resolve_transport تنظیم می‌شود

# قفل‌های همگانی: وقتی poll و webhook هر دو درگیر فایل‌های صف/outbox هستند،
# نوشتن هم‌زمان رکوردها را خراب نمی‌کند. RLock → فراخوانی تودرتو مجاز است.
_SEND_LOCK = threading.RLock()    # outbox: send / send_pending / drop
_UPDATE_LOCK = threading.RLock()  # پردازش update (گیرندهٔ webhook) سریال می‌شود
_STATUS_LOCK = threading.RLock()  # status.json + history.jsonl (thread-safe)


def _locked(lock):
    """دکوراتور ساده: اجرای تابع زیر قفل (RLock → تودرتو مجاز است)."""
    def decorator(fn):
        def wrapper(*args, **kwargs):
            with lock:
                return fn(*args, **kwargs)
        return wrapper
    return decorator

# ── Resilience: long-poll و retry-backoff هوشمند ──────────────────
# Long-poll طولانی‌تر = دست‌دادن‌های SSL کمتر؛ backoff نمایی با جیتر باعث
# می‌شود هنگام ناپایداری شبکه، تعداد تلاش‌ها (و خطاهای لاگ) به‌شدت کم شود.
POLL_TIMEOUT = 25       # ثانیهٔ long-poll تلگرام (سقف مجاز: ۵۰)
REQUEST_TIMEOUT = 40    # تایم‌اوت سوکت برای همان درخواست (باید > POLL_TIMEOUT)
BACKOFF_BASE = 2.0      # اولین تاخیر مجدد (ثانیه)
BACKOFF_CAP = 60.0      # سقف تاخیر مجدد
SEND_ATTEMPT_TIMEOUT = 10  # تایم‌اوت کوتاه برای هر تلاش ارسال — حلقه را سریع نگه می‌دارد
_consecutive_failures = 0
_last_offset = 0          # آخرین offset پردازش‌شده — برای ری‌استارت امن لازم است
HEALTH_ALERT_THRESHOLD = 5   # خطاهای پشتسرهم؛ از این بیشتر شد → هشدار به تلگرام
HEALTH_ALERT_PREFIX = "⚠️ هشدار سلامت ربات تلگرام\n"
_health_degraded = False
_health_start_ts = time.time()
OUTBOX_WARN_THRESHOLD = 10   # رکوردهای معوق بیشتر از این → هشدار جداگانه (یک‌بار)
OUTBOX_HARD_CAP = 50         # سقف سخت: بالاتر از این، رکورد جدید پذیرفته نمی‌شود
_outbox_warned = False
_last_error = ""
_last_error_ts = 0.0
_last_success_ts = 0.0


def _backoff_delay():
    """تاخیر نمایی با جیتر؛ بعد از هر موفقیت reset می‌شود."""
    global _consecutive_failures
    _consecutive_failures += 1
    exp = BACKOFF_BASE * (2 ** (_consecutive_failures - 1))
    return min(BACKOFF_CAP, exp * (1 + random.uniform(0, 0.3)))


@_locked(_SEND_LOCK)
def enqueue_outbox(text):
    """قرار دادن پیام در outbox برای تحویل مطمئن (حلقهٔ اصلی با retry می‌فرستد)."""
    payload = {
        "id": _new_message_id(),
        "chat_id": CHAT_ID,
        "text": text,
        "created_at": time.time(),
        "priority": "normal",
    }
    try:
        with open(OUTBOX_FILE, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(payload, ensure_ascii=False) + "\n")
        return True
    except OSError as exc:
        log(f"health enqueue failed: {exc}")
        return False


@_locked(_SEND_LOCK)
def drop_pending_health_alerts():
    """حذف هشدارهای سلامتِ تحویل‌نشده از outbox تا بعد از بهبود، پیام قدیمی نرسد."""
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            records = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError):
        return
    remaining = [r for r in records if not (r.get("text") or "").startswith(HEALTH_ALERT_PREFIX)]
    if len(remaining) == len(records):
        return
    temp = f"{OUTBOX_FILE}.{os.getpid()}.tmp"
    try:
        with open(temp, "w", encoding="utf-8") as handle:
            for record in remaining:
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        os.replace(temp, OUTBOX_FILE)
    except OSError:
        pass


@_locked(_STATUS_LOCK)
def update_status():
    """فایل وضعیت واحد (status.json) — نمای کامل سلامت برای /status و ابزارهای بیرونی."""
    outbox_count = 0
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            outbox_count = sum(1 for _ in handle)
    except OSError:
        pass
    payload = {
        "updated_at": now(),
        "pid": os.getpid(),
        "mode": "webhook" if resolve_transport() == "webhook" else "poll",
        "transport": PROXY or "direct",
        "proxy": PROXY,
        "webhook_url": WEBHOOK_URL,
        "webhook_registered": _webhook_registered,
        "consecutive_failures": _consecutive_failures,
        "health_degraded": _health_degraded,
        "outbox_pending": outbox_count,
        "outbox_warned": _outbox_warned,
        "last_error": _last_error,
        "last_error_at": _last_error_ts,
        "last_success_at": _last_success_ts,
        "uptime_seconds": int(time.time() - _health_start_ts),
    }
    try:
        with open(STATUS_FILE, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, ensure_ascii=False, indent=1)
    except OSError:
        pass
    _append_history_sample(outbox_count)


def _append_history_sample(outbox_count):
    """نمونهٔ روند ۲۴ساعته (failures/outbox/degraded) — حداکثر هر HISTORY_SAMPLE_SECONDS یک‌بار."""
    global _last_history_ts
    now_ts = time.time()
    if now_ts - _last_history_ts < HISTORY_SAMPLE_SECONDS:
        return
    _last_history_ts = now_ts
    sample = {
        "ts": now_ts,
        "failures": _consecutive_failures,
        "outbox": outbox_count,
        "degraded": 1 if _health_degraded else 0,
    }
    try:
        with open(HISTORY_FILE, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(sample) + "\n")
        _prune_history_file()
    except OSError:
        pass


def _prune_history_file():
    """بازنویسی فایل روند با دو سطح رزولوشن (نگهداشت ~۳۰ روز):

    ۲۴ ساعتِ آخر → همان نمونه‌های ۶۰ ثانیه‌ای؛ قدیمی‌ترها → هر باکت ۱۰ دقیقه
    یک نمونه (بدترین مقدار failures/outbox/degraded). سقف HISTORY_MAX_LINES.
    """
    try:
        with open(HISTORY_FILE, encoding="utf-8") as handle:
            lines = handle.readlines()
    except OSError:
        return
    if len(lines) <= HISTORY_MAX_LINES:
        return

    rows = []
    for line in lines:
        line = line.strip()
        if not line:
            continue
        try:
            rows.append(json.loads(line))
        except ValueError:
            continue
    if not rows:
        return

    # ترتیب فایل روند در عمل append-only است (جدیدترین در انتها)، ولی به هر حال
    # با max مستقل از ترتیب فایل کار می‌کنیم تا خطاهای احتمالی ترتیب، pruning را
    # به‌هم نریزند.
    newest = max(r["ts"] for r in rows)
    cutoff = newest - HISTORY_HOT_SECONDS
    hot = [r for r in rows if r["ts"] >= cutoff]
    cold = [r for r in rows if r["ts"] < cutoff]

    # قدیمی‌ها: هر باکت ۱۰ دقیقه → نمونه با بیشترین (failures, outbox, degraded)
    # و ts نمونه به ابتدای باکت نرمال می‌شود تا ردیف‌های قدیمی هم باکتی باشند.
    buckets = {}
    for r in cold:
        b = int(r["ts"] // HISTORY_COARSE_SECONDS) * HISTORY_COARSE_SECONDS
        prev = buckets.get(b)
        if prev is None or (r["failures"], r["outbox"], r["degraded"]) > \
                (prev["failures"], prev["outbox"], prev["degraded"]):
            buckets[b] = dict(r, ts=b)

    merged = hot + [buckets[k] for k in sorted(buckets)]
    merged.sort(key=lambda r: r["ts"])
    try:
        with open(HISTORY_FILE, "w", encoding="utf-8") as handle:
            for r in merged[-HISTORY_MAX_LINES:]:
                handle.write(json.dumps(r) + "\n")
    except OSError:
        pass


def health_check():
    """هشدار به تلگرام وقتی خطاهای پشتسرهم از آستانه رد شوند + اطلاع بهبود.

    فقط در لحظهٔ گذر از آستانه یک‌بار هشدار می‌دهد (نه برای هر خطا) و بعد از
    بهبود، هشدارِ تحویل‌نشده را از outbox حذف و «عادی شد» را جایگزین می‌کند.
    """
    global _health_degraded
    if _consecutive_failures >= HEALTH_ALERT_THRESHOLD and not _health_degraded:
        _health_degraded = True
        update_status()
        alert = (
            HEALTH_ALERT_PREFIX
            + f"{_consecutive_failures} خطای پشت‌سرهم در اتصال به تلگرام\n"
            + f"• پروکسی: {PROXY or 'غیرفعال (مستقیم)'}\n"
            + "• agent همچنان فعال است و با backoff تلاش می‌کند؛ پیام‌ها در صف محلی امن‌اند."
        )
        enqueue_outbox(alert)
        log(f"health: degraded ({_consecutive_failures} consecutive failures) — alert queued")
    elif _consecutive_failures == 0 and _health_degraded:
        _health_degraded = False
        drop_pending_health_alerts()
        enqueue_outbox("✅ وضعیت اتصال ربات تلگرام به حالت عادی برگشت.")
        update_status()
        log("health: recovered — alert queued")


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


def set_proxy_config(enabled):
    """به‌روزرسانی TELEGRAM_PROXY در CONFIG_FILE؛ بقیهٔ خطوط (توکن و...) دست‌نخورده می‌مانند."""
    proxy_line = "TELEGRAM_PROXY=http://127.0.0.1:3067" if enabled else "TELEGRAM_PROXY="
    try:
        with open(CONFIG_FILE, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        lines = []
    out, found = [], False
    for line in lines:
        if line.strip().startswith("TELEGRAM_PROXY="):
            out.append(proxy_line)
            found = True
        else:
            out.append(line)
    if not found:
        out.append(proxy_line)
    temp = CONFIG_FILE + ".tmp"
    with open(temp, "w", encoding="utf-8") as handle:
        handle.write("\n".join(out) + "\n")
    os.replace(temp, CONFIG_FILE)


def _config_proxy_value():
    """خواندن TELEGRAM_PROXY فعلی از فایل config — دقیقاً با همان قواعد read_local_config
    تا مقایسه با PROXY همیشه درست باشد (جلوگیری از حلقهٔ بی‌پایان ری‌استارت)."""
    try:
        with open(CONFIG_FILE, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    if key.strip() == "TELEGRAM_PROXY":
                        return value.strip().strip('"').strip("'")
    except OSError:
        pass
    return ""


def _config_proxy_changed():
    """آیا TELEGRAM_PROXY در فایل با مقدار در حال اجرا فرق دارد؟ (→ ری‌استارت خودکار)"""
    return _config_proxy_value() != PROXY


def restart_agent(reason):
    """نمونهٔ جداگانه spawn و سپس خروج — برای اعمال تغییرات config (پروکسی).

    ترتیب مهم است:
      ۱) offset فعلی ذخیره می‌شود تا نمونهٔ جدید همین update را دوباره پردازش نکند
         (گرنه حلقهٔ بی‌نهایت ری‌استارت رخ می‌دهد).
      ۲) نمونهٔ جدید spawn می‌شود (تا ۳۰ ثانیه برای قفل صبر می‌کند).
      ۳) قفل آزاد و فرایند فعلی خارج می‌شود.
    """
    log(f"restarting agent: {reason}")
    try:
        with open(OFFSET_FILE, "w", encoding="ascii") as handle:
            handle.write(str(_last_offset))
    except OSError:
        pass
    try:
        flags = 0
        if os.name == "nt":
            flags = (getattr(subprocess, "DETACHED_PROCESS", 0)
                     | getattr(subprocess, "CREATE_NEW_PROCESS_GROUP", 0)
                     | 0x00000200)  # CREATE_NO_WINDOW
        subprocess.Popen(
            [sys.executable, os.path.abspath(__file__)],
            cwd=os.path.dirname(os.path.abspath(__file__)),
            close_fds=True,
            creationflags=flags,
        )
    except Exception as exc:  # pragma: no cover
        log(f"restart spawn failed: {exc}")
        return False
    release_lock()
    os._exit(0)


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
            # لاگ فقط از main (یک خط برای watchdog) — این‌جا ساکت تا تکرار ۵ دقیقه‌ای
            # Task Scheduler باعث ۳۰ خط لاگ اضافه در هر دوره نشود.
            return False
        try:
            os.remove(LOCK_FILE)
        except OSError:
            return False
        return acquire_lock()


# ────────────────────────────────────────────
# Transport: webhook vs long-poll
# ────────────────────────────────────────────

def resolve_transport():
    """انتخاب ترنسپورت: webhook وقتی TELEGRAM_TRANSPORT=webhook یا auto+URL،
    وگرنه long-poll (fallback). webhook فقط با URL عمومی معنا دارد."""
    mode = TRANSPORT.lower()
    if mode == "webhook":
        return "webhook" if WEBHOOK_URL else "poll"
    if mode == "poll":
        return "poll"
    return "webhook" if WEBHOOK_URL else "poll"  # auto


def webhook_info():
    """getWebhookInfo — بررسی وضعیت ثبت webhook نزد تلگرام."""
    return api("getWebhookInfo", {}, timeout=SEND_ATTEMPT_TIMEOUT)


def register_webhook():
    """setWebhook با secret token و allowed_updates یکسان poll.
    drop_pending_updates=false تا هنگام جابه‌جایی poll→webhook چیزی گم نشود."""
    params = {
        "url": WEBHOOK_URL,
        "secret_token": WEBHOOK_SECRET or "",
        "allowed_updates": ALLOWED_UPDATES_JSON,
        "drop_pending_updates": "false",  # urlencode: Telegram به true/false کوچک نیاز دارد
    }
    return api("setWebhook", params, timeout=REQUEST_TIMEOUT)


def unregister_webhook():
    """deleteWebhook — بازگشت به long-poll بدون 409."""
    return api("deleteWebhook", {"drop_pending_updates": "false"}, timeout=SEND_ATTEMPT_TIMEOUT)


def ensure_webhook_registered():
    """ثبت webhook اگر هنوز ثبت نشده یا به URL دیگری اشاره می‌کند."""
    global _webhook_registered
    try:
        info = webhook_info()
        registered_url = str((info or {}).get("url") or "")
    except Exception as exc:
        log(f"getWebhookInfo failed during setup: {exc}")
        registered_url = None
    if registered_url == WEBHOOK_URL:
        _webhook_registered = True
        log(f"webhook already registered: {WEBHOOK_URL}")
        return True
    register_webhook()
    _webhook_registered = True
    log(f"webhook registered: {WEBHOOK_URL}")
    return True


def _ensure_no_stale_webhook():
    """قبل از شروع long-poll: اگر webhook کهنه ثبت شده، حذفش کن تا getUpdates
    با 409 Conflict روبه‌رو نشود (علت اصلی تعارض مصرف‌کننده‌ها)."""
    global _webhook_registered
    try:
        info = webhook_info()
        registered_url = str((info or {}).get("url") or "")
    except Exception:
        return
    if registered_url:
        try:
            unregister_webhook()
            _webhook_registered = False
            log(f"stale webhook removed before poll: {registered_url}")
        except Exception as exc:
            log(f"stale webhook removal failed: {exc}")


def _config_webhook_changed():
    """آیا TELEGRAM_WEBHOOK_URL/TRANSPORT در فایل با مقادیر در حال اجرا فرق دارد؟"""
    values = {}
    try:
        with open(CONFIG_FILE, encoding="utf-8") as handle:
            for raw in handle:
                line = raw.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    values[key.strip()] = value.strip().strip('"').strip("'")
    except OSError:
        return False
    return (values.get(WEBHOOK_URL_ENV, "") != WEBHOOK_URL
            or values.get(TRANSPORT_ENV, "auto").strip().lower() != TRANSPORT)


# ── گیرندهٔ محلی webhook (ThreadingHTTPServer) ─────────────────────
# تلگرام آپدیت را به URL عمومی (مثلاً تونل) پست می‌کند؛ این سرور محلی همان
# URL را روی پورت WEBHOOK_LISTEN سرو می‌کند. فقط بدنهٔ دارای secret_token
# معتبر پردازش می‌شود؛ پاسخ سریع 200 یعنی تلگرام retry نکند.

class _WebhookReceiver(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"

    def _authorized(self):
        supplied = self.headers.get("X-Telegram-Bot-Api-Secret-Token", "")
        return WEBHOOK_SECRET and supplied == WEBHOOK_SECRET

    def _respond(self, code, body=b""):
        self.send_response(code)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, OSError):
            pass

    def do_GET(self):  # noqa: N802
        self._respond(200, b"tarazin-webhook-ok")

    def do_POST(self):  # noqa: N802
        if not WEBHOOK_SECRET or not self._authorized():
            log("webhook rejected: bad/empty secret token")
            self._respond(403, b"forbidden")
            return
        try:
            length = int(self.headers.get("Content-Length") or 0)
            raw = self.rfile.read(length) if length else b"{}"
            update = json.loads(raw.decode("utf-8", "replace"))
        except Exception as exc:
            log(f"webhook payload error: {exc}")
            self._respond(400, b"bad request")
            return
        try:
            with _UPDATE_LOCK:
                process_update(update)
            _consecutive_failures_reset_ok()
        except Exception as exc:
            log(f"webhook processing error: {exc}")
            self._respond(500, b"internal error")
            return
        self._respond(200, b"ok")

    def log_message(self, fmt, *args):  # بی‌صدا — لاگ HTTP استاندارد را نخور
        return


def _consecutive_failures_reset_ok():
    """رسیدن موفق آپدیت از webhook = اتصال سالم → reset شمارندهٔ خطا."""
    global _consecutive_failures, _last_success_ts, _last_error
    if _consecutive_failures:
        _consecutive_failures = 0
        health_check()
    _last_success_ts = time.time()
    _last_error = ""


def start_webhook_server():
    host, _, port_text = WEBHOOK_LISTEN.rpartition(":")
    try:
        port = int(port_text)
    except ValueError:
        host, port = "127.0.0.1", 8443
    server = ThreadingHTTPServer((host or "127.0.0.1", port), _WebhookReceiver)
    server.daemon_threads = True
    return server


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
    if _OPENER is not None:
        with _OPENER.open(request, timeout=timeout) as response:
            payload = json.load(response)
    else:
        with urllib.request.urlopen(request, timeout=timeout) as response:
            payload = json.load(response)
    if not payload.get("ok"):
        raise RuntimeError(str(payload))
    return payload.get("result", [])


def _deliver(record):
    """تلاش همزمانِ کوتاه برای تحویل یک رکورد outbox (بدون تغییر صف)."""
    params = {"chat_id": record.get("chat_id") or CHAT_ID, "text": record.get("text", "")}
    if record.get("reply_markup"):
        params["reply_markup"] = json.dumps(record["reply_markup"])
    try:
        api("sendMessage", params, timeout=SEND_ATTEMPT_TIMEOUT)
        return True
    except Exception as exc:
        log(f"send failed: {exc}")
        return False


@_locked(_SEND_LOCK)
def _drop_outbox_record(record_id):
    """حذف یک رکورد تحویل‌شده از outbox."""
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            records = [json.loads(line) for line in handle if line.strip()]
    except (OSError, json.JSONDecodeError):
        return
    remaining = [r for r in records if r.get("id") != record_id]
    if len(remaining) == len(records):
        return
    temp = f"{OUTBOX_FILE}.{os.getpid()}.tmp"
    try:
        with open(temp, "w", encoding="utf-8") as handle:
            for record in remaining:
                handle.write(json.dumps(record, ensure_ascii=False) + "\n")
        os.replace(temp, OUTBOX_FILE)
    except OSError:
        pass


@_locked(_SEND_LOCK)
def send(text, reply_markup=None, priority="high"):
    """ارسال قابل‌اعتماد: اول در outbox (پایدار) ثبت می‌شود، بعد تلاش فوری کوتاه.

    اگر تلگرام قطع باشد پیام در صف می‌ماند و send_pending در حلقهٔ اصلی با
    backoff تحویلش می‌کند؛ ری‌استارت (حتی ری‌استارت پروکسی) پیام را از دست نمی‌دهد.

    priority="high": تأییدها و پاسخ‌های کلیک/دستور (پیش‌فرض — همهٔ فراخوان‌های
    داخلی پاسخِ کاربر هستند). رکوردهای بدون priority (گزارش‌های telegram_send.py
    و هشدارهای سلامت) عادی‌اند و بعد از high تحویل می‌شوند.
    """
    text = str(text)
    if len(text) > 3900:
        text = text[:3800] + "\n[پیام کوتاه شد؛ رکورد کامل در صف محلی است]"
    markup = None
    if reply_markup:
        # Sanitize stale records: clamp every callback_data to the 64-byte limit.
        markup = json.loads(json.dumps(reply_markup))
        for row in markup.get("inline_keyboard", []):
            for button in row:
                if "callback_data" in button:
                    button["callback_data"] = callback_data_safe(button["callback_data"])
    record = {"id": _new_message_id(), "chat_id": CHAT_ID, "text": text, "created_at": time.time()}
    if priority:
        record["priority"] = priority
    if markup:
        record["reply_markup"] = markup
    # سقف سخت: صف هیچ‌وقت بی‌نهایت رشد نمی‌کند — بالای سقف، رکورد جدید پذیرفته نمی‌شود.
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            pending_count = sum(1 for _ in handle)
    except OSError:
        pending_count = 0
    if pending_count >= OUTBOX_HARD_CAP:
        log(f"outbox at hard cap ({pending_count}); dropping new send")
        return False
    try:
        with open(OUTBOX_FILE, "a", encoding="utf-8") as handle:
            handle.write(json.dumps(record, ensure_ascii=False) + "\n")
    except OSError as exc:
        log(f"outbox write failed: {exc}")
    # تلاش فوری با تایم‌اوت کوتاه؛ اگر موفق شد رکورد از صف حذف می‌شود
    if _deliver(record):
        _drop_outbox_record(record["id"])
    return True


def answer_callback(callback_query_id, text=""):
    try:
        api("answerCallbackQuery", {"callback_query_id": callback_query_id, "text": text},
            timeout=SEND_ATTEMPT_TIMEOUT)
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
    if PROXY:
        buttons.append({"text": "⛔ غیرفعال کردن پروکسی", "callback_data": "proxy:off"})
    else:
        buttons.append({"text": "🔄 فعال کردن پروکسی (3067)", "callback_data": "proxy:on"})
    if not buttons:
        buttons.append({"text": "📊 وضعیت صف", "callback_data": "status"})
    safe = []
    for button in buttons:
        safe.append({"text": button["text"], "callback_data": callback_data_safe(button["callback_data"])})
    return {"inline_keyboard": [[button] for button in safe]}


def send_with_dynamic_buttons(text, buttons_fn=dynamic_buttons):
    send(text, reply_markup=buttons_fn())


def outbox_health_check(count):
    """هشدار جداگانه وقتی صف ارسال بیش از آستانه رکورد معوق دارد (یک‌بار، نه هر سیکل)."""
    global _outbox_warned
    if count > OUTBOX_WARN_THRESHOLD and not _outbox_warned:
        _outbox_warned = True
        enqueue_outbox(
            f"⚠️ هشدار صف ارسال تلگرام\n"
            f"• {count} رکورد معوق در صف (آستانه: {OUTBOX_WARN_THRESHOLD})\n"
            f"• احتمالاً مسیر تلگرام قطع است؛ رکوردها امن‌اند و با backoff به‌ترتیب تحویل می‌شوند."
        )
        log(f"outbox health: warned ({count} pending)")
    elif count <= OUTBOX_WARN_THRESHOLD and _outbox_warned:
        _outbox_warned = False
        log(f"outbox health: recovered ({count} pending)")


@_locked(_SEND_LOCK)
def send_pending():
    """تحویل رکوردهای outbox با تلاش کوتاه؛ ناموفق‌ها حفظ می‌شوند (backoff در حلقهٔ اصلی)."""
    try:
        with open(OUTBOX_FILE, encoding="utf-8") as handle:
            records = [json.loads(line) for line in handle if line.strip()]
    except FileNotFoundError:
        return
    except (OSError, json.JSONDecodeError) as exc:
        log(f"outbox read failed: {exc}")
        return
    # اولویت: پاسخ‌های کلیک/دستور (high) قبل از گزارش‌های عادی؛ در هر گروه به‌ترتیب زمان.
    records.sort(key=lambda r: (0 if r.get("priority") == "high" else 1, r.get("created_at", 0)))
    remaining = []
    for record in records:
        if not _deliver(record):
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
    # بعد از نهایی‌شدن فایل — تا هشدار توسط بازنویسی همین سیکل پاک نشود
    outbox_health_check(len(remaining))


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
        send("دستورات:\n/help\n/status\n/health\n/queue\n/auto on|off\n/approve TASK-ID\n/reject TASK-ID دلیل\n/done TASK-ID گزارش\n/report TASK-ID گزارش")
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
        mode = "webhook" if resolve_transport() == "webhook" else "long-poll"
        proxy_state = f"پروکسی: {PROXY}" if PROXY else "پروکسی: غیرفعال (مستقیم)"
        transport_line = f"نحوهٔ دریافت: {mode}" + (f" → {WEBHOOK_URL}" if mode == "webhook" else " (getUpdates)")
        health = "⚠️ ناپایدار" if _health_degraded else "✅ عادی"
        outbox_note = ""
        try:
            with open(OUTBOX_FILE, encoding="utf-8") as handle:
                pending = sum(1 for _ in handle)
            if pending:
                outbox_note = f"\nصف ارسال: {pending} رکورد معوق" + (" ⚠️" if pending > OUTBOX_WARN_THRESHOLD else "")
        except OSError:
            pass
        err_note = f"\nآخرین خطا: {_last_error[:90]}" if _last_error else ""
        uptime = int(time.time() - _health_start_ts)
        hours, rem = divmod(uptime, 3600)
        send(f"🟢 صف محلی فعال است؛ executor: Freebuff\n"
             f"{transport_line}\n"
             f"{proxy_state}\n"
             f"وضعیت اتصال: {health} ({_consecutive_failures} خطای پشت‌سرهم)\n"
             f"آپ‌تایم: {hours}h {rem // 60}m"
             f"{outbox_note}{err_note}\n{summary}")
        return
    if command == "/health":
        uptime = int(time.time() - _health_start_ts)
        hours, rem = divmod(uptime, 3600)
        minutes = rem // 60
        state = "⚠️ ناپایدار" if _health_degraded else "✅ عادی"
        transport = f"پروکسی {PROXY}" if PROXY else "مستقیم"
        send(
            f"🩺 وضعیت سلامت ربات\n"
            f"• اتصال: {state}\n"
            f"• خطاهای پشت‌سرهم: {_consecutive_failures} (آستانهٔ هشدار: {HEALTH_ALERT_THRESHOLD})\n"
            f"• مسیر: {transport}\n"
            f"• آپ‌تایم: {hours}h {minutes}m\n"
            f"• آستانهٔ هشدار: {HEALTH_ALERT_THRESHOLD} خطای پشت‌سرهم → اطلاع خودکار به همین چت"
        )
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

    if data == "proxy:off":
        set_proxy_config(False)
        answer_callback(cb_id, "پروکسی غیرفعال شد")
        send("⛔ پروکسی غیرفعال شد؛ agent با اتصال مستقیم ری‌استارت می‌شود.", reply_markup=dynamic_buttons())
        log("proxy disabled by button; restarting")
        restart_agent("proxy disabled")
        return
    if data == "proxy:on":
        set_proxy_config(True)
        answer_callback(cb_id, "پروکسی فعال شد")
        send("✅ پروکسی فعال شد (http://127.0.0.1:3067)؛ agent با اتصال از طریق پروکسی ری‌استارت می‌شود.", reply_markup=dynamic_buttons())
        log("proxy enabled by button; restarting")
        restart_agent("proxy enabled")
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
    global _consecutive_failures, _last_offset, _last_error, _last_error_ts, _last_success_ts
    try:
        updates = api(
            "getUpdates",
            {"timeout": POLL_TIMEOUT, "offset": offset, "limit": 20, "allowed_updates": '["message", "callback_query"]'},
            timeout=REQUEST_TIMEOUT,
        )
        _consecutive_failures = 0  # موفقیت → reset backoff
        _last_success_ts = time.time()
        health_check()
        for update in updates:
            process_update(update)
            offset = max(offset, update["update_id"] + 1)
            _last_offset = offset
        return offset
    except urllib.error.HTTPError as exc:
        if exc.code == 409:
            delay = max(_backoff_delay(), 20)
            log(f"Telegram 409: another consumer is polling; retrying in {delay:.0f}s")
            time.sleep(delay)
            health_check()
        elif exc.code == 429:
            retry_after = 10
            try:
                header = exc.headers.get("Retry-After") if exc.headers else None
                if header:
                    retry_after = min(60, int(header))
            except (ValueError, TypeError):
                pass
            delay = max(_backoff_delay(), retry_after)
            log(f"Telegram 429: rate limited; retrying in {delay:.0f}s")
            time.sleep(delay)
            health_check()
        else:
            delay = _backoff_delay()
            log(f"Telegram HTTP error: {exc}; retrying in {delay:.0f}s")
            time.sleep(delay)
            health_check()
    except (urllib.error.URLError, TimeoutError, OSError) as exc:
        delay = _backoff_delay()
        _last_error = str(exc)[:200]
        _last_error_ts = time.time()
        log(f"Telegram network error: {exc}; retrying in {delay:.0f}s")
        time.sleep(delay)
        health_check()
    except Exception as exc:
        delay = _backoff_delay()
        _last_error = str(exc)[:200]
        _last_error_ts = time.time()
        log(f"Telegram poll error: {exc}; retrying in {delay:.0f}s")
        time.sleep(delay)
        health_check()
    return offset


def _config_restart_needed():
    """هر تغییری که نیاز به ری‌استارت دارد: پروکسی، ترنسپورت یا URL وب‌هوک."""
    return _config_proxy_changed() or _config_webhook_changed()


def ensure_webhook_secret():
    """اگر secret وب‌هوک تنظیم نشده، یک مقدار تصادفی بساز و در config ذخیره کن
    تا دریافت‌ها فقط با آن token پذیرفته شوند و بعد از ری‌استارت هم ثابت بماند."""
    global WEBHOOK_SECRET
    if WEBHOOK_SECRET:
        return
    new_secret = "tz-" + uuid.uuid4().hex[:32]
    try:
        with open(CONFIG_FILE, encoding="utf-8") as handle:
            lines = handle.read().splitlines()
    except OSError:
        lines = []
    out, found = [], False
    for line in lines:
        if line.strip().startswith(WEBHOOK_SECRET_ENV + "="):
            out.append(f"{WEBHOOK_SECRET_ENV}={new_secret}")
            found = True
        else:
            out.append(line)
    if not found:
        out.append(f"{WEBHOOK_SECRET_ENV}={new_secret}")
    temp = CONFIG_FILE + ".tmp"
    try:
        with open(temp, "w", encoding="utf-8") as handle:
            handle.write("\n".join(out) + "\n")
        os.replace(temp, CONFIG_FILE)
        WEBHOOK_SECRET = new_secret
        log(f"generated webhook secret and saved to {CONFIG_FILE}")
    except OSError as exc:
        WEBHOOK_SECRET = new_secret
        log(f"webhook secret save failed (in-memory only): {exc}")


def _run_webhook_mode():
    """حالت وب‌هوک: آپدیت‌ها فوری و بدون getUpdates/409 می‌رسند؛ ارسال‌ها همان
    مسیر outbox با پروکسی می‌ماند. گیرندهٔ محلی + ثبت webhook نزد تلگرام."""
    global _webhook_registered
    ensure_webhook_secret()
    try:
        ensure_webhook_registered()
    except Exception as exc:
        _webhook_registered = False
        log(f"webhook setup failed (will retry): {exc}")
        # alert once so the failure is visible, then keep the daemon alive
        enqueue_outbox("⚠️ ثبت webhook تلگرام ناموفق بود؛ agent تلاش می‌کند.\n"
                       f"• URL: {WEBHOOK_URL}\n"
                       f"• خطا: {str(exc)[:200]}")

    try:
        server = start_webhook_server()
    except OSError as exc:
        log(f"webhook receiver bind failed on {WEBHOOK_LISTEN}: {exc}")
        send("⚠️ گیرندهٔ وب‌هوک نمی‌تواند روی پورت بایند شود؛ agent خارج می‌شود.\n"
             f"• {WEBHOOK_LISTEN}\n• خطا: {str(exc)[:200]}")
        return 3

    thread = threading.Thread(target=server.serve_forever, daemon=True, name="webhook-receiver")
    thread.start()
    log(f"webhook receiver listening on {WEBHOOK_LISTEN} -> {WEBHOOK_URL}")
    update_status()
    try:
        while True:
            if os.path.exists(STOP_FILE):
                os.remove(STOP_FILE)
                log("stop file seen; exiting")
            if _config_restart_needed():
                restart_agent("config changed (proxy/transport/webhook)")
                return 0
            # سلامت: اگر تلگرام webhook را گم کند (مثلاً دستی delete شده) دوباره ثبت کن
            try:
                info = webhook_info()
                if str((info or {}).get("url") or "") != WEBHOOK_URL:
                    register_webhook()
                    log("webhook re-registered after health check")
            except Exception as exc:
                log(f"webhook health check failed: {exc}")
            send_pending()
            update_status()
            time.sleep(30)
    except KeyboardInterrupt:
        return 0
    finally:
        server.shutdown()
        release_lock()


def _run_poll_mode():
    """حالت long-poll (پیش‌فرض/fallback): از طریق پروکسی؛ ابتدا webhook کهنه را
    حذف می‌کند تا getUpdates با 409 مواجه نشود."""
    _ensure_no_stale_webhook()
    offset = read_offset()
    update_status()
    try:
        while True:
            if os.path.exists(STOP_FILE):
                os.remove(STOP_FILE)
                log("stop file seen; exiting")
            # ری‌استارت خودکار بعد از تغییر config — مقایسهٔ فایل با حافظه:
            # بعد از ری‌استارت برابر می‌شوند (بدون حلقهٔ بی‌پایان).
            if _config_restart_needed():
                restart_agent("config changed (proxy/transport/webhook)")
                return 0
            send_pending()
            offset = poll(offset)
            write_offset(offset)
            send_pending()
            update_status()
    except KeyboardInterrupt:
        return 0
    finally:
        release_lock()


def main():
    # Retry short so a restart child survives the parent's lock-release race.
    # Watchdog تکرارشوندهٔ Task Scheduler (هر چند دقیقه) هم از همین مسیر می‌آید؛
    # وقتی نمونهٔ اصلی زنده است نباید ۳۰ ثانیه لاگ خراب کند — فقط یک خط و خروج.
    locked = False
    for _attempt in range(1, 16):
        if acquire_lock():
            locked = True
            break
        if _attempt == 1:
            log("agent already running elsewhere; watchdog exiting silently")
        time.sleep(2)
    if not locked:
        return 2
    log(f"local Telegram queue started; root={ROOT}; no Claude executor")
    mode = resolve_transport()
    log(f"telegram transport mode: {mode}")
    log(f"telegram outbound: {'proxy ' + PROXY if PROXY else 'direct'}")
    if mode == "webhook":
        log(f"telegram inbound: webhook {WEBHOOK_URL} via local {WEBHOOK_LISTEN}")
        return _run_webhook_mode()
    log(f"telegram resilience: long-poll={POLL_TIMEOUT}s, backoff={BACKOFF_BASE:.0f}-{BACKOFF_CAP:.0f}s")
    return _run_poll_mode()


if __name__ == "__main__":
    raise SystemExit(main())
