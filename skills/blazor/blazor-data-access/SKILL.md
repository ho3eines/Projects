---
name: blazor-data-access
description: Data access in the single Tarazin Blazor Server app — DbService + named TSQL + Dapper.
category: blazor
tags: [blazor, server, dapper, tsql, named-scripts, schema]
version: 1.0.0
author: Hermes Agent
license: MIT
metadata:
  tarazin:
    tags: [blazor, server, dapper, tsql, named-scripts, schema, db]
    related_skills: [tarazin-project-architecture]
---

# 🔌 Blazor Data Access (DbService + named TSQL)

Replaces the old `blazordeployservice` / `IRequestService` / webapi transport.
All data flows through **named TSQL scripts** executed **in-process** with
Dapper. No HTTP, no encryption envelopes, no tokens.

## When to Use

- Any page that reads or writes data
- Adding a new query/execute script
- Understanding schema boundaries and the cross-schema gate

## Components

| Piece | File | Role |
|---|---|---|
| Script store | `Services/ScriptCatalog.cs` | loads `Data/Scripts/{schema}/{Name}.sql` at startup |
| Executor | `Services/DbService.cs` | `QueryAsync<T>` / `QueryFirstOrDefaultAsync<T>` / `ExecuteAsync` / `ScalarAsync` |
| Scripts | `Data/Scripts/{schema}/*.sql` | the data layer (report-first) |
| Models | `Models/*.cs` | Dapper result shapes (ADR-003) |

## API

```csharp
await Db.QueryAsync<T>(schema, scriptName, params);
await Db.QueryFirstOrDefaultAsync<T>(schema, scriptName, params);
await Db.ExecuteAsync(schema, scriptName, params);          // → rows affected
await Db.ScalarAsync(schema, scriptName, params);           // → object?
```

`DbService` opens a connection per call (`DefaultConnection` → `TarazinMaster`),
maps results by column-name → property-name, and throws if the script name is
missing from the catalog (typo = loud failure).

## Script conventions

```sql
-- TarazinApp/Data/Scripts/{schema}/{Name}.sql
-- Cross-schema: central        ← only if you must read another schema
SELECT ... FROM [{schema}].[Table] t
WHERE t.Column = @Param AND t.IsDeleted = 0
ORDER BY t.Id DESC;
```

- Fully qualified `[schema].[table]` — never `dbo` by accident.
- Parameters only via `@Name` (Dapper) — never concatenation.
- `_Ensure.sql` (DDL) and `_Seed.sql` (data) are idempotent and run at startup.
- Reads filter `IsDeleted = 0`.

## Schema boundary

- Pages/modules call only their own schema.
- Server-side scripts may read other schemas ONLY with a
  `-- Cross-schema: x, y` header comment.
- `tools/cross-schema-scan.sh` fails the build on undocumented cross-schema refs.

## Examples

```csharp
// query
var docs = (await Db.QueryAsync<DailyDocumentRow>("accounting", "DailyDocuments",
    new { FromDate = from, ToDate = to, SearchText = q, DocumentType = (string?)null,
          SkipRows = 0, TakeSize = 100 })).ToList();

// execute with JSON payload (journal lines)
await Db.ExecuteAsync("accounting", "DocumentInsert",
    new { LinesJson = json, DocumentDate = date, DocumentType = t, CounterPartyName = p, CreatedBy = user });

// scalar
var count = Convert.ToInt32(await Db.ScalarAsync("central", "UserCount"));
```

## Pitfalls

- Don't `SELECT *` into a model you don't fully control — alias columns to the
  model property names (`l.Title AS AccountTitle`).
- Don't hard-code connection strings in pages — `DbService` owns it.
- Don't cache `ScriptCatalog` entries per-request — it's a singleton loaded once.
- DateTime params: SQL Server `date` columns accept `DateTime`; cast in SQL when
  you only need the date part (`CAST(@MovementDate AS DATE)`).
