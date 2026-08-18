#!/usr/bin/env bash
# Local SQL reachability/authentication check. Credentials must be supplied by
# the operator and are never printed or given a source-controlled default.
#
# Usage:
#   MSSQL_SA_PASSWORD='...' bash tools/test-connection.sh
# or, for a non-sa development login:
#   TARAZIN_SQL_USER='...' TARAZIN_SQL_PASSWORD='...' bash tools/test-connection.sh
set -uo pipefail

HOST="${TARAZIN_SQL_HOST:-localhost}"
PORT="${TARAZIN_SQL_PORT:-1433}"
USER="${TARAZIN_SQL_USER:-sa}"
PASS="${TARAZIN_SQL_PASSWORD:-${MSSQL_SA_PASSWORD:-}}"
DB="${TARAZIN_SQL_DB:-TarazinMaster}"

if [[ -z "$PASS" ]]; then
    echo "❌ Set TARAZIN_SQL_PASSWORD (or MSSQL_SA_PASSWORD for the local Compose service)." >&2
    exit 2
fi

# SQL Server identifiers can contain many characters, but this diagnostic only
# needs a normal deployment database name. Restrict it before placing it in the
# metadata query below.
if [[ ! "$DB" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "❌ TARAZIN_SQL_DB contains unsupported characters." >&2
    exit 2
fi

# 1) Is the TCP endpoint reachable?
if command -v nc >/dev/null 2>&1; then
    if ! nc -z -w 3 "$HOST" "$PORT" 2>/dev/null; then
        echo "❌ The configured SQL endpoint is not reachable."
        exit 1
    fi
fi

# 2) Authenticate and run a query. SQLCMDPASSWORD avoids putting the credential
# in sqlcmd's command line. Docker receives it as a one-process environment
# variable rather than interpolating it into a shell command.
run_sqlcmd() {
    local query="$1"
    if command -v sqlcmd >/dev/null 2>&1; then
        SQLCMDPASSWORD="$PASS" sqlcmd \
            -S "${HOST},${PORT}" -U "$USER" -C -b -h -1 -W -Q "$query"
        return
    fi

    if ! command -v docker >/dev/null 2>&1; then
        echo "__NO_TOOL__"
        return 127
    fi

    local tool
    if docker compose exec -T mssql test -x /opt/mssql-tools18/bin/sqlcmd >/dev/null 2>&1; then
        tool=/opt/mssql-tools18/bin/sqlcmd
    else
        tool=/opt/mssql-tools/bin/sqlcmd
    fi

    docker compose exec -T -e SQLCMDPASSWORD="$PASS" mssql "$tool" \
        -S localhost -U "$USER" -C -b -h -1 -W -Q "$query"
}

out="$(run_sqlcmd 'SELECT 1' 2>&1)"
rc=$?
if [[ "$out" == "__NO_TOOL__" ]]; then
    echo "❌ Neither sqlcmd nor Docker is available; the query test could not run."
    exit 2
fi
if [[ $rc -ne 0 ]]; then
    # Do not echo raw driver diagnostics: they may include endpoint/configuration
    # details and are not needed to communicate a failed test.
    echo "❌ SQL authentication or the test query failed."
    exit 1
fi

echo "✅ SQL authentication and SELECT 1 succeeded."

# 3) Check whether the target database exists without printing connection data.
exists="$(run_sqlcmd "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = N'${DB}'" 2>/dev/null | tr -d '[:space:]')"
if [[ "$exists" == "1" ]]; then
    echo "✅ The configured target database exists."
else
    echo "ℹ️  The target database does not exist yet; server-side initialization may create it if authorized."
fi
