#!/usr/bin/env bash
# Start the Tarazin dev server in the background, log to a file.
#
# Runs the stale-build guard (tools/check-stale-build.sh) FIRST so the
# "--no-build" server never serves old Tarazin.Ui code. If the guard reports
# stale, this script refuses to start and tells you to rebuild first.
#
# Skip the guard (advanced/emergency) with:  bash tools/start-dev-server.sh --force
set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FORCE=0
if [ "${1:-}" = "--force" ]; then
  FORCE=1
fi

if [ "$FORCE" -eq 0 ] && ! bash tools/check-stale-build.sh; then
  echo ""
  echo "❌  شروع سرویس لغو شد — گارد «سرور با کد قدیمی» خطا داد."
  echo "   ابتدا کپی درست را بساز:"
  echo "     dotnet build Tarazin.Web/Tarazin.Web.csproj"
  echo "   سپس دوباره اجرا کن:          bash tools/start-dev-server.sh"
  echo "   (برای دور زدن گارد:         bash tools/start-dev-server.sh --force)"
  exit 1
fi

nohup dotnet run --project Tarazin.Web --no-build > /tmp/tarazin-dev.log 2>&1 &
echo "PID $!"
sleep 1
echo "started"