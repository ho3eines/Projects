#!/usr/bin/env bash
# Start the Tarazin dev server with auto-restart via `dotnet watch`.
#
# `dotnet watch` rebuilds + restarts on `.cs` changes and hot-reloads `.razor`
# pages instantly — new pages appear WITHOUT any manual restart. A small
# supervisor (tools/dev-server-watch.sh) crash-heals `dotnet watch`.
#
# This launcher:
#   1. kills any stale supervisor instances of dev-server-watch.sh,
#   2. kills any running `dotnet watch` / old `--no-build` server,
#   3. runs the stale-build guard and builds if needed,
#   4. starts the supervisor in the background.
#
# Usage: bash tools/start-dev-server.sh
# Stop:  bash tools/dev-server-watch.sh --stop
# Logs:  /tmp/tarazin-watch.log (server), /tmp/dev-server-watch.log (supervisor)
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

log() { echo "[$(date '+%H:%M:%S')] $*"; }

# ── idempotent: اگر سرور سالم و supervisor زنده است، کاری نکن ──
# (برای اجرای دوره‌ایِ Task Scheduler هر ۵ دقیقه — فقط وقتی واقعاً پایین است ری‌هیل می‌کند)
if [ "${1:-}" != "--force" ] \
   && curl -sk --max-time 3 https://localhost:65220/api/health 2>/dev/null | grep -q '"status":"ok"'; then
  # supervisor زنده؟ (تطبیق نام اسکریپت در command line فرایندهای bash — بدون anchor انتهایی
  # چون خروجی wmic ستون PID را هم دارد؛ فرایندهای خودِ دستور (wmic/grep) با name='bash.exe' حذف می‌شوند)
  if wmic process where "name='bash.exe'" get ProcessId,CommandLine 2>/dev/null \
      | grep "dev-server-watch.sh" >/dev/null 2>&1; then
    log "dev server already healthy — nothing to do"
    exit 0
  fi
fi

# ۱) نمونه‌های قبلی supervisor (bash) — command line دقیقاً نام اسکریپت است.
log "cleaning stale supervisors..."
for p in $(wmic process where "name='bash.exe'" get ProcessId,CommandLine 2>/dev/null \
    | grep "dev-server-watch.sh" | grep -v "wmic process where" | grep -oE "[0-9]+ *$" | tr -d ' '); do
  CL="$(wmic process where "ProcessId=$p" get CommandLine 2>/dev/null | tr -d '\r' | grep -E "dev-server-watch\.sh *$" | head -1)"
  if [ -n "$CL" ]; then
    taskkill //PID "$p" //F //T >/dev/null 2>&1
    log "  killed stale supervisor pid $p"
  fi
done

# ۲) هر dotnet watch / سرور قدیمی
log "stopping previous servers..."
for p in $(wmic process where "name='dotnet.exe'" get ProcessId,CommandLine 2>/dev/null \
    | grep -iE "watch.*Tarazin\.Web|Tarazin\.Web" | grep -v "wmic process where" | grep -oE "[0-9]+ *$" | tr -d ' '); do
  taskkill //PID "$p" //F //T >/dev/null 2>&1
done
sleep 2

# ۳) گارد build کهنه: اگر خروجی کهنه بود اول build کن.
if ! bash tools/check-stale-build.sh >/dev/null 2>&1; then
  log "stale build detected — building Tarazin.Web first..."
  dotnet build Tarazin.Web/Tarazin.Web.csproj -c Debug --nologo -v q || true
fi

# ۴) supervisor را در پس‌زمینه اجرا کن
rm -f /tmp/dev-server-watch.pid
nohup bash tools/dev-server-watch.sh > /dev/null 2>&1 &
sleep 2
log "supervisor started — dev server comes up in ~30-60s (https://localhost:65220)"
log "logs: tail -f /tmp/dev-server-watch.log | /tmp/tarazin-watch.log"
