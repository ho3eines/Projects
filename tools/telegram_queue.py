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
import subprocess
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
RESEED_LOG = os.path.join(STATE_DIR, "reseed.log")


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
        print(
            "usage: list | next | has-notify | claim-next [--include-awaiting] | claim TASK-ID | complete TASK-ID SUMMARY | fail TASK-ID REASON",
            file=sys.stderr,
        )
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
        save(tasks)
        print(json.dumps(task, ensure_ascii=False))
        return 0
    elif command == "complete":
        task.update({"status": "completed", "result": " ".join(args[2:]), "completed_at": now(), "updated_at": now()})
        save(tasks)
        print(json.dumps(task, ensure_ascii=False))
        # ── قانون دائمی: بعد از هر تسک، دادهٔ نمونه تازه شود ──────────
        if "--no-reseed" not in args:
            run_auto_reseed(task.get("id", ""))
        # ── تست خودکار انبار بعد از هر تسک (قانون دائمی) ─────────────
        if "--no-tests" not in args:
            run_auto_inventory_tests(task.get("id", ""))
        return 0
    else:
        task.update({"status": "failed", "result": " ".join(args[2:]) or "بدون دلیل", "updated_at": now()})
        save(tasks)
        print(json.dumps(task, ensure_ascii=False))
        return 0


TEST_LOG = os.path.join(STATE_DIR, "tests.log")

INVENTORY_TEST_CLASSES = [
    "InventoryPhase5Tests", "InventoryMovementInsertTests", "InventoryAdjustmentTests",
    "LotSerialTests", "ItemPickerDbTests", "SeedCleanupTests", "GoldItemLinkTests",
]


def run_auto_inventory_tests(task_id):
    """Run the inventory test suite after a completed task (non-fatal).

    Each class runs in its own `dotnet test` invocation (sequential) because
    the tests share one live SQL Server and xUnit's default parallelism makes
    combined runs time out on DB contention (known project issue — all classes
    pass when isolated). Outcome is logged to ~/.telegram-bridge/agent/
    tests.log; on FAILURE an alert is queued to Telegram (priority high). The
    task itself is never failed.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    csproj = os.path.join(root, "Tarazin.Tests", "Tarazin.Tests.csproj")
    if not os.path.exists(csproj):
        return
    try:
        lines = []
        ok = True
        for cls in INVENTORY_TEST_CLASSES:
            proc = subprocess.run(
                ["dotnet", "test", csproj, "-c", "Debug", "--nologo", "--no-restore", "--filter", f"FullyQualifiedName~{cls}"],
                cwd=root,
                capture_output=True,
                text=True,
                encoding="utf-8",
                errors="replace",
                timeout=900,
            )
            passed = "Passed!" in (proc.stdout or "") and proc.returncode == 0
            retried = False
            if not passed:  # shared live DB → external contention can time out a class once; retry once
                import time
                time.sleep(5)
                proc = subprocess.run(
                    ["dotnet", "test", csproj, "-c", "Debug", "--nologo", "--no-restore", "--filter", f"FullyQualifiedName~{cls}"],
                    cwd=root,
                    capture_output=True,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    timeout=900,
                )
                retried = True
                passed = "Passed!" in (proc.stdout or "") and proc.returncode == 0
            ok = ok and passed
            summary = [l for l in (proc.stdout or "").splitlines() if "Passed!" in l or "Failed!" in l]
            lines.append(f"{cls}: {'✅' if passed else '❌ rc=' + str(proc.returncode)} {'(retry)' if retried and passed else ''} {' | '.join(summary)}")
            if not passed:
                lines.append((proc.stdout or "").strip().splitlines()[-3:] and " ...".join([l.strip() for l in (proc.stdout or "").strip().splitlines()[-3:]]))
        tail = lines[-8:]
        with open(TEST_LOG, "a", encoding="utf-8") as handle:
            handle.write(f"[{now()}] task={task_id} ok={ok}\n")
            handle.write("\n".join(tail) + "\n")
        print(f"auto-tests: {'✅' if ok else '⚠️ see tests.log'}", file=sys.stderr)
        if not ok:
            _notify_telegram(
                "⚠️ تست‌های خودکار انبار بعد از تسک " + task_id + " رد شدند\n"
                + "\n".join(tail) + "\n"
                "جزئیات کامل: ~/.telegram-bridge/agent/tests.log"
            )
    except Exception as exc:
        try:
            with open(TEST_LOG, "a", encoding="utf-8") as handle:
                handle.write(f"[{now()}] task={task_id} ERROR {exc}\n")
        except Exception:
            pass
        print(f"auto-tests skipped: {exc}", file=sys.stderr)
        _notify_telegram(
            "⚠️ اجرای تست‌های خودکار انبار بعد از تسک " + task_id + " با خطا مواجه شد:\n"
            + str(exc) + "\n"
            "جزئیات کامل: ~/.telegram-bridge/agent/tests.log"
        )


def _notify_telegram(text):
    """Queue a high-priority alert to Telegram via the same outbox path as the
    agent (tools/telegram_send.py). Best-effort — never raises."""
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    sender = os.path.join(root, "tools", "telegram_send.py")
    if not os.path.exists(sender):
        return
    try:
        subprocess.run(
            [sys.executable, sender, "--priority", "high", "--text", text],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=60,
        )
    except Exception:
        pass


def run_auto_reseed(task_id):
    """Run seed-demo-data.sh --reseed after a completed task (non-fatal).

    Keeps demo data fresh after every completed Telegram task. Failure never
    fails the task itself — the outcome is logged to ~/.telegram-bridge/agent/
    reseed.log and, when reseed FAILS, an alert is queued to Telegram so the
    error is seen and fixed.
    """
    root = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))  # repo root
    script = os.path.join(root, "tools", "seed-demo-data.sh")
    if not os.path.exists(script):
        return
    try:
        proc = subprocess.run(
            ["bash", "tools/seed-demo-data.sh", "--reseed"],
            cwd=root,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=240,
        )
        tail = (proc.stdout or "").strip().splitlines()[-4:]
        ok = proc.returncode == 0 and "Demo data seeded" in (proc.stdout or "")
        with open(RESEED_LOG, "a", encoding="utf-8") as handle:
            handle.write(f"[{now()}] task={task_id} ok={ok} rc={proc.returncode}\n")
            handle.write("\n".join(tail) + "\n")
        print(f"auto-reseed: {'✅' if ok else '⚠️ see reseed.log'} (rc={proc.returncode})", file=sys.stderr)
        if not ok:
            _notify_telegram(
                "⚠️ reseed خودکار بعد از تسک " + task_id + " شکست خورد\n"
                "rc=" + str(proc.returncode) + "\n"
                + "\n".join(tail) + "\n"
                "جزئیات کامل: ~/.telegram-bridge/agent/reseed.log"
            )
    except Exception as exc:  # never break the completed task
        try:
            with open(RESEED_LOG, "a", encoding="utf-8") as handle:
                handle.write(f"[{now()}] task={task_id} ERROR {exc}\n")
        except Exception:
            pass
        print(f"auto-reseed skipped: {exc}", file=sys.stderr)
        _notify_telegram(
            "⚠️ reseed خودکار بعد از تسک " + task_id + " با خطا مواجه شد:\n"
            + str(exc) + "\n"
            "جزئیات کامل: ~/.telegram-bridge/agent/reseed.log"
        )


if __name__ == "__main__":
    raise SystemExit(main(sys.argv[1:]))
