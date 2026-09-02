#!/usr/bin/env bash
# check-server.sh — بررسی سلامت سرور dev از endpoint اختصاصی /api/health.
#
# خروجی روی صفحه: وضعیت (سالم/پایین)، آپتایم واقعی، نسخهٔ build و زمان build.
# به‌صورت پیش‌فرض نتیجه را از طریق tools/telegram_send.py به تلگرام هم می‌فرستد
# (با --no-telegram فقط روی صفحه).
#
# Exit code: 0 = سالم (status:"ok")، 1 = پایین/بدون پاسخ، 2 = خطای استفاده.
#
# Usage:
#   bash tools/check-server.sh                     # صفحه + تلگرام
#   bash tools/check-server.sh --no-telegram       # فقط صفحه (برای cron/supervisor)
#   bash tools/check-server.sh --url http://localhost:65221/api/health
#   HEALTH_URL="..." bash tools/check-server.sh    # جایگزینی مسیر از طریق env

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

HEALTH_URL="${HEALTH_URL:-https://localhost:65220/api/health}"
SEND_TELEGRAM=1

for arg in "$@"; do
  case "$arg" in
    --no-telegram) SEND_TELEGRAM=0 ;;
    --help|-h)
      grep '^#' "$0" | sed 's/^# \{0,1\}//; /^!/d' | head -25
      exit 0
      ;;
    --url)
      echo "❌ --url requires a value: --url http://host:port/api/health" >&2
      exit 2
      ;;
    --url=*) HEALTH_URL="${arg#--url=}" ;;
    *)
      echo "❌ unknown option: $arg (use --help)" >&2
      exit 2
      ;;
  esac
done

GREEN=$'\033[0;32m'; RED=$'\033[0;31m'; YELLOW=$'\033[0;33m'; NC=$'\033[0m'

# ── گرفتن پاسخ health ──
JSON="$(curl -sk --max-time 6 "$HEALTH_URL" 2>/dev/null)"
CURL_RC=$?

if [ $CURL_RC -ne 0 ] || [ -z "$JSON" ]; then
  echo "${RED}[پایین]${NC} سرور پاسخ نداد (curl exit=$CURL_RC) — $HEALTH_URL"
  if [ "$SEND_TELEGRAM" = "1" ]; then
    PYTHONIOENCODING=utf-8 python tools/telegram_send.py --priority high \
      "⛔ سرور dev پایین است (بدون پاسخ) — $HEALTH_URL" >/dev/null 2>&1
  fi
  exit 1
fi

# ── استخراج فیلدها (python — JSON ایمن با فارسی/اعداد) ──
read -r STATUS UPTIME BUILD_VER BUILD_TIME < <(PYTHONIOENCODING=utf-8 python -c "
import json, sys
try:
    d = json.loads(sys.stdin.read())
except Exception:
    print('invalid invalid invalid invalid')
    sys.exit(0)
s = str(d.get('status', 'unknown'))
u = int(d.get('uptimeSeconds', 0) or 0)
days, rem = divmod(u, 86400)
hours, rem = divmod(rem, 3600)
mins = rem // 60
up = f'{days}d {hours}h {mins}m' if days else (f'{hours}h {mins}m' if hours else f'{mins}m')
print(s, up, d.get('buildVersion', '?'), d.get('buildTime', '?'))
" <<< "$JSON")

summary=""
if [ "$STATUS" = "ok" ]; then
  summary="${GREEN}[سالم]${NC} سرور بالا است — uptime: $UPTIME"
  code=0
else
  summary="${RED}[پایین]${NC} پاسخ نامعتبر: status=\"$STATUS\" — $HEALTH_URL"
  code=1
fi

echo "$summary"
echo "  endpoint : $HEALTH_URL"
echo "  build    : $BUILD_VER"
echo "  build time: $BUILD_TIME"
echo "  datetime : $(date '+%F %T')"

# ── گزارش به تلگرام فقط وقتی سالم است (پایین در بالا گزارش شد) ──
if [ "$SEND_TELEGRAM" = "1" ] && [ "$code" = "0" ]; then
  PYTHONIOENCODING=utf-8 python tools/telegram_send.py \
    "✅ سرور dev سالم — آپتایم $UPTIME
نسخه: $BUILD_VER
زمان build: $BUILD_TIME" >/dev/null 2>&1
fi

exit "$code"