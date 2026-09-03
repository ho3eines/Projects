#!/usr/bin/env bash
# =============================================================
# cloudflared-tunnel.sh — persistent Argo quick tunnel for Tarazin.
#
# Working recipe (carrier poisons Cloudflare edge DNS; see HANDOFF):
#   1. hosts file pins region1/region2.v2.argotunnel.com to real IPs
#   2. all Cloudflare traffic rides the local 3067 HTTP proxy
#   3. transport forced to http2 so the data-plane can use the proxy
#
# Reports each new (ephemeral) trycloudflare URL to Telegram.
# Used by Task Scheduler "Tarazin\CloudflaredTunnel" (ONLOGON).
# =============================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

export HTTPS_PROXY=http://127.0.0.1:3067
export HTTP_PROXY=http://127.0.0.1:3067
export ALL_PROXY=http://127.0.0.1:3067
export TUNNEL_TRANSPORT_PROTOCOL=http2
export NO_PROXY=""

LOG=/tmp/cf-tunnel.log
: > "$LOG"

# if an older tunnel instance is running, stop it first (new URL each run)
pkill -f "cloudflared tunnel --url" 2>/dev/null || true
sleep 1

cloudflared tunnel --url https://localhost:65220 \
  --no-autoupdate --no-tls-verify --edge-ip-version 4 \
  > "$LOG" 2>&1 &
CFPID=$!

URL=""
for _ in $(seq 1 45); do
  URL=$(grep -oE 'https://[a-z0-9-]+\.trycloudflare\.com' "$LOG" | head -1)
  [ -n "$URL" ] && break
  kill -0 "$CFPID" 2>/dev/null || break
  sleep 2
done

if [ -n "$URL" ]; then
  python tools/telegram_send.py --priority high \
    "🌐 تانل ارگو بالا آمد: $URL (تست بعد از ۲۰ ثانیه)"
else
  python tools/telegram_send.py --priority high \
    "⚠️ تانل ارگو بالا نیامد. log: $LOG"
fi

wait "$CFPID"