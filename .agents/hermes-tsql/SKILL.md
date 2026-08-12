---
name: hermes-tsql
description: "THE only data-access skill for Hermes. When the user wants a new entity, module, report, CRUD, query, insert, update, delete, TSQL script, schema, SystemController, or any server communication in this repo. Triggers: اسکریپت، TSQL، entity جدید، سند، گزارش، query, execute, scalar, webapi, schema, DailyDocuments, ISystemApi. NEVER use server-client-comm, ICommunicationService, WebSocket, per-project controllers, or raw SQL via RequestService."
---

# hermes-tsql — Named TSQL is the only data path

Hermes is a modular ERP: every product is a **client-only Blazor WASM** app. All data goes through **one** WebAPI that runs **named TSQL files**. There is no other backend.

```
central-client ──(login, token in URL)──► accounting / inventory / store
        │                                         │
        └──────────────► webapi ◄─────────────────┘
                            │
              1) POST /api/auth/handshake   (ProjectGuid)
              2) POST /api/Data/            (AES + named script)
                            │
              Data/Scripts/{schema-from-guid}/{Name}.sql
                            │
              SQL Server  [schema].[Table]
```

Load this skill for **any** data work. Do **not** load `server-client-comm`.

---

## Golden rules

1. **No per-project API.** Never add a controller under `accounting/`, `central-client/`, or a new `{Entity}Controller`.
2. **No raw SQL from the client.** Never call `IRequestService.Request(sql, …)` or `ISqlService.Insert/Select/Update/Delete` for Hermes business data.
3. **No WebSocket / auto-CRUD / BusinessService / Dapper query classes.** That is Pdd.ir (`server-client-comm`). Not this repo.
4. **Named script only.** Client calls `IRequestService.Request(scriptName, param)`. Server runs handshake (`ProjectGuid`) first, then the script. Schema is forced from the project registry.
5. **Schema = project name.** Tables live in `[accounting].…`, `[central].…`, etc.
6. **UI stack:** HTML + Bootstrap 5.3 + BDS components. No MudBlazor / Radzen / Tailwind / shadcn.
7. **Reports first.** Before a new module, list the reports, then design tables/scripts around them.
8. **Do not ask the user to re-explain this structure.**

---

## Endpoints clients use

| Step | Method | URL | Who |
|------|--------|-----|-----|
| 1 | POST | `/api/auth/handshake` | `RequestService` (automatic, cached) |
| 2 | POST | `/api/Data/` | `RequestService` after session exists |

`/api/system/*` is the internal executor. Clients do **not** call it (plaintext + JWT).

Legacy table (server-side executor only):

| Method | URL | Script kind | Returns |
|--------|-----|-------------|---------|
| POST | `/api/system/query` | SELECT | `{ requestId, totalCount, data: [...] }` |
| POST | `/api/system/execute` | INSERT / UPDATE / DELETE / DDL | `{ requestId, affectedRows }` |
| POST | `/api/system/scalar` | single value (`SELECT COUNT`, next number, …) | `{ requestId, value }` |

Payload (`Share.Models.SystemRequestPayload`):

```json
{
  "scriptName": "DailyDocuments",
  "schema": "accounting",
  "parameters": {
    "FromDate": "2026-08-12",
    "ToDate": "2026-08-12",
    "SearchText": "",
    "DocumentType": null,
    "SkipRows": 0,
    "TakeSize": 20
  },
  "requestId": "guid"
}
```

### Path resolution (`SystemQueryExecutor.ResolveScriptPath`)

Tried in order:

1. `ScriptName` with `.` or `\` rewritten to `/` → `Data/Scripts/{parts}.sql`  
   e.g. `accounting/DailyDocuments` or `accounting.DailyDocuments`
2. `Data/Scripts/{Schema}/{ScriptName}.sql`  
   e.g. Schema=`accounting`, ScriptName=`DailyDocuments`
3. `Data/Scripts/{ScriptName}.sql`

**Preferred call shape:** `ScriptName = "DailyDocuments"`, `Schema = "accounting"`.

Parameters arrive as JSON object and become Dapper `@Name` parameters. Use **only** `@Param` in SQL — never string-concat user input.

---

## Client call (always `IRequestService` — Hermes protocol)

Handshake is automatic: first `Request()` asks for a session with `ProjectGuid`, then sends the named script encrypted.

```razor
@inject IRequestService Request
@inject IAlertService Alert

