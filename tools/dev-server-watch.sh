#!/usr/bin/env bash
# dev-server-watch.sh — سرپرستِ سرور dev با `dotnet watch` (پس از راه‌اندازی توسط
# tools/start-dev-server.sh اجرا می‌شود).
#
# `dotnet watch` خودش سورس را رصد می‌کند: برای `.razor` هات‌ریلود (بدون ریاستارت) و
# برای `.cs` توقف → build → ریاستارت. پس صفحه‌های جدید بدون دخالت دستی دیده می‌شوند.
# (در ویندوز build در حالی که سرور بالاست FAIL می‌شود چون فرایند در حال اجرا
# exe/dll را قفل می‌کند — برای همین watchdog «رصد خروجی build» جواب نمی‌دهد.)
#
# این اسکریپت فقط نقش سرپرست دارد:
#   - `dotnet watch` را اجرا می‌کند و اگر بمیرد دوباره بالا می‌آورد (crash-heal).
#   - تک‌نمونه: اگر نمونهٔ قبلی زنده باشد (pidfile) خارج می‌شود.
#   - پاک‌سازی نمونه‌های قدیمی و dotnet watch قبلی را tools/start-dev-server.sh
#     انجام می‌دهد (چون command line این اسکریپت برای تشخیص خودش مناسب نیست).
#
# اجرا:   nohup bash tools/dev-server-watch.sh > /dev/null 2>&1 &
# توقف:   bash tools/dev-server-watch.sh --stop   (فقط watch را می‌کشد)

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LOG=/tmp/tarazin-watch.log
WATCH_LOG=/tmp/dev-server-watch.log
PID_FILE=/tmp/dev-server-watch.pid
CHECK_EVERY=10
HEALTH_URL="https://localhost:65220/api/health"

log() { echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$WATCH_LOG"; }

# سالم واقعی = endpoint /api/health جواب «status:ok» بدهد (نه فقط هر ۲۰۰).
is_healthy() {
  curl -sk --max-time 4 "$HEALTH_URL" 2>/dev/null | grep -q '"status":"ok"'
}

# زمان build فعلی از DLL خروجی (برای لاگ «با کدام build ریاستارت شد»).
build_time() {
  stat -c "%y" "Tarazin.Web/bin/Debug/net8.0/Tarazin.Web.dll" 2>/dev/null | cut -d. -f1
}

# PID واقعی فرایند dotnet watch (command line شامل "watch run" و Tarazin.Web).
watch_pids() {
  wmic process where "name='dotnet.exe'" get ProcessId,CommandLine 2>/dev/null \
    | grep -iE "watch.*Tarazin\.Web|Tarazin\.Web.*watch" | grep -oE "[0-9]+ *$" | tr -d ' '
}

kill_watch() {
  local p
  for p in $(watch_pids); do
    taskkill //PID "$p" //F //T >/dev/null 2>&1
  done
  local i
  for i in $(seq 1 12); do
    if [ -z "$(watch_pids)" ] \
       && ! netstat -ano 2>/dev/null | grep LISTENING | grep -qE ":65220|:65221"; then
      return 0
    fi
    sleep 1
  done
}

start_watch() {
  nohup dotnet watch run --project Tarazin.Web --launch-profile Tarazin.Web > "$LOG" 2>&1 &
  log "dotnet watch started (build: $(build_time))"
}

# ── --stop ──
if [ "${1:-}" = "--stop" ]; then
  kill_watch
  exit 0
fi

# تک‌نمونه: اگر نمونهٔ قبلی زنده است، خارج شو (PID ثبت‌شده MSYS است؛ kill -0 آن را می‌فهمد).
if [ -f "$PID_FILE" ]; then
  old="$(cat "$PID_FILE" 2>/dev/null || echo "")"
  if [ -n "$old" ] && [ "$old" != "$$" ] && kill -0 "$old" 2>/dev/null; then
    log "another supervisor alive (pid $old) — exiting"
    exit 0
  fi
fi
echo "$$" > "$PID_FILE"

kill_watch
start_watch

while true; do
  if ! is_healthy && [ -z "$(watch_pids)" ]; then
    log "watch process gone — restarting"
    kill_watch
    start_watch
  fi
  sleep "$CHECK_EVERY"
done
