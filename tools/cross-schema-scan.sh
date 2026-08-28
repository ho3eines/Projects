#!/usr/bin/env bash
# cross-schema-scan.sh — Validates that no SQL script accesses a foreign schema.
# Usage: bash tools/cross-schema-scan.sh
# Exit code: 0 = pass, 1 = violations found.

set -uo pipefail

SCRIPTS_DIR="Tarazin.Data/Scripts"
VIOLATIONS=0

# Known project schemas
KNOWN_SCHEMAS="accounting assets bi branch central currency goldshop inventory payroll store treasury"

if [ ! -d "$SCRIPTS_DIR" ]; then
  echo "ERROR: $SCRIPTS_DIR not found. Run from project root."
  exit 2
fi

echo "=== Cross-Schema Scan ==="
echo "Scanning $SCRIPTS_DIR ..."

# Build a single grep pattern for all known schemas: accounting|assets|bi|...
SCHEMA_PATTERN=$(echo "$KNOWN_SCHEMAS" | tr ' ' '|')

for schema_dir in "$SCRIPTS_DIR"/*/; do
  schema=$(basename "$schema_dir")

  # Find all SQL files and grep for cross-schema refs in one pass
  matches=$(grep -rnEi "(FROM|JOIN|INTO|UPDATE|DELETE\s+FROM)\s+(${SCHEMA_PATTERN})\." "$schema_dir" 2>/dev/null || true)

  if [ -n "$matches" ]; then
    while IFS= read -r match; do
      [ -z "$match" ] && continue

      filename=$(echo "$match" | cut -d: -f1 | xargs basename)
      line_num=$(echo "$match" | cut -d: -f2)
      line_content=$(echo "$match" | cut -d: -f3-)

      # Skip comment lines
      [[ "$line_content" =~ ^[[:space:]]*-- ]] && continue

      # Extract schema.table references and check each
      refs=$(echo "$line_content" | grep -oEi "\b(${SCHEMA_PATTERN})\.[A-Za-z_][A-Za-z0-9_]*" || true)
      while IFS= read -r ref; do
        [ -z "$ref" ] && continue
        ref_schema=$(echo "$ref" | cut -d. -f1 | tr '[:upper:]' '[:lower:]')
        ref_table=$(echo "$ref" | cut -d. -f2)

        # Skip own schema
        [ "$ref_schema" = "$schema" ] && continue

        echo "VIOLATION: $schema/$filename:$line_num references $ref_schema.$ref_table"
        VIOLATIONS=$((VIOLATIONS + 1))
      done <<< "$refs"
    done <<< "$matches"
  fi
done

echo ""
echo "=== Scan Complete ==="

if [ "$VIOLATIONS" -gt 0 ]; then
  echo "FAILED: $VIOLATIONS cross-schema violation(s) found."
  exit 1
else
  echo "PASSED: No cross-schema violations."
  exit 0
fi
