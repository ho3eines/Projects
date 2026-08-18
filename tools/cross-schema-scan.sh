#!/usr/bin/env bash
# ============================================================
# Cross-schema static analysis (PRD AC #3 / ADR-003)
#
# Every .sql script under Tarazin.Data/Scripts/{schema}/ may only
# reference its own schema — unless the reference is declared in a
# header comment:
#
#     -- Cross-schema: inventory, central
#
# Exit code 1 on any undocumented cross-schema reference.
# ============================================================
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$ROOT/Tarazin.Data/Scripts"

fail=0
count=0

while IFS= read -r -d '' f; do
    count=$((count + 1))
    schema="$(basename "$(dirname "$f")")"

    # Referenced schemas: [name]. Ignore line comments so examples such as
    # [schema].[table] in prose do not create phantom dependencies.
    refs="$(sed -E 's/--.*$//' "$f" \
        | grep -oE '\[[a-zA-Z_][a-zA-Z0-9_]*\]\.' \
        | sed -E 's/^\[([^]]+)\]\.$/\1/' \
        | sort -u || true)"

    # Declared allow-list from header.
    allowed="$(grep -m1 -E '^--[[:space:]]*Cross-schema:' "$f" \
        | sed -E 's/^--[[:space:]]*Cross-schema:[[:space:]]*//' \
        | tr ',' ' ' || true)"

    for ref in $refs; do
        if [ "$ref" = "$schema" ]; then
            continue
        fi
        if echo "$allowed" | grep -qw "$ref"; then
            continue
        fi
        echo "VIOLATION: $f references [$ref]. — add header '-- Cross-schema: $ref'"
        fail=1
    done
done < <(find "$SCRIPTS" -name '*.sql' -print0)

echo "Scanned $count script(s) under $SCRIPTS"
if [ "$fail" -eq 1 ]; then
    echo "Cross-schema scan FAILED (PRD AC #3)"
    exit 1
fi
echo "Cross-schema scan OK — no undocumented cross-schema references"
