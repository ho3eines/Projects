#!/usr/bin/env bash
# refresh-test-report.sh — updates the auto-gate section of docs/testing-report.md
# from the latest `dotnet test` summary line (passed as $1).
#
# The report's hand-written body ("گزارش تست نرم‌افزار ترازین.md") can drift from
# reality; this step makes the QA evidence reflect the actual last automated gate
# run so a stale/contradicting report is caught by CI, not by a human.
#
# Replaces the block between the markers
#     <!-- AUTO-GATE:START --> ... <!-- AUTO-GATE:END -->
# in-place. If the markers are absent, appends a fresh section at the end.
# Exit 0 = updated (or report already absent → 1), 1 = error/missing input.
#
# Usage: bash tools/refresh-test-report.sh "<dotnet test summary line>"
set -uo pipefail

REPORT="docs/testing-report.md"
TEST_LINE="${1:-}"

if [ -z "$TEST_LINE" ]; then
  echo "❌ no test summary provided — pass the dotnet test summary line as \$1"
  exit 1
fi
if [ ! -f "$REPORT" ]; then
  echo "❌ report not found: $REPORT"
  exit 1
fi

# Parse dotted numbers out of a line like:
#   Passed!  - Failed:     0, Passed:    44, Skipped:     0, Total:    44, ...
num() { printf '%s' "$TEST_LINE" | sed -nE "s/.*$1:[[:space:]]+([0-9]+).*/\1/p" | head -1; }
PASSED="$(num Passed)"; FAILED="$(num Failed)"; TOTAL="$(num Total)"
[ -z "$PASSED" ] && PASSED=0
[ -z "$FAILED" ] && FAILED=0
[ -z "$TOTAL" ]  && TOTAL=0

if [ "$FAILED" -gt 0 ]; then STATUS="❌ ناقص"
elif [ -n "$(printf '%s' "$TEST_LINE" | grep -o "Skipped!")" ]; then STATUS="⏭️ skip (بدون SQL Server)"
else STATUS="✅ پاس"; fi

NOW="$(date '+%Y-%m-%d %H:%M')"

CONTENT="#### نتایج آخرین اجرای gate خودکار — ${NOW}
- وضعیت: **${STATUS}**
- مجموع تست‌ها: **${TOTAL}**
- موفقی: **${PASSED}** | ناموفق: **${FAILED}**
- خلاصهٔ dotnet test: \`${TEST_LINE}\`
- این بخش به‌صورت خودکار توسط \`tools/run-checks.sh\` (step ۶) از خروجی واقعی بازنویسی می‌شود؛ عدد‌های بخش‌های ۵.۴–۵.۶ دستی‌اند الهام از همین اجرا."
echo "$CONTENT"

# Ensure the marker block exists
if ! grep -q "<!-- AUTO-GATE:START -->" "$REPORT"; then
  printf '\n---\n\n## ۱۰. نتایج آخرین اجرای gate خودکار\n\n<!-- AUTO-GATE:START -->\n<!-- AUTO-GATE:END -->\n' >> "$REPORT"
fi

# Replace everything between the markers with fresh CONTENT.
awk -v c="$CONTENT" '
  /<!-- AUTO-GATE:START -->/{p=1; print; print c; print ""; next}
  /<!-- AUTO-GATE:END -->/{p=0; print; next}
  !p{print}
' "$REPORT" > "$REPORT.tmp" && mv "$REPORT.tmp" "$REPORT"

echo "✅ report updated: $REPORT"
exit 0