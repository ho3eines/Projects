#!/usr/bin/env bash
# check-stale-build.sh — Pre-restart guard for the "server runs old code" bug.
#
# The dev server is usually started with `dotnet run --no-build`, which loads the
# DLLs already copied into Tarazin.Web/bin. If Tarazin.Ui was rebuilt (e.g. via
# `dotnet test` or `dotnet build Tarazin.Ui`) but Tarazin.Web was NOT rebuilt, the
# running server keeps serving the OLD Ui code even though the source is fixed.
#
# Run this BEFORE restarting the dev server. Exit code:
#   0 = fresh (safe to restart)
#   1 = stale build detected (rebuild first)
#   2 = build output missing
#
# Usage: bash tools/check-stale-build.sh   (from project root)

set -uo pipefail

UI_BIN="Tarazin.Ui/bin/Debug/net8.0"
WEB_BIN="Tarazin.Web/bin/Debug/net8.0"
STALE=0

if [ ! -d "$UI_BIN" ] || [ ! -d "$WEB_BIN" ]; then
  echo "ERROR: build output missing. Run 'dotnet build Tarazin.Web/Tarazin.Web.csproj' first."
  exit 2
fi

echo "=== Stale-Build Guard ==="

# 1) Every Ui-built DLL copied into Web/bin must not be older than its Ui/bin original.
for f in "$UI_BIN"/*.dll; do
  [ -e "$f" ] || continue
  name=$(basename "$f")
  web="$WEB_BIN/$name"
  [ -e "$web" ] || continue
  ui_t=$(stat -c %Y "$f")
  web_t=$(stat -c %Y "$web")
  if [ "$web_t" -lt "$ui_t" ]; then
    echo "❌ STALE: $name — Tarazin.Web/bin copy is OLDER than Tarazin.Ui/bin."
    echo "   Ui/bin:  $(date -d @"$ui_t" '+%Y-%m-%d %H:%M:%S')"
    echo "   Web/bin: $(date -d @"$web_t" '+%Y-%m-%d %H:%M:%S')"
    echo "   Fix: stop the dev server, then: dotnet build Tarazin.Web/Tarazin.Web.csproj"
    STALE=1
  fi
done

# 2) Tarazin.Ui itself must not be older than its newest source file
#    (catches the case where Ui was never rebuilt after a source edit).
NEWEST_SRC=$(find Tarazin.Ui \( -name '*.cs' -o -name '*.razor' \) -printf '%T@\n' 2>/dev/null | sort -n | tail -1 | cut -d. -f1)
if [ -n "$NEWEST_SRC" ] && [ -f "$UI_BIN/Tarazin.Ui.dll" ]; then
  ui_t=$(stat -c %Y "$UI_BIN/Tarazin.Ui.dll")
  if [ "$ui_t" -lt "$NEWEST_SRC" ]; then
    echo "❌ STALE: Tarazin.Ui.dll is OLDER than the newest source file."
    echo "   Fix: dotnet build Tarazin.Ui/Tarazin.Ui.csproj  (then rebuild Tarazin.Web)"
    STALE=1
  fi
fi

echo ""
if [ "$STALE" -eq 0 ]; then
  echo "✅ Fresh: Tarazin.Web/bin matches Tarazin.Ui/bin — safe to restart the server."
  exit 0
fi
echo "FAILED: stale build detected — do NOT restart the server until rebuilt."
exit 1
