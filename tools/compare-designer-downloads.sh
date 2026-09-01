#!/usr/bin/env bash
# compare-designer-downloads.sh — مقایسهٔ لایوِ دیزاینر چاپ با بایت‌های مرجع تست.
#
# پروندهٔ مرجع: sha256.txt که DesignerMatrixTests تولید می‌کند
#   (%TEMP%/tarazin-pdf/designer-matrix/sha256.txt؛ هر سطر «LABEL<TAB>HEX»)
# برای «treasury.cheques» در هر چهار ترکیب  A4-P / A4-L / A5-P / A5-L با
# BuildTemplatePdf (همان مسیر دکمهٔ دانلود دیزاینر) ساخته و هش می‌گیرد. این
# اسکریپت همان مقایسه را با فایل‌هایی که کاربر از UI دانلود می‌کند انجام می‌دهد —
# تا ثابت شود دانلودِ مرورگر دقیقاً همان بایت‌های QuestPDF است (و نه خروجیِ
# HTML/کد کهنهٔ سرورِ --no-build).
#
# هشِ مقایسه، همان StableHash تست است: /CreationDate و /ModDate (تایم‌استمپِ با
# دقتِ ثانیه) با مقدار ثابت جایگزین می‌شوند، سپس SHA256 روی بایت‌های Latin1 —
# یعنی هش فقط به محتوای واقعی بستگی دارد نه ساعتِ ساختِ PDF. این نرمال‌سازی باید
# در هر دو طرف یکی باشد؛ اگر بایت‌ها فرق داشته باشند (تغییرِ رندر، قالبِ متفاوت،
# کدِ کهنه) هش‌ها مطابقت نمی‌کنند.
#
# Usage (از ریشهٔ پروژه):
#   bash tools/compare-designer-downloads.sh A5-L=path/a.pdf A4-P=path/b.pdf
#       مقایسهٔ صریح: هر فایلِ دانلودشده با برچسبِ ترکیبش.
#   bash tools/compare-designer-downloads.sh --dir پوشه
#       اسکن خودکارِ پوشه (پیش‌فرض: نه) — جهتِ هر PDF از MediaBoxِ خودش تشخیص
#       داده می‌شود (نیازمند pymupdf؛ بدون آن باید LABEL=path صریح بدهی).
#   MANIFEST=path bash tools/compare-designer-downloads.sh ...
#       override مسیر sha256.txt (پیش‌فرض: %TEMP%/tarazin-pdf/designer-matrix/sha256.txt)
#
# Exit: 0 = همهٔ موارد ارائه‌شده مطابقت دارند؛ 1 = عدم تطابق یا خطای ورودی.

set -uo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

usage() {
  sed -n '2,30p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# ── مسیر manifest (تولیدشده توسط تست) ───────────────────────────────────
MANIFEST="${MANIFEST:-${TEMP:-/tmp}/tarazin-pdf/designer-matrix/sha256.txt}"
if [ ! -f "$MANIFEST" ]; then
  echo "❌ manifest مرجع یافت نشد: $MANIFEST"
  echo "   اول تست مرجع را اجرا کن تا sha256.txt ساخته شود:"
  echo "   dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo --filter Designer_download_matrix_matches_reference_bytes"
  exit 1
fi

PY=py
command -v py >/dev/null 2>&1 || PY=python3
if ! command -v "$PY" >/dev/null 2>&1; then
  echo "❌ Python در دسترس نیست (برای StableHash لازم است)."
  exit 1
fi

# StableHash — دقیقاً همان نرمال‌سازی C# تست:
#   text = Latin1(bytes); norm = regex( CreationDate|ModDate ); sha256(Latin1(norm))
stable_hash() {
  "$PY" -X utf8 - "$1" <<'PYEOF'
import hashlib, re, sys
raw = open(sys.argv[1], 'rb').read()
text = raw.decode('latin1')
norm = re.sub(r"/CreationDate\s*\([^)]*\)|/ModDate\s*\([^)]*\)",
              "/CreationDate (D:0+00'00')/ModDate (D:0+00'00')", text)
print(hashlib.sha256(norm.encode('latin1')).hexdigest().upper())
PYEOF
}

# تشخیص برچسب ترکیب از MediaBox صفحهٔ اول — خروجی: برچسب، یا خالی (ناشناخته).
# کد خروجی: 0 = پیدا شد، 2 = PDF ناشناخته، 3 = pymupdf نصب نیست.
pdf_label() {
  "$PY" -X utf8 - "$1" <<'PYEOF'
import sys
try:
    import pymupdf
except ImportError:
    sys.exit(3)
d = pymupdf.open(sys.argv[1])
r = d[0].rect
w, h = r.width, r.height
combos = [("A4-P", 595.28, 841.89), ("A4-L", 841.89, 595.28),
          ("A5-P", 419.53, 595.28), ("A5-L", 595.28, 419.53)]
for label, cw, ch in combos:
    if abs(w - cw) < 3 and abs(h - ch) < 3:
        print(label)
        sys.exit(0)
sys.exit(2)  # ابعاد با هیچ ترکیب مرجع نمی‌خورد
PYEOF
}

ref_hash() {  # ref_hash LABEL → هش مرجع یا خالی
  local label="$1"
  awk -F'	' -v L="$label" '$1 == L { print $2; found=1 } END { exit !found }' "$MANIFEST" 2>/dev/null
}

FAIL=0
compare_one() {  # compare_one LABEL FILE
  local label="$1" file="$2"
  if [ ! -f "$file" ]; then
    echo "❌ [$label] فایل یافت نشد: $file"
    FAIL=1
    return
  fi
  local ref
  ref="$(ref_hash "$label")"
  if [ -z "$ref" ]; then
    echo "❌ [$label] برچسب در manifest نیست (sha256.txt این ترکیب را ندارد)."
    FAIL=1
    return
  fi
  local got
  got="$(stable_hash "$file")"
  if [ "$got" = "$ref" ]; then
    echo "✅ [$label] مطابقت — $ref"
  else
    echo "❌ [$label] عدم تطابق:"
    echo "     مرجع (تست): $ref"
    echo "     دانلود (UI): $got"
    FAIL=1
  fi
}

# ── پارس آرگومان‌ها: --dir پوشه | LABEL=path ... ────────────────────────
DIR=""
PAIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --dir)
      [ $# -ge 2 ] || { echo "❌ --dir به پوشه نیاز دارد."; usage; exit 1; }
      DIR="$2"; shift 2 ;;
    --help|-h)
      usage; exit 0 ;;
    *=*)
      PAIRS+=("$1"); shift ;;
    *)
      echo "❌ آرگومان ناشناخته: $1 (فرمت درست: LABEL=path)"
      usage; exit 1 ;;
  esac
