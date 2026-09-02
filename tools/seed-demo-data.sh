#!/usr/bin/env bash
# =============================================================
# seed-demo-data.sh — One-command demo-data seed for Tarazin.
#
# Runs the sample-data SQL scripts (in the right order) against
# a live SQL Server, using the SAME connection convention as the
# test suite / CI (TARAZIN_TEST_CONN), and the same -I flag that
# the CI discovered is mandatory (QUOTED_IDENTIFIER ON for the
# filtered indexes used by several _Ensure schemas).
#
# Order matters:
#   1. sample-inventory-treasury.sql  — inventory + treasury + cheque
#   2. sample-gold-receipt.sql        — GOLD-24 FIFO layers (prerequisite)
#   3. sample-gold-invoice.sql        — gold invoice consuming those layers
#
# Usage:
#   bash tools/seed-demo-data.sh                     # defaults
#   bash tools/seed-demo-data.sh --force             # seed even if already done
#   bash tools/seed-demo-data.sh --company 6 --fiscal-year 12
#   TARAZIN_TEST_CONN="Server=...;..." bash tools/seed-demo-data.sh
#
# Exit code: 0 = ok, 1 = failure (or already seeded without --force).
# =============================================================
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

COMPANY_ID=3          # active demo company (documented in tools/README.md)
FISCAL_YEAR_ID=4      # its active fiscal year 1405
FORCE=0
RESEED=0
# sqlcmd connection — defaults match appsettings.json / TestDb.cs local default
SERVER="localhost"
DB="TarazinMaster"
USER="sa"
PASSWORD="123456"

# ── argument parsing ──────────────────────────────────────────────
usage() {
  cat <<'HELP'
seed-demo-data.sh — One-command demo-data seed for Tarazin.

Runs the sample-data SQL scripts (in the right order) against a live
SQL Server, using the same connection convention as CI (TARAZIN_TEST_CONN)
and the mandatory -I flag (QUOTED_IDENTIFIER ON).

Usage:
  bash tools/seed-demo-data.sh                     # defaults
  bash tools/seed-demo-data.sh --force             # seed even if already done
  bash tools/seed-demo-data.sh --company 6 --fiscal-year 12
  TARAZIN_TEST_CONN="Server=...;..." bash tools/seed-demo-data.sh
HELP
  echo
  echo "Options:"
  echo "  --company <id>        CompanyId to seed into (default 3)"
  echo "  --fiscal-year <id>    FiscalYearId to use (default 4)"
  echo "  --force               run even if seed data already exists"
  echo "  --reseed              delete previous sample data first, then seed fresh"
  echo "  --server <name>       SQL Server (default localhost)"
  echo "  --db <name>           database (default TarazinMaster)"
  echo "  --user <name>         SQL login (default sa)"
  echo "  --password <pw>       SQL password (default 123456)"
  echo "  -h, --help            this help"
  echo
  echo "Env: TARAZIN_TEST_CONN (connection string) overrides --server/--db/--user/--password."
}

while [ $# -gt 0 ]; do
  case "$1" in
    --company)       COMPANY_ID="${2:?--company needs a value}"; shift 2 ;;
    --fiscal-year)   FISCAL_YEAR_ID="${2:?--fiscal-year needs a value}"; shift 2 ;;
    --force)         FORCE=1; shift ;;
    --reseed)        RESEED=1; shift ;;
    --server)        SERVER="${2:?--server needs a value}"; shift 2 ;;
    --db)            DB="${2:?--db needs a value}"; shift 2 ;;
    --user)          USER="${2:?--user needs a value}"; shift 2 ;;
    --password)      PASSWORD="${2:?--password needs a value}"; shift 2 ;;
    -h|--help)       usage; exit 0 ;;
    *) echo "❌ unknown option: $1"; usage; exit 1 ;;
  esac
done

