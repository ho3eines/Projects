#!/usr/bin/env bash
# run-checks.sh — One-shot validation gate for the whole project.
#
# Runs, in order, every check a coder/CI must pass before a build, PR, or
# dev-server restart:
#   1. Cross-schema scan      (tools/cross-schema-scan.sh)
#   2. Print-template guards  (PrintTemplateResolutionTests + PrintTemplateSqlGuardTests)
#   3. Full test suite        (PDF regression, close-year, everything else)
#   4. Web build              (dotnet build Tarazin.Web)  — refreshes Web/bin copy
#   5. Stale-build guard      (tools/check-stale-build.sh)
#   6. Test-report refresh    (tools/refresh-test-report.sh) — regenerates the
#                             auto-gate section of docs/testing-report.md from the
#                             real step-3 output, so the QA evidence never drifts.
#
# Exit code: 0 = all green, 1 = a check failed (the failing step is named).
#
# NOTE on ordering: the Web build (4) MUST come after the test/build that refresh
# Tarazin.Ui/bin and before the stale guard (5), so that the "server runs old code"
# bug is caught and the guard reports a clean 0.
#
# NOTE on SQL: the print-template and close-year guards need a live SQL Server;
# without one they Skip (not fail). CI spins up SQL Server as a service of the
# same checks job (with TARAZIN_TEST_CONN set), so here they actually run inside
# the same gate — and a later conditional step re-validates the guards against
# a fresh schema built from the _Ensure sources.
#
# Usage: bash tools/run-checks.sh            (from project root)

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

FAIL=0

step() { echo; echo "══════ $1 ══════"; }
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAIL=1; }

# ── 1. Cross-schema scan ──────────────────────────────────────────────
step "۱) Cross-Schema Scan"
if bash tools/cross-schema-scan.sh; then
  pass "Cross-schema scan"
else
  fail "Cross-schema scan — fix the violations above."
fi

# ── 2. Print-template guards (Resolution + SqlGuard) ─────────────────
step "۲) گاردهای قالب چاپ (Resolution + SqlGuard)"
# بدون SQL Server تست‌ها Skip می‌شوند (Skipped!) — آن هم نتیجهٔ قابل قبول برای
# این گام است؛ در CI سرویس SQL Server همین job را بالا می‌آورد (TARAZIN_TEST_CONN)
# تا این گاردها واقعاً اجرا شوند — و یک step شرطی بعدی آن‌ها را روی اسکیمای تازه
# از _Ensure ها دوباره اعتبارسنجی می‌کند.
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo \
     --filter "FullyQualifiedName~PrintTemplate" 2>&1 | tail -1 | grep -qE "Passed!|Skipped!"; then
  pass "گاردهای قالب چاپ سبز (ترتیب وضوح، بازنشانی، ایندکس‌های یکتا، هم‌زمانی)"
else
  fail "گاردهای قالب چاپ قرمز شدند — ترتیب وضوح/بازنشانی/ایندکس برگشته."
fi

# ── 3. Full test suite (PDF regression + close-year + rest) ───────────
# خروجی کامل ذخیره می‌شود تا گام ۶ (تولید گزارش نهایی) از همان عددِ واقعی بخواند.
step "۳) کل سویت تست (PDF/حسابداری/چاپ)"
TEST_SUMMARY_LINE="$(dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo 2>&1 | grep -E "Passed!|Skipped!|Failed!" | tail -1)"
if printf '%s\n' "$TEST_SUMMARY_LINE" | grep -qE "Passed!|Skipped!"; then
  pass "همهٔ تست‌ها سبز — $TEST_SUMMARY_LINE"
else
  fail "تست‌ها قرمز شدند — باگ خروجی PDF/سند برگشته."
fi

# ── 4. Web build (refreshes Tarazin.Web/bin — REQUIRED before restart) ─
step "۴) بیلد کامل وب (به‌روزرسانی کپی Tarazin.Web/bin)"
if dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo -v q 2>&1 | grep -q "0 Error(s)"; then
  pass "بیلد وب بدون خطا"
else
  fail "بیلد وب با خطا — پیش از ادامه درستش کن."
fi

# ── 5. Stale-build guard (must be 0 before dev-server restart) ────────
step "۵) گارد ضد «سرور با کد قدیمی»"
if bash tools/check-stale-build.sh; then
  pass "ساختار بیلد تازه — امن برای ریاستارت dev server"
else
  fail "گارد stale خطا داد — اول طبق پیام rebuild کن."
fi

# ── 6. Test-report refresh (QA evidence must reflect reality) ──────────
step "۶) به‌روزرسانی گزارش نهایی تست"
if bash tools/refresh-test-report.sh "$TEST_SUMMARY_LINE"; then
  pass "گزارش تست (docs/testing-report.md) از خروجی واقعی بازنویسی شد"
else
  fail "بازنویسی گزارش تست شکست خورد — فایل گزارش قابل‌نوشتن نیست."
fi

echo
echo "══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ همهٔ چک‌ها پاس شدند — امن برای بیلد/PR/ریاستارت."
  exit 0
else
  echo "❌ یک یا چند چک ناموفق بود (بالا را ببین)."
  exit 1
fi
