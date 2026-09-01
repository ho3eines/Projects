#!/usr/bin/env python3
"""Idempotent starter for tools/telegram_agent.py (Task Scheduler entry point).

Safe to run on every logon and on a periodic schedule: if the agent daemon is
already alive (bridge.lock + live PID), it exits immediately without touching
it. Otherwise it starts one detached instance and confirms the lock was taken.

Register via Task Scheduler (see tools/telegram_agent_task.xml):
    schtasks /Create /TN "Tarazin\\TelegramAgent" /XML tools\\telegram_agent_task.xml /F
"""

import os
import subprocess
import sys
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
AGENT = os.path.join(ROOT, "tools", "telegram_agent.py")
LOCK_FILE = os.path.join(os.path.expanduser("~"), ".telegram-bridge", "bridge.lock")
STDOUT_LOG = os.path.join(ROOT, "tools", "agent_stdout.log")

DETACHED_PROCESS = 0x00000008
CREATE_NEW_PROCESS_GROUP = 0x00000200
CREATE_NO_WINDOW = 0x08000000
CREATE_BREAKAWAY_FROM_JOB = 0x01000000


def pid_alive(pid):
    """Robust check: os.kill(pid, 0) on Windows raises OSError 22 for live
    processes spawned through launcher shims; OpenProcess with
    PROCESS_QUERY_LIMITED_INFORMATION works for same-user processes and only
    returns error 87 for genuinely dead PIDs."""
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
    except (OSError, SystemError):
        return False


def agent_alive():
    """True if the lock file exists and points to a live process."""
    try:
        with open(LOCK_FILE, encoding="ascii") as handle:
            pid = int(handle.read().strip())
    except (OSError, ValueError):
        return False
    return pid > 0 and pid_alive(pid)


def main():
    if agent_alive():
        print("telegram agent already running; nothing to do.")
        return 0

    # Stale lock (dead PID) — remove so the new instance can claim it.
    try:
        os.remove(LOCK_FILE)
    except OSError:
        pass

    interpreter = sys.executable
    flags = DETACHED_PROCESS | CREATE_NEW_PROCESS_GROUP | CREATE_NO_WINDOW | CREATE_BREAKAWAY_FROM_JOB
    with open(STDOUT_LOG, "a", encoding="utf-8", errors="replace") as out:
        subprocess.Popen(
            [interpreter, AGENT],
            cwd=ROOT,
            stdin=subprocess.DEVNULL,
            stdout=out,
            stderr=subprocess.STDOUT,
            close_fds=True,
            creationflags=flags,
        )

    # Give the daemon a moment to acquire the lock, then confirm.
    for _ in range(10):
        time.sleep(0.5)
        if agent_alive():
            print("telegram agent started.")
            return 0
    print("telegram agent failed to start (lock not acquired).", file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
