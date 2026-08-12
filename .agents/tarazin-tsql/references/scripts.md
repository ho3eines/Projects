# tarazin-tsql — Scripts

## File location

```
Tarazin.Data/Scripts/
  accounting/
    _Ensure.sql          ← DDL (schemas/tables), runs at startup
    _Seed.sql            ← idempotent seed data, runs at startup
    DailyDocuments.sql   ← main-page grid
    DocumentInsert.sql   ← journal entry (OPENJSON @LinesJson)
    ChartOfAccountSearch.sql / ChartOfAccountUpsert.sql
    DailyBookReport.sql / GeneralLedgerReport.sql / TrialBalanceReport.sql
    DocumentPeriodClose.sql
  central/
    _Ensure.sql / _Seed.sql
    UserAuthenticate.sql / UserUpsert.sql / UserList.sql / UserCount.sql
    AuditInsert.sql / AuditLastRowHash.sql / AuditSearch.sql
    NewsList.sql / NewsUpsert.sql / BlogList.sql / BlogUpsert.sql
    GalleryList.sql / GalleryUpsert.sql / PartySearch.sql / PartyUpsert.sql
  inventory/  treasury/  payroll/  goldshop/  store/
    ... (same pattern)
```

**Embedded**: these files are compiled into `Tarazin.Data` as resources named
`Tarazin.Scripts.{schema}.{name}.sql`; `ScriptCatalog` self-loads them, so
both hosts (web + MAUI) work without a content root. The on-disk files remain
the source of truth for editing and for `tools/cross-schema-scan.sh`.

Schema folder name = SQL schema name = module id.

## Resolver (source of truth)

`ScriptCatalog` (startup): key = `{schema}/{scriptName}` (case-insensitive),
value = file text. `DbService.Resolve(schema, name)` throws if missing — a typo
is caught immediately, not silently.

## Parameter binding

Dapper binds an anonymous object's properties to `@Name` parameters. Script
parameters are declared implicitly by usage:

| C# | Dapper/SQL |
|----|------------|
| `DateTime` | `datetime2` (or cast in SQL: `CAST(@MovementDate AS DATE)`) |
| `string` | `nvarchar` |
| `int`/`decimal` | `int` / `decimal` |
| `null` (typed `(int?)null`) | `NULL` — script must handle `@P IS NULL` |

## Conventions

- Every SELECT returns columns aliased to the C# model property names
  (ADR-003). Example: `l.Title AS AccountTitle`.
- `IsDeleted = 0` filters on reads; soft-delete via update, not hard delete.
- `_Ensure.sql` is idempotent: `IF NOT EXISTS (… sys.schemas …) CREATE SCHEMA`,
  `IF NOT EXISTS (… sys.tables …) CREATE TABLE`.
- `_Seed.sql` is idempotent: guard every INSERT with `IF NOT EXISTS (SELECT 1 …)`.
- Cross-schema reads require the header `-- Cross-schema: <schema>, …`
  (checked by `tools/cross-schema-scan.sh`).
