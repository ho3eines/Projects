#!/usr/bin/env bash
# run-checks.sh — One-shot validation gate for the whole project.
#
# Runs, in order, every check a coder/CI must pass before a build, PR, or
# dev-server restart:
#   1. Cross-schema scan      (tools/cross-schema-scan.sh)
#   2. Print-template guards  (PrintTemplateResolutionTests + PrintTemplateSqlGuardTests)
#   2b. SourceDetail SQL guard (SourceDetailSqlGuardTests) — every cheque-source
#                               prefix resolves its linked accounting document
#   2c. Multi-invoice gate guard (MultiInvoiceGateTests) — store→accounting→treasury:
#                               each report yields exactly one invoice + one document
#                               + one unique SourceReference (idempotent)
#   3. Source-label guard     (TreasurySourceLabelsTests) — pure unit, never skips
#   4. Full test suite        (PDF regression, close-year, everything else)
#   4b. RTL-header pymupdf    (tools/check-rtl-headers.sh generic) — logo rightmost
#   4c. A5L template guard    (tools/check-rtl-headers.sh a5l) — MediaBox 595x420
#                             landscape + RTL header (BuildTemplatePdf A5L)
#   4d. BuildTablePdf A5L guard (tools/check-rtl-headers.sh table) — MediaBox
#                             595x420 landscape + RTL header (BuildTablePdf A5L)
#   4e. A5L no-header guard   (tools/check-rtl-headers.sh noheader) — MediaBox
#                             595x420 landscape + standalone QR replaces the logo
#   4f. BuildTablePdf multi-page guard (tools/check-rtl-headers.sh table-many) —
#                             BuildTablePdf with 60+ rows in A5L must be
#                             multi-page AND the table header repeats on every page
#   4g. BuildInvoicePdf A5L multi-page guard (tools/check-rtl-headers.sh
#                             invoice-a5l-many) — BuildInvoicePdf with 25 rows in
#                             A5L: MediaBox 595x420 landscape, multi-page, table
#                             header repeats on every page, no edge overflow
#   5. Web build              (dotnet build Tarazin.Web)  — refreshes Web/bin copy
#   6. Stale-build guard      (tools/check-stale-build.sh)
#   7. Test-report refresh    (tools/refresh-test-report.sh) — regenerates the
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
# NOTE on the source-label guard (step 3): it is PURE unit — no DB — so it must
# always run and fail (never Skip) so a renamed/extended prefix in
# TreasurySourceLabels is caught immediately.
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

# ── 3. Source-label guard (pure unit — no DB, never skips) ────────────
# برچسب مفهومی «منبع چک» (TreasurySourceLabels) را قفل می‌کند: هر پیشوندِ
# پشتیبانی‌شده در سه حالت (نمونهٔ واقعی، حروف کوچک/متفاوت، بی‌مقدار/ناشناخته).
# چون واحد و بدون دیتابیس است، همیشه اجرا و در صورت برگشتِ برچسب‌ها Fail می‌شود.
# ── 2b. SourceDetail SQL guard (real script, live data) ──────────────
# گاردِ SQL خالص روی treasury.SourceDetail: برای هر پیشوند منبعِ چک (GoldInvoice /
# GoldPurchase / Order / StoreOrder / Invoice / Cheque / Payroll / دستی) دادهٔ واقعی
# در همان اسکیمای دامنه seed می‌شود + سند حسابداریِ لینک‌شده، سپس اسکریپتِ واقعی
# صدا و تأیید می‌شود که DocumentId / DocumentNumber / ModuleId درست وضوح می‌شوند.
# بدون SQL Server Skip می‌شود (نه Fail)؛ در CI با سرویس SQL همین job واقعاً اجرا می‌شود.
step "۲ب) گارد وضوح منبع چک (SourceDetailSqlGuardTests)"
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo \
     --filter "FullyQualifiedName~SourceDetailSqlGuardTests" 2>&1 | tail -1 | grep -qE "Passed!|Skipped!"; then
  pass "همهٔ پیشوندهای منبع چک، سند حسابداری لینک‌شده را وضوح می‌کنند"
else
  fail "گارد SourceDetail قرمز شد — یکی از مسیرهای وضوح منبع چک خراب است."
fi

# ── 2c. Multi-invoice gate guard (store → accounting → treasury) ────
# قرارداد یکپارچه: «هر گزارش/سفارش دقیقاً یک فاکتور، یک سند حسابداری و یک منبع
# یکتا تولید می‌کند.» گاردِ SQL خالص روی اسکریپت‌های REAL این دروازه —
# accounting.SalesInvoiceFromOrder (idempotent on OrderId → یک فاکتور),
# treasury.CashEntryFromInvoice (idempotent on SourceReference='Invoice:{Id}' → یک حرکت),
# و یک سند با منبع یکتا per سفارش. بدون SQL Server Skip می‌شود (نه Fail)؛
# در CI با سرویس SQL واقعاً اجرا می‌شود.
step "۲ج) گارد دروازهٔ چندفاکتوره (MultiInvoiceGateTests)"
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo \
     --filter "FullyQualifiedName~MultiInvoiceGateTests" 2>&1 | tail -1 | grep -qE "Passed!|Skipped!"; then
  pass "هر گزارش → یک فاکتور + یک سند حسابداری + یک منبع یکتا"