@code {
    List<DailyDocumentRow> Rows = new();

    async Task LoadAsync()
    {
        Rows = await Request.Request<DailyDocumentRow>(
            "DailyDocuments",
            new {
                FromDate = DateTime.Today,
                ToDate = DateTime.Today,
                SearchText = "",
                DocumentType = (string?)null,
                SkipRows = 0,
                TakeSize = 20
            }) ?? new();
    }

    async Task SaveAsync()
    {
        await Request.Request<object>("DocumentInsert",
            new { DocumentNumber = "1", TotalAmount = 0m },
            isExec: true);
        await Alert.ShowSuccessAsync("ثبت شد", "سند ذخیره شد");
    }
}
```

Config (`wwwroot/appsettings.json`):

```json
"BlazorDeploy": {
  "ApiSettings": {
    "BaseUrl": "https://localhost:65222/api/",
    "Protocol": "Hermes",
    "ProjectGuid": "<same guid as webapi Hermes:Projects>",
    "Encryption": "<same SharedKey as that project>"
  }
}
```

Schema is **not** sent by the client. The server binds schema from ProjectGuid.

Do **not** use `ISystemApi` for data (plaintext). User login token (later) still travels `?token=` from central-client.

---

## Adding a feature (the only checklist)

### 0. Reports first (new module)

Write the report list in chat or `docs/` before any table. Models follow reports, not the other way around.

### 1. DTO / row model

- Shared across clients → `share/common/Models/{Name}.cs`
- Project-only → `{project}/Models/{Name}.cs`
- Inherit `BaseEntity` when the table has audit columns (`CreatedAt`, `UpdatedAt`, `CreatedBy`, `UpdatedBy`, `IsDeleted`)
- Property names **match SQL column aliases** (`DocumentId`, not `document_id`)

### 2. Named TSQL files

`webapi/Data/Scripts/{schema}/{ScriptName}.sql`

| Kind | Name pattern | Endpoint |
|------|--------------|----------|
| List / grid | `{Thing}s`, `DailyDocuments`, `{Thing}Search` | query |
| One row | `{Thing}ById` | query |
| Insert | `{Thing}Insert` | execute |
| Update | `{Thing}Update` | execute |
| Soft delete | `{Thing}Delete` | execute (`IsDeleted = 1`) |
| Scalar | `{Thing}NextNumber`, `{Thing}Count` | scalar |
| DDL / ensure | `_{Thing}Ensure` (leading underscore) | execute |

Qualify every table: `[accounting].[Documents]`.

Pagination (copy `DailyDocuments.sql` — **do not** mix `TOP` with `OFFSET`):

```sql
WHERE ...
ORDER BY d.DocumentDate DESC, d.DocumentNumber DESC
OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY;
```

Search: `(@SearchText = '' OR col LIKE '%' + @SearchText + '%')` — still parameterized.

### 3. Client page (4 folders only)

```
{project}/
  Pages/
    Index.razor                 ← home: از تاریخ / تا تاریخ (default today) + daily grid
    Dashboard.razor             ← summary of all sections
    Entry/                      ← ورود عملیات
    SpecialOperations/          ← عملیات ویژه (سال مالی، …)
    Reports/                    ← گزارشات
    Settings/                   ← جداول پایه + امکانات
  Shared/Components/
  Models/                       ← project-only DTOs
```

Home page **must** have FromDate/ToDate (default today) and a clickable daily grid.

### 4. UI

- Bootstrap 5.3 + existing BDS: `Modal`, `SearchableList`, `PersianDatePicker`, `BootstrapNumericInput`, `IAlertService`, `IModalService`, `IThemeService`, `ICultureService`
- Modal-first for simple CRUD; Page + modal for reports / big grids
- Skeleton for page load, not `spinner-border` (spinner only on the save button)
- Visible `<label>` on every field; `PersianDatePicker` binds `long?` Unix — convert with `ISqlService.UnixTimeToPersian` / `DateTimeToUnixTime` **only as helpers**, never for CRUD
- No new NuGet UI kits

### 5. Auth

- Do not invent a second login
- Token from central-client URL → `ISystemApi`
- `SystemController` is `[Authorize]`; unauthenticated calls return 401

---

## Script header (required)

```sql
-- =============================================
-- webapi/Data/Scripts/accounting/DocumentById.sql
-- Schema: accounting
-- Endpoint: query
-- Params: @Id INT
-- =============================================
SELECT ...
FROM [accounting].[Documents] d
WHERE d.DocumentId = @Id
  AND d.IsDeleted = 0;
```

---

## What BDS is for (and what it is not)

| Use | Do not use for Hermes data |
|-----|----------------------------|
| `IRequestService` with **script name** (`Protocol=Hermes`) | `IRequestService.Request("SELECT …")` raw SQL |
| `IModalService`, `IAlertService` | `ISqlService.Insert/Select/Update/Delete` |
| `IThemeService`, `ICultureService` | `ISqlService.InitializeAsync` |
| `IClientStorageService` (prefs) | `ISystemApi` plaintext `/api/system` |
| `IEncryptionService` (handshake) | BlazorDeploy.ir `Protocol=BlazorDeploy` against Hermes |

With `Protocol=Hermes`, `RequestService` talks to **this** webapi (`auth/handshake` + `Data/`). Leave `Protocol=BlazorDeploy` only for BlazorDeploy.ir apps.

---

## Current repo map (do not reinvent)

| Path | Role |
|------|------|
| `webapi/Controllers/AuthController.cs` | ProjectGuid handshake |
| `webapi/Controllers/DataController.cs` | Encrypted named-script runner |
| `webapi/Services/SystemQueryExecutor.cs` | Load + Dapper-run named files |
| `webapi/Data/Scripts/{schema}/*.sql` | All TSQL |
| `webapi/appsettings.json` → `Hermes:Projects` | ProjectGuid registry |
| `blazordeployservice/Services/RequestService.cs` | Client transport |
| `docs/SECURITY.md` | Gap review |
| `central-client/` | Login, company site, users, widgets |
| `accounting/` | Accounting WASM client |
| `docs/PROJECT.md` | Project law |

---

## References

- `references/scripts.md` — naming, pagination, DDL, DailyDocuments
- `references/client.md` — `ISystemApi`, token, page patterns
- `references/forbidden.md` — exact anti-patterns (including server-client-comm)
