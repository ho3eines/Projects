#!/usr/bin/env bash
# run-checks.sh — One-shot validation gate for the whole project.
#
# Runs, in order, every check a coder/CI must pass before a build, PR, or
# dev-server restart:
#   1. Cross-schema scan      (tools/cross-schema-scan.sh)
#   2. PDF regression tests   (dotnet test Tarazin.Tests)
#   3. Web build              (dotnet build Tarazin.Web)  — refreshes Web/bin copy
#   4. Stale-build guard      (tools/check-stale-build.sh)
#
# Exit code: 0 = all green, 1 = a check failed (the failing step is named).
#
# NOTE on ordering: the Web build (3) MUST come after the test/build that refresh
# Tarazin.Ui/bin and before the stale guard (4), so that the "server runs old code"
# bug is caught and the guard reports a clean 0.
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

# ── 2. PDF regression tests (guards MediaBox/pagination/RTL) ──────────
step "۲) تست‌های بازگشت‌پذیر PDF (Tarazin.Tests)"
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo 2>&1 | tail -1 | grep -q "Passed!"; then
  pass "همهٔ تست‌های PDF سبز"
else
  fail "تست‌های PDF قرمز شدند — باگ خروجی PDF برگشته."
fi

# ── 3. Web build (refreshes Tarazin.Web/bin — REQUIRED before restart) ─
step "۳) بیلد کامل وب (به‌روزرسانی کپی Tarazin.Web/bin)"
if dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo -v q 2>&1 | grep -q "0 Error(s)"; then
  pass "بیلد وب بدون خطا"
else
  fail "بیلد وب با خطا — پیش از ادامه درستش کن."
fi

# ── 4. Stale-build guard (must be 0 before dev-server restart) ────────
step "۴) گارد ضد «سرور با کد قدیمی»"
if bash tools/check-stale-build.sh; then
  pass "ساختار بیلد تازه — امن برای ریاستارت dev server"
else
  fail "گارد stale خطا داد — اول طبق پیام rebuild کن."
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