done

echo "═══ مقایسهٔ دانلود لایو دیزاینر با بایت‌های مرجع (StableHash) ═══"
echo "manifest: $MANIFEST"

# ── حالت ۱: جفت‌های صریح LABEL=path ────────────────────────────────────
if [ ${#PAIRS[@]} -gt 0 ]; then
  for pair in "${PAIRS[@]}"; do
    label="${pair%%=*}"
    file="${pair#*=}"
    case "$label" in
      A4-P|A4-L|A5-P|A5-L) ;;
      *) echo "❌ برچسب نامعتبر: $label (باید A4-P/A4-L/A5-P/A5-L باشد)"; FAIL=1; continue ;;
    esac
    compare_one "$label" "$file"
  done
  [ "$FAIL" -eq 0 ] && echo "✅ همهٔ موارد صریح مطابقت دارند." || echo "❌ حداقل یک مورد مطابقت ندارد."
  exit "$FAIL"
fi

# ── حالت ۲: اسکن خودکار پوشه (جهت از MediaBox) ──────────────────────────
if [ -z "$DIR" ]; then
  echo "❌ یا جفت LABEL=path بده، یا با --dir پوشه‌ای را برای اسکن معرفی کن."
  usage
  exit 1
fi
[ -d "$DIR" ] || { echo "❌ پوشه یافت نشد: $DIR"; exit 1; }

if ! "$PY" -X utf8 -c "import pymupdf" >/dev/null 2>&1; then
  echo "❌ حالت اسکن خودکار به pymupdf نیاز دارد (یا جفت‌های LABEL=path بده)."
  exit 1
fi

seen=""
found_any=0
# نام فایل دیزاینر همیشه توکن کاغذ (A4/A5) را دارد؛ فقط آن‌ها را در نظر بگیر.
for f in "$DIR"/*.pdf; do
  [ -f "$f" ] || continue
  base="$(basename "$f")"
  echo "$base" | grep -qiE "[Aa][45]" || continue
  label="$(pdf_label "$f")"
  rc=$?
  if [ $rc -eq 3 ]; then
    echo "⏭️  pymupdf در اجرای تشخیص در دسترس نبود — این فایل رد شد: $base"
    continue
  fi
  if [ $rc -ne 0 ] || [ -z "$label" ]; then
    echo "⚠️  [$base] ابعاد با هیچ ترکیب مرجع (A4/A5 × عمودی/افقی) نمی‌خورد — رد شد."
    continue
  fi
  found_any=1
  seen="$seen $label"
  compare_one "$label" "$f"
done

if [ "$found_any" -eq 0 ]; then
  echo "❌ هیچ PDFِ منطبق (دارای A4/A5 در نام و ابعاد مرجع) در $DIR پیدا نشد."
  FAIL=1
else
  echo
  echo "ترکیب‌های دیده‌شده:${seen:- —}"
  for missing in A4-P A4-L A5-P A5-L; do
    case " $seen " in
      *" $missing "*) ;;
      *) echo "⚠️  برچسب $missing در این پوشه دیده نشد (اگر دانلود نکرده‌ای طبیعی است)." ;;
    esac
  done
  [ "$FAIL" -eq 0 ] && echo "✅ همهٔ موارد اسکن‌شده مطابقت دارند." || echo "❌ حداقل یک مورد مطابقت ندارد."
fi
exit "$FAIL"