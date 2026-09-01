#!/usr/bin/env bash
# check-rtl-headers.sh — pymupdf verification of the RTL header guard.
#
# The xUnit guard (PrintRtlGuards.Page_methods_wire_rtl_header_builders) locks the
# source wiring (page → header builder + ContentFromRightToLeft ordering). This
# script verifies the actual rendered PDFs: in the header of every dumped PDF
# (invoice, cheque report, template) the teal logo block must be the rightmost
# element — its x near the right edge of the page — proving real RTL output,
# not just source structure.
#
# Usage: bash tools/check-rtl-headers.sh [all|generic|a5l|table|noheader|table-many|invoice-a5l-many|table-summary-pages]   (from project root)
#   all     (default) — generic logo-rightmost check on every dumped PDF,
#                       PLUS the A5L guards: BuildTemplatePdf (template-a5l.pdf),
#                       BuildTablePdf (table-a5l.pdf), the no-header QR guard
#                       (template-a5l-noheader.pdf), the multi-page table guard
#                       (table-a5l-many.pdf) and the multi-page invoice guard
#                       (invoice-a5l-many.pdf: BuildInvoicePdf with 25 rows in A5L
#                       — MediaBox 595x420, multi-page, header repeats, no overflow).
#   generic            — only the logo-rightmost check on all dumped PDFs.
#   a5l                — only the BuildTemplatePdf A5L guard (template-a5l.pdf):
#                       MediaBox must be landscape ≈ 595×420 and header RTL.
#   table              — only the BuildTablePdf A5L guard (table-a5l.pdf):
#                       MediaBox must be landscape ≈ 595×420 and header RTL.
#   noheader           — BuildTemplatePdf A5L with the company header OFF: must NOT
#                       skip; the standalone QR must replace the logo (no teal logo
#                       in the header band + a QR image top-right).
#   table-many         — BuildTablePdf with 60+ rows in A5L must be multi-page AND
#                       the table header must repeat on every page (per-page text).
#   invoice-a5l-many   — BuildInvoicePdf with 25 rows in A5L must be multi-page,
#                       the table header must repeat on every page, MediaBox must be
#                       A5 landscape ≈ 595×420 and nothing may overflow the page edge.
#   table-summary-pages — BuildTablePdf with 20 rows in A5 portrait: the header must
#                       appear on every page that has table rows; the summary-only last
#                       page (no rows) is legitimately header-less (table-a5-summary.pdf).
#   The «a5l»/«table»/«noheader»/«table-many»/«invoice-a5l-many»/«table-summary-pages» modes let
#   run-checks.sh / CI name each guard as its own step.
#
# Requires the dump files produced by `dotnet test` (PrintRtlGuards.Dump_rtl_header_pdfs_for_pymupdf)
# and Python 3 + pymupdf. If either is missing, the step is SKIPPED (optional).
#
# Exit:  0 = verified (or skipped), 1 = a header is NOT right-aligned.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

MODE="${1:-all}"

DIR="${TEMP:-/tmp}/tarazin-pdf/rtl-headers"
[ -z "${TEMP:-}" ] && DIR="/tmp/tarazin-pdf/rtl-headers"

if ! command -v py >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
  echo "⏭️  pymupdf check skipped — Python not available (optional step)."
  exit 0
fi

PY=py
command -v py >/dev/null 2>&1 || PY=python3
if ! "$PY" -X utf8 -c "import pymupdf" >/dev/null 2>&1; then
  echo "⏭️  pymupdf check skipped — pymupdf not installed (optional step)."
  exit 0
fi