else
  fail "گارد دروازهٔ چندفاکتوره قرمز شد — ایدمپوتنسی فاکتور/منبع خراب است."
fi

# ── 3. Source-label guard (pure unit — no DB, never skips) ────────────
step "۳) گارد برچسب منبع (TreasurySourceLabels)"
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo --filter "FullyQualifiedName~TreasurySourceLabels" 2>&1 | tail -1 | grep -qE "Passed!"; then
  pass "برچسب‌های منبع چک پایدارند (همهٔ پیشوندها در سه حالت)"
else
  fail "برچسب منبع برگشته — TreasurySourceLabels را مطابق تست به‌روز کن."
fi

# ── 3b. Vazirmatn font guard (pure unit — no DB, never skips) ─────────
# ضمانت می‌دهد فونت گزارش‌ها «Vazirmatn» از TTF جاسازی‌شده resolve می‌شود نه
# فالتبک لاتین (VazirmatnFontRegistrar.Register → QuestPDF BaseFont).
step "۳ب) گارد فونت Vazirmatn (VazirmatnFontRegistrationTests)"
if dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo --filter "FullyQualifiedName~VazirmatnFontRegistrationTests" 2>&1 | tail -1 | grep -qE "Passed!"; then
  pass "فونت گزارش‌ها — Vazirmatn واقعی (embedded)، نه فالتبک لاتین"
else
  fail "فونت گزارش برگشته — VazirmatnFontRegistrar/ثبت فونت را بررسی کن."
fi

# ── 4. Full test suite (PDF regression + close-year + rest) ───────────
# خروجی کامل ذخیره می‌شود تا گام ۷ (تولید گزارش نهایی) از همان عددِ واقعی بخواند.
step "۴) کل سویت تست (PDF/حسابداری/چاپ)"
TEST_SUMMARY_LINE="$(dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo 2>&1 | grep -E "Passed!|Skipped!|Failed!" | tail -1)"
if printf '%s\n' "$TEST_SUMMARY_LINE" | grep -qE "Passed!|Skipped!"; then
  pass "همهٔ تست‌ها سبز — $TEST_SUMMARY_LINE"
else
  fail "تست‌ها قرمز شدند — باگ خروجی PDF/سند برگشته."
fi

# ── 4b. RTL header pymupdf check (optional locally — runs in CI) ────
# بعد از اجرای کل سویت (که Dump_rtl_header_pdfs_for_pymupdf چهار PDF را
# برون‌ریزی می‌کند: فاکتور، چک‌ها، جدول عمومی، قالب) هدر راست‌چینِ واقعیِ
# هر کدام با pymupdf تأیید می‌شود: لوگوی سبز باید راست‌ترین عنصر باشد
# (x نزدیک لبهٔ راست برگه). بدون Python+pymupdf محلی SKIP می‌شود؛ اما CI
# (workflow) آن‌ها را نصب می‌کند تا این گام واقعاً اجرا و Fail واقعی بدهد.
# حالت «generic» فقط همین چک عمومی را اجرا می‌کند؛ گارد A5L جداگانه در ۴ج.
step "۴ب) تأیید pymupdf هدر راست‌چین (محلی اختیاری — در CI الزامی)"
if bash tools/check-rtl-headers.sh generic; then
  pass "هدر راست‌چین (لوگو راست‌ترین) در فاکتور/چک/جدول/قالب تأیید شد"
else
  fail "هدر RTL در یکی از PDF های برون‌ریزی‌شده خراب است — ترتیب لوگو/متن برگشته."
fi

# ── 4c. BuildTemplatePdf A5L guard (named pymupdf step) ───────────────
# گاردِ صریحِ خروجی A5L تابع BuildTemplatePdf (فایل template-a5l.pdf که توسط
# Dump_rtl_header_pdfs_for_pymupdf برون‌ریزی می‌شود): MediaBox باید دقیقاً
# A5 افقی ≈ ۵۹۵×۴۲۰ باشد (نه A5 پرتره و نه A4) و هدر آن RTL بماند (لوگوی سبز
# راست‌ترین عنصر). همین گام با نام خودش در CI هم اجرا می‌شود (step جدا).
step "۴ج) گارد A5L قالب چاپ (pymupdf — MediaBox و هدر RTL)"
if bash tools/check-rtl-headers.sh a5l; then
  pass "خروجی A5L قالب چاپ — MediaBox=595x420 landscape و هدر راست‌چین"
