# hermes-tsql — Scripts

## File location

```
webapi/Data/Scripts/
  accounting/
    DailyDocuments.sql      ← exists
    DocumentById.sql
    DocumentInsert.sql
    DocumentUpdate.sql
    DocumentDelete.sql
    DocumentNextNumber.sql
    _DocumentsEnsure.sql
  central/
    ...
```

Schema folder name = SQL schema name = project id (`accounting`, `central`, `inventory`, `store`).

## Resolver (source of truth)

`webapi/Services/SystemQueryExecutor.cs`:

1. `scriptName` with `\` and `.` → `/` then `Data/Scripts/{that}.sql`
2. else `Data/Scripts/{schema}/{scriptName}.sql`
3. else `Data/Scripts/{scriptName}.sql`
4. else `FileNotFoundException`

Always pass `Schema` from the client so (2) wins.

## Parameter binding

`BuildParameters` only understands a JSON **object**:

| JSON | Dapper |
|------|--------|
| string | string |
| number (fits int64) | long |
| other number | double |
| true/false | bool |
| null | null |
| array/object | raw JSON text (avoid — flatten instead) |

Name parameters exactly as `@FromDate`, `@TakeSize`, … in SQL. Missing params throw at SQL Server — validate on the client first.

## Pagination & filter (home grid)

Canonical param set (from `DailyDocuments.sql`):

| Param | Role |
|-------|------|
| `@FromDate` / `@ToDate` | inclusive range, default today |
| `@SearchText` | `''` means no text filter |
| `@DocumentType` | NULL means all |
| `@SkipRows` | `(page - 1) * pageSize` |
| `@TakeSize` | page size |

```sql
WHERE d.DocumentDate BETWEEN @FromDate AND @ToDate
  AND (@SearchText = '' OR d.DocumentNumber LIKE '%' + @SearchText + '%'
       OR d.CounterPartyName LIKE '%' + @SearchText + '%')
  AND (@DocumentType IS NULL OR d.DocumentType = @DocumentType)
ORDER BY d.DocumentDate DESC, d.DocumentNumber DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
```

Do **not** add `SELECT TOP (@TakeSize)` when using `OFFSET/FETCH` (the current `DailyDocuments.sql` has a redundant `TOP` — drop it when you next touch that file).

`query` result `totalCount` is `data.Count` (this page), **not** the full table count. If the grid needs a real total, add a sibling scalar script `{Thing}Count` with the same filters.

## Soft delete

`BaseEntity.IsDeleted`. Deletes are `UPDATE … SET IsDeleted = 1`. Every list script filters `IsDeleted = 0` (or `d.IsDeleted = 0`).

## Audit columns

Match `BaseEntity`:

```sql
CreatedAt  DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
UpdatedAt  DATETIME2 NULL,
CreatedBy  NVARCHAR(100) NULL,
UpdatedBy  NVARCHAR(100) NULL,
IsDeleted  BIT NOT NULL DEFAULT 0
```

Pass `@CreatedBy` / `@UpdatedBy` from the signed-in user when you have it.

Dates on **documents** (DocumentDate) are business dates — `DATE` or `DATETIME2` is fine. `PersianDatePicker` uses Unix `long`; convert at the UI edge, do not store Unix unless the column is already `BIGINT`.

## DDL / ensure scripts

Name with leading `_`. Run once from a Settings “initialize” action or a documented setup step. Example:

```sql
-- _DocumentsEnsure.sql  (execute)
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'accounting')
    EXEC('CREATE SCHEMA [accounting]');

IF NOT EXISTS (SELECT 1 FROM sys.tables t
               JOIN sys.schemas s ON t.schema_id = s.schema_id
               WHERE s.name = N'accounting' AND t.name = N'Documents')
BEGIN
    CREATE TABLE [accounting].[Documents] (
        DocumentId        INT IDENTITY(1,1) PRIMARY KEY,
        DocumentNumber    NVARCHAR(50) NOT NULL,
        DocumentDate      DATE NOT NULL,
        DocumentType      NVARCHAR(50) NULL,
        CounterPartyName  NVARCHAR(200) NULL,
        TotalAmount       DECIMAL(18,2) NOT NULL DEFAULT 0,
        CurrencyCode      NVARCHAR(10) NULL,
        Status            NVARCHAR(50) NOT NULL DEFAULT N'Draft',
        CreatedAt         DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
        UpdatedAt         DATETIME2 NULL,
        CreatedBy         NVARCHAR(100) NULL,
        UpdatedBy         NVARCHAR(100) NULL,
        IsDeleted         BIT NOT NULL DEFAULT 0
    );
END
```

Never emit `CREATE TABLE` from the WASM client via `ISqlService.InitializeAsync`.

## Seed (mandatory after every finished part)

File: `webapi/Data/Scripts/{schema}/_Seed.sql`  
Startup runs `_Ensure` then `_Seed` for every active schema.

Rules:

- `IF NOT EXISTS` so it is safe to run on every boot
- Enough rows to click through the UI (today’s date for home-grid scripts)
- No secrets except the documented test user (`admin` / `admin` is created in C#, not in SQL)

```sql
-- _Seed.sql  (execute)
IF NOT EXISTS (SELECT 1 FROM [accounting].[Documents] WHERE DocumentNumber = N'SEED-001')
BEGIN
    INSERT INTO [accounting].[Documents]
        (DocumentNumber, DocumentDate, DocumentType, CounterPartyName, TotalAmount, CurrencyCode, Status, CreatedBy)
    VALUES
        (N'SEED-001', CAST(SYSUTCDATETIME() AS DATE), N'Journal', N'شرکت نمونه', 1500000, N'IRR', N'Draft', N'seed');
END
```

After you finish Entry / Reports / Settings / any new table: update `_Seed.sql` in the same turn. Do not leave the user with empty grids.

## Security in SQL

- Parameterize everything.
- Qualify schema. Do not `USE` another database.
- No `xp_cmdshell`, no dynamic SQL built from user strings. If you must use dynamic SQL, allow-list identifiers and still parameterize values.
- Scripts are files on disk — treat them as code. Review before adding.

## Existing script

`webapi/Data/Scripts/accounting/DailyDocuments.sql` — home-page daily document grid. Columns: `DocumentId`, `DocumentNumber`, `DocumentDate`, `DocumentType`, `CounterPartyName`, `TotalAmount`, `CurrencyCode`, `Status`, `CreatedAt`.
