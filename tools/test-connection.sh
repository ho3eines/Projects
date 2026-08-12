#!/usr/bin/env bash
# ============================================================
# تست سریع رشتهٔ اتصال — بدون اجرای برنامه.
#
# چرا: وقتی برنامه خطای اتصال می‌دهد، اول باید مطمئن شویم خودِ
# SQL Server بالا و در دسترس است. این اسکریپت با sqlcmd داخل
# کانتینر mssql یک «SELECT 1» می‌زند.
#
# استفاده:
#   bash tools/test-connection.sh                 # با مقادیر پیش‌فرض docker-compose
#   MSSQL_SA_PASSWORD='...' bash tools/test-connection.sh
#   TARAZIN_SQL_HOST=localhost TARAZIN_SQL_PORT=1433 bash tools/test-connection.sh
# ============================================================
set -uo pipefail

HOST="${TARAZIN_SQL_HOST:-localhost}"
PORT="${TARAZIN_SQL_PORT:-1433}"
USER="${TARAZIN_SQL_USER:-sa}"
PASS="${MSSQL_SA_PASSWORD:-Tarazin!Master2026}"
DB="${TARAZIN_SQL_DB:-TarazinMaster}"

echo "──────────────────────────────────────────────"
echo " تست اتصال ترازین"
echo " سرور    : ${HOST},${PORT}"
echo " کاربر   : ${USER}"
echo " دیتابیس : ${DB}"
echo "──────────────────────────────────────────────"

# ۱) پورت باز است؟
if command -v nc >/dev/null 2>&1; then
    if nc -z -w 3 "$HOST" "$PORT" 2>/dev/null; then
        echo "✅ پورت ${PORT} باز است."
    else
        echo "❌ پورت ${PORT} روی ${HOST} بسته است."
        echo "   → کانتینر را بالا بیاورید:  docker compose up -d"
        exit 1
    fi
else
    echo "ℹ️  ابزار nc نصب نیست؛ از تست پورت صرف‌نظر شد."
fi

# ۲) لاگین و کوئری
run_sqlcmd() {
    local q="$1"
    if command -v sqlcmd >/dev/null 2>&1; then
        sqlcmd -S "${HOST},${PORT}" -U "$USER" -P "$PASS" -C -b -h -1 -W -Q "$q"
    elif command -v docker >/dev/null 2>&1; then
        docker compose exec -T mssql bash -lc \
            "/opt/mssql-tools18/bin/sqlcmd -S localhost -U '$USER' -P '$PASS' -C -b -h -1 -W -Q \"$q\" \
             || /opt/mssql-tools/bin/sqlcmd -S localhost -U '$USER' -P '$PASS' -b -h -1 -W -Q \"$q\""
    else
        echo "__NO_TOOL__"
        return 127
    fi
}

out="$(run_sqlcmd 'SELECT 1' 2>&1)"
rc=$?

if [[ "$out" == "__NO_TOOL__" ]]; then
    echo "❌ نه sqlcmd نصب است و نه docker در دسترس؛ تست کوئری ممکن نشد."
    exit 2
fi

if [[ $rc -ne 0 ]]; then
    echo "❌ لاگین/کوئری ناموفق:"
    echo "$out" | sed 's/^/   /'
    echo "   → رمز sa را با MSSQL_SA_PASSWORD در docker-compose.yml مقایسه کنید."
    exit 1
fi

echo "✅ لاگین موفق (SELECT 1)."

# ۳) دیتابیس مقصد وجود دارد؟
exists="$(run_sqlcmd "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'${DB}'" 2>&1 | tr -d '[:space:]')"
if [[ "$exists" == "1" ]]; then
    echo "✅ دیتابیس ${DB} موجود است."
else
    echo "ℹ️  دیتابیس ${DB} هنوز ساخته نشده — برنامه در اولین اجرا خودش می‌سازد (EnsureDatabaseAsync)."
fi

echo "──────────────────────────────────────────────"
echo "رشتهٔ اتصال معادل:"
echo "Server=${HOST},${PORT};Database=${DB};User Id=${USER};Password=***;TrustServerCertificate=True;Encrypt=False"