else
  fail "گارد A5L قالب چاپ خراب شد — اندازه/جهت صفحه یا هدر RTL برگشته."
fi

# ── 4d. BuildTablePdf A5L guard (named pymupdf step) ─────────────────
# همان گارد ۴ج، ولی برای جدول عمومی (BuildTablePdf → BuildOfficialHeader):
# فایل table-a5l.pdf باید MediaBox A5 افقی ≈ ۵۹۵×۴۲۰ و هدر RTL داشته باشد.
step "۴د) گارد BuildTablePdf A5L (pymupdf — MediaBox و هدر RTL)"
if bash tools/check-rtl-headers.sh table; then
  pass "BuildTablePdf A5L — MediaBox=595x420 landscape و هدر راست‌چین"
else
  fail "گارد BuildTablePdf A5L خراب شد — اندازه/جهت صفحه یا هدر RTL برگشته."
fi

# ── 4e. BuildTemplatePdf A5L no-header guard (named pymupdf step) ────────
# وقتی هدر شرکت خاموش است ولی QR روشن، QR مستقل باید در گوشهٔ بالای راست جای
# لوگو بنشیند (فایل template-a5l-noheader.pdf). این گام رسماً skip نمی‌شود
# (فایل هست) و تشخیص می‌دهد: بدون لوگوی هدر + تصویر QR در باند بالا-راست.
step "۴هـ) گارد A5L بدون هدر — QR مستقل جایگزین لوگو (pymupdf)"
if bash tools/check-rtl-headers.sh noheader; then
  pass "خروجی A5L بدون هدر — QR مستقل در گوشهٔ بالای راست (جایگزین لوگو)"
else
  fail "گارد A5L بدون هدر خراب شد — QR مستقل جایگزین لوگو نشده است."
fi

# ── 4f. BuildTablePdf multi-page guard (named pymupdf step) ────────────
# جدول عمومی با ۶۵ ردیف در A5L (table-a5l-many.pdf) باید چندصفحه باشد و هدرِ جدول
# در هر صفحه تکرار شود (استخراج متن هر صفحه با pymupdf). اگر صفحه‌بندی خراب شود
# (یک صفحهٔ بریده) یا هدر از صفحهٔ ۲ به بعد نیفتد، این گام Fail می‌دهد.
step "۴و) گارد BuildTablePdf چندصفحه‌گی (pymupdf — هدر در هر صفحه)"
if bash tools/check-rtl-headers.sh table-many; then
  pass "BuildTablePdf ۶۵ ردیفی در A5L چندصفحه است و هدر در هر صفحه تکرار شده"
else
  fail "گارد BuildTablePdf چندصفحه‌گی خراب شد — هدر در همهٔ صفحه‌ها تکرار نشده یا صفحه‌بندی بریده."
fi

# ── 4g. BuildInvoicePdf A5L multi-page guard (named pymupdf step) ────────
# فاکتور طلا با ۲۵ ردیف در A5L (invoice-a5l-many.pdf) باید: MediaBox A5 landscape
# ≈ ۵۹۵×۴۲۰، چندصفحه، هدرِ جدول در هر صفحه و بدون بیرون‌زدگی از لبه. اگر اندازه/جهت
# صفحه برگردد، هدر از صفحهٔ ۲ به بعد نیفتد، یا محتوایی از لبه بیرون بزند → Fail.
step "۴ز) گارد BuildInvoicePdf A5L چندصفحه (pymupdf — MediaBox و بدون بیرون‌زدگی)"
if bash tools/check-rtl-headers.sh invoice-a5l-many; then
  pass "BuildInvoicePdf ۲۵ ردیفی در A5L — MediaBox=595x420 landscape، چندصفحه، هدر در هر صفحه، بدون بیرون‌زدگی"
else
  fail "گارد BuildInvoicePdf A5L چندصفحه خراب شد — MediaBox، چندصفحه‌گی، تکرار هدر یا بیرون‌زدگی."
fi

# ── 5. Web build (refreshes Tarazin.Web/bin — REQUIRED before restart) ─
step "۵) بیلد کامل وب (به‌روزرسانی کپی Tarazin.Web/bin)"
if dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo -v q 2>&1 | grep -q "0 Error(s)"; then
  pass "بیلد وب بدون خطا"
else
  fail "بیلد وب با خطا — پیش از ادامه درستش کن."
fi

# ── 6. Stale-build guard (must be 0 before dev-server restart) ────────
step "۶) گارد ضد «سرور با کد قدیمی»"
if bash tools/check-stale-build.sh; then
  pass "ساختار بیلد تازه — امن برای ریاستارت dev server"
else
  fail "گارد stale خطا داد — اول طبق پیام rebuild کن."
fi

# ── 7. Test-report refresh (QA evidence must reflect reality) ──────────
step "۷) به‌روزرسانی گزارش نهایی تست"
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