# ── connection: TARAZIN_TEST_CONN wins (CI convention) ─────────────
if [ -n "${TARAZIN_TEST_CONN:-}" ]; then
  # Parse "Key=Value;..." pairs (case-insensitive keys).
  get_cs() { printf '%s' "$TARAZIN_TEST_CONN" | tr ';' '\n' | grep -iE "^[[:space:]]*$1=" | head -1 | sed -E "s/^[[:space:]]*$1=[[:space:]]*//I"; }
  SERVER=$(get_cs "Server");    [ -z "$SERVER" ] && SERVER="localhost"
  DB=$(get_cs "Database");      [ -z "$DB" ] && DB="TarazinMaster"
  USER=$(get_cs "User Id");     [ -z "$USER" ] && USER="sa"
  PASSWORD=$(get_cs "Password"); [ -z "$PASSWORD" ] && PASSWORD="123456"
fi

# ── locate sqlcmd ─────────────────────────────────────────────────
find_sqlcmd() {
  local c
  for c in \
    "/c/Program Files/Microsoft SQL Server/Client SDK/ODBC/170/Tools/Binn/sqlcmd.exe" \
    "/c/Program Files/Microsoft SQL Server/150/Tools/Binn/sqlcmd.exe" \
    "/c/Program Files/Microsoft SQL Server/Client SDK/ODBC/130/Tools/Binn/sqlcmd.exe" \
    "$(command -v sqlcmd 2>/dev/null)"; do
    [ -n "$c" ] && [ -x "$c" ] && { echo "$c"; return 0; }
  done
  return 1
}

SQLCMD="$(find_sqlcmd)" || { echo "❌ sqlcmd not found. Install SQL Server tools or pass its path."; exit 1; }
echo "🧰 sqlcmd: $SQLCMD"
echo "🎯 target: $SERVER / $DB  (CompanyId=$COMPANY_ID, FiscalYearId=$FISCAL_YEAR_ID)"

run_sql() {
  "$SQLCMD" -S "$SERVER" -U "$USER" -P "$PASSWORD" -d "$DB" -I -b -f 65001 \
    -v CompanyId="$COMPANY_ID" -v FiscalYearId="$FISCAL_YEAR_ID" \
    -i "$1"
}

step() { echo; echo "══════ $1 ══════"; }
pass() { echo "✅ $1"; }
fail() { echo "❌ $1"; FAIL=1; }

# ── idempotency guard ─────────────────────────────────────────────
ALREADY="$("$SQLCMD" -S "$SERVER" -U "$USER" -P "$PASSWORD" -d "$DB" -I -h -1 \
  -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM [treasury].[Cheques] WHERE ChequeNumber = N'CHQ-SAMPLE-001';" 2>/dev/null | tr -d '[:space:]')"
if [ "${ALREADY:-0}" != "0" ]; then
  if [ "$RESEED" -eq 1 ]; then
    echo "⚠  Seed data present — --reseed given, cleaning old sample data first."
    step "۰) پاک‌سازی داده‌های نمونهٔ قبلی (seed-cleanup)"
    if run_sql "tools/seed-cleanup.sql"; then
      pass "old sample data removed"
    else
      fail "seed-cleanup.sql failed (aborting, nothing reseeded)"
      exit 1
    fi
  elif [ "$FORCE" -eq 0 ]; then
    echo "⚠  Seed data already present (cheque CHQ-SAMPLE-001 exists)."
    echo "   Re-running would duplicate rows. Use --reseed to clean+reseed, or --force to run anyway."
    exit 1
  else
    echo "⚠  Seed data already present — --force given, seeding again (duplicates possible)."
  fi
fi

# ── run the three scripts in order ────────────────────────────────
FAIL=0

step "۱) انبار + خزانه + چک"
if run_sql "tools/sample-inventory-treasury.sql"; then
  pass "movements/treasury/cheque inserted"
else
  fail "sample-inventory-treasury.sql failed"
fi

step "۲) رسید طلای ۲۴ (لایه‌های FIFO برای فاکتور)"
if run_sql "tools/sample-gold-receipt.sql"; then
  pass "GOLD-24 receipt inserted"
else
  fail "sample-gold-receipt.sql failed"
fi

step "۳) فاکتور فروش طلا"
if run_sql "tools/sample-gold-invoice.sql"; then
  pass "gold invoice inserted"
else
  fail "sample-gold-invoice.sql failed"
fi

echo
echo "══════════════════════════════════════════"
if [ "$FAIL" -eq 0 ]; then
  echo "✅ Demo data seeded — refresh the UI to see it."
  exit 0
else
  echo "❌ One or more steps failed (see above)."
  exit 1
fi