# ───────────── گارد عمومی: لوگو راست‌ترین در همهٔ PDF های برون‌ریزی‌شده ─────────────
run_generic() {
  if [ ! -d "$DIR" ] || [ -z "$(ls "$DIR"/*.pdf 2>/dev/null)" ]; then
    echo "⏭️  pymupdf check skipped — dumped PDFs not found (run the full test suite first)."
    return 0
  fi

  # Verifies in every PDF: at least one teal logo block (#0f766e) in the header band
  # whose left edge (x0) is in the rightmost 10% of the page width.
  FAILED=""
  for f in "$DIR"/*.pdf; do
    name="$(basename "$f")"
    # فایل «بدون هدر» عمداً لوگوی سبز ندارد (QR مستقل جایگزینش شده) — چک عمومی
    # روی آن نادرست Fail می‌دهد؛ گارد اختصاصی run_a5l_noheader آن را می‌سنجد.
    [ "$name" = "template-a5l-noheader.pdf" ] && continue
    if ! "$PY" -X utf8 - "$f" <<'PYEOF'
import sys, pymupdf
f = sys.argv[1]
doc = pymupdf.open(f)
page = doc[0]
W = page.rect.width
logos = []
for d in page.get_drawings():
    fill = d.get("fill")
    if fill and abs(fill[0]-0.0588)<0.02 and abs(fill[1]-0.4627)<0.02 and abs(fill[2]-0.4314)<0.02:
        logos.append(d["rect"])
ok = False
for lg in logos:
    if lg.y0 < 60 and lg.x0 > W * 0.90:
        ok = True
        break
print(f"  {f.split(chr(92))[-1] if chr(92) in f else f.split('/')[-1]}: logo_x0={[round(l.x0) for l in logos]} pageW={round(W)} ok={ok}")
sys.exit(0 if ok else 2)
PYEOF
    then
      FAILED="$FAILED $name"
    fi
  done

  if [ -n "$FAILED" ]; then
    echo "❌ RTL header pymupdf check failed for:$FAILED — logo is not the rightmost element."
    return 1
  fi
  echo "✅ RTL header pymupdf check — logo rightmost in all dumped PDFs."
  return 0
}

# ───────────── گارد A5L: قالب چاپ (BuildTemplatePdf) با override «A5L» ─────────────
# قالب چاپ با override «A5L» (فایل template-a5l.pdf که Dump_rtl_header_pdfs_for_pymupdf
# می‌سازد) باید: (۱) MediaBox افقی ≈ ۵۹۵×۴۲۰ باشد (نه A5 پرترهٔ ۴۲۰×۵۹۵ و نه A4)،
# و (۲) هدرش RTL بماند — لوگوی سبز در نوار هدر راست‌ترین عنصر (x0 در ۱۰٪ راست صفحه).
run_a5l() {
  local A5L="$DIR/template-a5l.pdf"
  if [ ! -f "$A5L" ]; then
    echo "⏭️  BuildTemplatePdf A5L step skipped — template-a5l.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$A5L" <<'PYEOF'
import sys, pymupdf
f = sys.argv[1]
doc = pymupdf.open(f)
page = doc[0]
W, H = page.rect.width, page.rect.height

# ۱) MediaBox باید A5 landscape باشد (عرض > ارتفاع، حدود ۵۹۵×۴۲۰).
if not (560 < W < 620 and 400 < H < 440 and W > H):
    print(f"  template-a5l: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 landscape ~595x420")
    sys.exit(2)

# ۲) هدر RTL: لوگوی سبز (#0f766e) باید در نوار هدر (y<60) راست‌ترین عنصر باشد.
logos = []
for d in page.get_drawings():
    fill = d.get("fill")
    if fill and abs(fill[0]-0.0588)<0.02 and abs(fill[1]-0.4627)<0.02 and abs(fill[2]-0.4314)<0.02:
        logos.append(d["rect"])
ok = any(lg.y0 < 60 and lg.x0 > W * 0.90 for lg in logos)
print(f"  template-a5l: MediaBox={W:.0f}x{H:.0f} landscape logo_x0={[round(l.x0) for l in logos]} pageW={round(W)} rtl_header={ok}")
sys.exit(0 if ok else 2)
PYEOF
  then
    echo "❌ BuildTemplatePdf A5L pymupdf check failed — MediaBox یا هدر RTL درست نیست."
    return 1
  fi
  echo "✅ BuildTemplatePdf A5L pymupdf check — MediaBox=595x420 (landscape) و هدر راست‌چین."
  return 0
}

# ───────────── گارد A5L: جدول عمومی (BuildTablePdf) با override «A5L» ─────────────
# همان گارد قالب، ولی برای گزارش جدولی عمومی (BuildTablePdf → BuildOfficialHeader):
# فایل table-a5l.pdf (ساخته‌شده توسط Dump_rtl_header_pdfs_for_pymupdf) باید
# (۱) MediaBox افقی ≈ ۵۹۵×۴۲۰ باشد و (۲) هدرش RTL بماند — لوگوی سبز راست‌ترین.
run_table_a5l() {
  local T="$DIR/table-a5l.pdf"
  if [ ! -f "$T" ]; then
    echo "⏭️  BuildTablePdf A5L step skipped — table-a5l.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$T" <<'PYEOF'
import sys, pymupdf
f = sys.argv[1]
doc = pymupdf.open(f)
page = doc[0]
W, H = page.rect.width, page.rect.height

# ۱) MediaBox باید A5 landscape باشد (عرض > ارتفاع، حدود ۵۹۵×۴۲۰).
if not (560 < W < 620 and 400 < H < 440 and W > H):
    print(f"  table-a5l: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 landscape ~595x420")
    sys.exit(2)

# ۲) هدر RTL: لوگوی سبز (#0f766e) باید در نوار هدر (y<60) راست‌ترین عنصر باشد.
logos = []
for d in page.get_drawings():
    fill = d.get("fill")
    if fill and abs(fill[0]-0.0588)<0.02 and abs(fill[1]-0.4627)<0.02 and abs(fill[2]-0.4314)<0.02:
        logos.append(d["rect"])
ok = any(lg.y0 < 60 and lg.x0 > W * 0.90 for lg in logos)
print(f"  table-a5l: MediaBox={W:.0f}x{H:.0f} landscape logo_x0={[round(l.x0) for l in logos]} pageW={round(W)} rtl_header={ok}")
sys.exit(0 if ok else 2)
PYEOF
  then
    echo "❌ BuildTablePdf A5L pymupdf check failed — MediaBox یا هدر RTL درست نیست."
    return 1
  fi
  echo "✅ BuildTablePdf A5L pymupdf check — MediaBox=595x420 (landscape) و هدر راست‌چین."
  return 0
}

# ───── گارد A5L بدون هدر: QR مستقل باید جایگزین لوگو شود (BuildTemplatePdf) ─────
# وقتی هدر شرکت خاموش است (ShowCompanyHeader=false) ولی QR روشن، هدر رسمی رندر
# نمی‌شود و QR مستقل در گوشهٔ بالای راست جای لوگو می‌نشیند (فایل
# template-a5l-noheader.pdf ساخته‌شده توسط Dump_rtl_header_pdfs_for_pymupdf).
# این گارد رسماً skip نمی‌شود (فایل هست) و تشخیص می‌دهد: (۱) لوگوی سبز در باند
# هدر وجود ندارد، (۲) یک تصویر (PNGِ QR) در باند بالا و سمت راست هست.
run_a5l_noheader() {
  local F="$DIR/template-a5l-noheader.pdf"
  if [ ! -f "$F" ]; then
    echo "⏭️  BuildTemplatePdf A5L no-header step skipped — template-a5l-noheader.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$F" <<'PYEOF'
import sys, pymupdf
f = sys.argv[1]
doc = pymupdf.open(f)
page = doc[0]
W, H = page.rect.width, page.rect.height

# ۱) MediaBox باید A5 landscape باشد (عرض > ارتفاع، حدود ۵۹۵×۴۲۰).
if not (560 < W < 620 and 400 < H < 440 and W > H):
    print(f"  template-a5l-noheader: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 landscape ~595x420")
    sys.exit(2)

# ۲) هدر رسمی خاموش است → لوگوی سبز (#0f766e) نباید در باند هدر (y<60) باشد.
logo_in_band = False
for d in page.get_drawings():
    fill = d.get("fill")
    if fill and abs(fill[0]-0.0588)<0.02 and abs(fill[1]-0.4627)<0.02 and abs(fill[2]-0.4314)<0.02:
        if d["rect"].y0 < 60:
            logo_in_band = True
            break

# ۳) QR مستقل باید جایگزین لوگو شده باشد: تصویری (PNGِ QR) در باند بالا و سمت راست
#    (x0 در ۱۵٪ راست صفحه). لوگوی سبز نیست؛ پس هر تصویرِ بالا-راست = QR مستقل.
qr_in_band = False
for info in page.get_image_info():
    x0, y0, x1, y1 = info["bbox"]
    if y0 < 60 and x0 > W * 0.85:
        qr_in_band = True
        break

print(f"  template-a5l-noheader: MediaBox={W:.0f}x{H:.0f} landscape logo_in_band={logo_in_band} qr_in_band={qr_in_band}")
if logo_in_band or not qr_in_band:
    print("  FAIL — انتظار: بدون لوگوی هدر + QR مستقل در گوشهٔ بالای راست (جایگزین لوگو)")
    sys.exit(2)
sys.exit(0)
PYEOF
  then
    echo "❌ BuildTemplatePdf A5L no-header pymupdf check failed — QR مستقل جایگزین لوگو نشده است."
    return 1
  fi
  echo "✅ BuildTemplatePdf A5L no-header pymupdf check — QR مستقل در گوشهٔ بالای راست (جایگزین لوگو)."
  return 0
}

# ───── گارد «هدر فقط روی صفحاتِ حاوی جدول» (BuildTablePdf در A5 پرتوره) ─────
# جدول عمومی با ۲۰ ردیف در A5 **پرتوره** (فایل table-a5-summary.pdf ساخته‌شده توسط
# Dump_rtl_header_pdfs_for_pymupdf) طوری‌ست که صفحهٔ ۱ = جدول (هدر + ردیف‌ها) و
# صفحهٔ آخر = فقط جمع‌بندی (بدون هدر جدول و بدون ردیف). این گارد «هدرِ جدول فقط
# روی صفحاتِ حاوی جدول» را می‌سنجد: هر صفحه‌ای که ردیفِ جدول دارد باید هدرِ جدول
# («شماره چک») هم داشته باشد — ولی صفحهٔ جمع‌بندی که ردیفی ندارد، رسماً معتبر است
# که هدر نداشته باشد (اشتباه قدیمی: چکِ «هدر در هر صفحه» این حالت را Fail می‌کرد).
run_table_summary_pages() {
  local F="$DIR/table-a5-summary.pdf"
  if [ ! -f "$F" ]; then
    echo "⏭️  BuildTablePdf summary-page step skipped — table-a5-summary.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$F" <<'PYEOF'
import sys, pymupdf, unicodedata
f = sys.argv[1]
doc = pymupdf.open(f)
page0 = doc[0]
W, H = page0.rect.width, page0.rect.height

# ۱) MediaBox باید A5 پرتوره باشد (عرض < ارتفاع، حدود ۴۲۰×۵۹۵).
if not (400 < W < 440 and 560 < H < 620 and W < H):
    print(f"  table-a5-summary: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 پرتوره ~420x595")
    sys.exit(2)

def texts(p):
    return unicodedata.normalize('NFKC', p.get_text())

# ۲) ساختار دو-صفحه‌ای لازم است: صفحهٔ ۱ = جدول (هدردارد + ردیف CHQ)، صفحهٔ ۲ = فقط جمع‌بندی.
n = doc.page_count
if n < 2:
    print(f"  table-a5-summary: FAIL فقط {n} صفحه — انتظار جدول در صفحهٔ ۱ و جمع‌بندی در صفحهٔ آخر")
    sys.exit(2)

# ۳) «هدر فقط روی صفحاتِ حاوی جدول»: هر صفحه‌ای که ردیفِ جدول (CHQ-) دارد باید هدر
#    («شماره چک») هم داشته باشد؛ صفحه‌های بدون ردیف (جمع‌بندی) معاف‌اند — یعنی اگر
#    صفحه‌ای ردیف دارد ولی هدر ندارد، Fail؛ و اگر صفحهٔ جمع‌بندی هدر نداشته باشد، OK.
missing_header_on_row_pages = []
for i, page in enumerate(doc):
    t = texts(page)
    has_rows = "CHQ-" in t
    has_header = "شماره چک" in t
    if has_rows and not has_header:
        missing_header_on_row_pages.append(i + 1)

# ۴) صفحهٔ جمع‌بندی باید واقعاً جمع‌بندی داشته باشد و ردیف نداشته باشد (ضد-تهی).
summary_pages = []
for i, page in enumerate(doc):
    t = texts(page)
    if "جمع مبلغ" in t and "CHQ-" not in t:
        summary_pages.append(i + 1)

print(f"  table-a5-summary: MediaBox={W:.0f}x{H:.0f} portrait pages={n} missing_header_on_row_pages={missing_header_on_row_pages} summary_only_pages={summary_pages}")
if missing_header_on_row_pages:
    print(f"  FAIL — صفحاتِ دارای ردیف که هدر جدول ندارند: {missing_header_on_row_pages}")
    sys.exit(2)
if not summary_pages:
    print("  FAIL — هیچ صفحهٔ جمع‌بندی‌ای (بدون ردیف، دارای جمع مبلغ) پیدا نشد — ساختار تست درست نیست")
    sys.exit(2)
if summary_pages[-1] != n:
    print(f"  FAIL — صفحهٔ جمع‌بندی باید آخرین صفحه باشد نه {summary_pages[-1]} از {n}")
    sys.exit(2)
sys.exit(0)
PYEOF
  then
    echo "❌ BuildTablePdf summary-page pymupdf check failed — هدرِ جدول روی صفحه‌های دارای ردیف تکرار نشده یا ساختار جمع‌بندی درست نیست."
    return 1
  fi
  echo "✅ BuildTablePdf summary-page pymupdf check — هدر فقط روی صفحاتِ دارای ردیف؛ صفحهٔ جمع‌بندی بدون هدر معتبر است."
  return 0
}

# ─────── گارد چندصفحه‌گی جدول عمومی (BuildTablePdf): هدر در هر صفحه تکرار شود ───────
# جدول عمومی با ۶۵ ردیف در A5L (فایل table-a5l-many.pdf ساخته‌شده توسط
# Dump_rtl_header_pdfs_for_pymupdf) باید: (۱) چندصفحه باشد (PageCount >= 2)،
# (۲) هدرِ جدول (برچسب «شماره چک») در **هر** صفحه تکرار شود — چون `table.Header(...)`
# در QuestPDF خودکار روی هر صفحه می‌آید؛ اگر هدر از صفحهٔ ۲ به بعد نیفتد یعنی خراب است.
run_table_many() {
  local F="$DIR/table-a5l-many.pdf"
  if [ ! -f "$F" ]; then
    echo "⏭️  BuildTablePdf multi-page step skipped — table-a5l-many.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$F" <<'PYEOF'
import sys, pymupdf, unicodedata
f = sys.argv[1]
doc = pymupdf.open(f)
page0 = doc[0]
W, H = page0.rect.width, page0.rect.height

# ۱) MediaBox باید A5 landscape باشد (عرض > ارتفاع، حدود ۵۹۵×۴۲۰).
if not (560 < W < 620 and 400 < H < 440 and W > H):
    print(f"  table-a5l-many: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 landscape ~595x420")
    sys.exit(2)

# ۲) باید چندصفحه باشد (۶۵ ردیف در A5L هرگز در یک صفحه جا نمی‌شود).
n = doc.page_count
if n < 2:
    print(f"  table-a5l-many: FAIL فقط {n} صفحه — انتظار چندصفحه بودن (۶۵ ردیف در A5L)")
    sys.exit(2)

# ۳) هدرِ جدول باید در هر صفحه تکرار شود: برچسب «شماره چک» فقط در ردیف هدر است
#    (ردیف‌های بدنه CHQ-xxxxx هستند) پس باید در متن هر صفحه دیده شود.
#    نکته: استخراج متن PDF حروف را به شکل Presentation Forms (U+FBxx) برمی‌گرداند،
#    پس با NFKC به پایهٔ فارسی نرمال می‌کنیم تا مقایسهٔ رشته درست باشد.
def texts(p):
    return unicodedata.normalize('NFKC', p.get_text())
missing = []
for i, page in enumerate(doc):
    if "شماره چک" not in texts(page):
        missing.append(i + 1)
print(f"  table-a5l-many: MediaBox={W:.0f}x{H:.0f} landscape pages={n} header_on_page={[i+1 for i in range(n) if i+1 not in missing]}")
if missing:
    print(f"  FAIL — هدرِ جدول در صفحه‌های {missing} تکرار نشده است.")
    sys.exit(2)
sys.exit(0)
PYEOF
  then
    echo "❌ BuildTablePdf multi-page pymupdf check failed — چندصفحه نیست یا هدر در همهٔ صفحه‌ها تکرار نشده."
    return 1
  fi
  echo "✅ BuildTablePdf multi-page pymupdf check — چندصفحه و هدرِ جدول در هر صفحه تکرار شده."
  return 0
}

# ─────── گارد A5L چندصفحه فاکتور طلا (BuildInvoicePdf): بدون بیرون‌زدگی ───────
# فاکتور طلا با ۲۵ ردیف در A5 افقی (فایل invoice-a5l-many.pdf ساخته‌شده توسط
# Dump_rtl_header_pdfs_for_pymupdf) باید: (۱) MediaBox A5 landscape ≈ ۵۹۵×۴۲۰ باشد،
# (۲) چندصفحه شود (PageCount >= 2)، (۳) هدرِ جدول (برچسب «ردیف») در **هر** صفحه تکرار
# شود، و (۴) هیچ محتوایی (متن یا رسم) از لبهٔ صفحه بیرون نزند.
run_invoice_a5l_many() {
  local F="$DIR/invoice-a5l-many.pdf"
  if [ ! -f "$F" ]; then
    echo "⏭️  BuildInvoicePdf A5L multi-page step skipped — invoice-a5l-many.pdf not found (run the full test suite first)."
    return 0
  fi

  if ! "$PY" -X utf8 - "$F" <<'PYEOF'
import sys, pymupdf, unicodedata
f = sys.argv[1]
doc = pymupdf.open(f)
page0 = doc[0]
W, H = page0.rect.width, page0.rect.height

# ۱) MediaBox باید A5 landscape باشد (عرض > ارتفاع، حدود ۵۹۵×۴۲۰).
if not (560 < W < 620 and 400 < H < 440 and W > H):
    print(f"  invoice-a5l-many: FAIL MediaBox={W:.0f}x{H:.0f} — انتظار A5 landscape ~595x420")
    sys.exit(2)

# ۲) باید چندصفحه باشد (۲۵ ردیف فاکتور در A5L هرگز در یک صفحه جا نمی‌شود).
n = doc.page_count
if n < 2:
    print(f"  invoice-a5l-many: FAIL فقط {n} صفحه — انتظار چندصفحه بودن (۲۵ ردیف در A5L)")
    sys.exit(2)

# ۳) هدرِ جدول باید در هر صفحه تکرار شود: برچسب «ردیف» فقط در ردیف هدر جدول است
#    (بدنه شمارهٔ ردیف را می‌نویسد) — با NFKC نرمال می‌کنیم چون استخراج متن PDF
#    حروف را به شکل Presentation Forms (U+FBxx) برمی‌گرداند.
def texts(p):
    return unicodedata.normalize('NFKC', p.get_text())
missing = []
for i, page in enumerate(doc):
    if "ردیف" not in texts(page):
        missing.append(i + 1)
if missing:
    print(f"  invoice-a5l-many: FAIL — هدرِ جدول در صفحه‌های {missing} تکرار نشده است.")
    sys.exit(2)

# ۴) بدون بیرون‌زدگی: هیچ کلمه یا رسمی از لبهٔ صفحه بیرون نزند (تلورانس ۲pt).
tol = 2.0
overflow = []
for i, page in enumerate(doc):
    pW, pH = page.rect.width, page.rect.height
    for x0, y0, x1, y1, *_ in page.get_text("words"):
        if x0 < -tol or y0 < -tol or x1 > pW + tol or y1 > pH + tol:
            overflow.append((i + 1, "word", round(x0, 1), round(y0, 1), round(x1, 1), round(y1, 1)))
    for d in page.get_drawings():
        r = d["rect"]
        if r.x0 < -tol or r.y0 < -tol or r.x1 > pW + tol or r.y1 > pH + tol:
            overflow.append((i + 1, "drawing", round(r.x0, 1), round(r.y0, 1), round(r.x1, 1), round(r.y1, 1)))
print(f"  invoice-a5l-many: MediaBox={W:.0f}x{H:.0f} landscape pages={n} header_on_all={not missing} overflow_items={len(overflow)}")
if overflow:
    print(f"  FAIL — بیرون‌زدگی از لبهٔ صفحه: {overflow[:5]}")
    sys.exit(2)
sys.exit(0)
PYEOF
  then
    echo "❌ BuildInvoicePdf A5L multi-page pymupdf check failed — MediaBox، چندصفحه‌گی، تکرار هدر یا بیرون‌زدگی."
    return 1
  fi
  echo "✅ BuildInvoicePdf A5L multi-page pymupdf check — MediaBox=595x420 (landscape)، چندصفحه، هدر در هر صفحه و بدون بیرون‌زدگی."
  return 0
}

OK=0
case "$MODE" in
  generic) run_generic || OK=1 ;;
  a5l)     run_a5l || OK=1 ;;
  table)   run_table_a5l || OK=1 ;;
  noheader) run_a5l_noheader || OK=1 ;;
  table-many) run_table_many || OK=1 ;;
  invoice-a5l-many) run_invoice_a5l_many || OK=1 ;;
  table-summary-pages) run_table_summary_pages || OK=1 ;;
  *)       run_generic || OK=1
           run_a5l || OK=1
           run_table_a5l || OK=1
           run_a5l_noheader || OK=1
           run_table_many || OK=1
           run_invoice_a5l_many || OK=1
           run_table_summary_pages || OK=1 ;;
esac
exit $OK
