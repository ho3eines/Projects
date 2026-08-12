---
name: tarazin-tsql
description: "THE Tarazin architecture + data skill. Use for any entity, TSQL, module, schema, DbService, named script, login, session, audit, or how modules talk to the database. NEVER use HttpClient-for-data, raw SQL in pages, per-module controllers, webapi, WASM clients, or the old BlazorDeployService transport."
---

# tarazin-tsql — Architecture & data (v2.1: Blazor Hybrid)

This file is the **source of truth** for how Tarazin is built and how every
module reads/writes data. Load it for any data, auth, or new-module work.

---

## 1. What Tarazin is (v2.2)

Five projects with one-way dependencies (`Share ← Data ← Ui ← hosts`):

- `Tarazin.Share/` — models/contracts only (namespace `Tarazin.Models`)
- `Tarazin.Data/` — data layer: `DbService`, `ScriptCatalog`, `AuditService`,
  `PasswordHasher`, `ICurrentUser`, `TarazinDbInitializer` + embedded scripts
- `Tarazin.Ui/` — Razor Class Library (UI): modules, layout, `UserSession`,
  `AuthService`, `AddTarazinUiServices`
- `Tarazin.Web/` — Blazor Server host (browser)
- `Tarazin.Maui/` — MAUI Blazor Hybrid host (BlazorWebView, native)

UI is **MudBlazor**. Data access is **Dapper over named TSQL scripts** executed
**in the same process** — there is **no webapi, no WASM, no HTTP data layer**.
Scripts are **embedded resources** in `Tarazin.Data` so both hosts work
without any content root.

```
┌──────────────────────────────────────────────────────────────┐
│ Tarazin.Share (models)                                       │
│ Tarazin.Data (DbService + ScriptCatalog + embedded scripts)  │
│ Tarazin.Ui (RCL — Modules/ Layout/ Services/)                │
│   Modules/{Name}/Pages/*.razor  (MudBlazor UI)                │
│        │ DbService.QueryAsync<T>(schema, script)              │
│   Scripts/{schema}/{Name}.sql (embedded in Data) ── Dapper ─┐ │
└─────────────────────────────────────────────────────────────┼──┘
        host: Tarazin.Web (Blazor Server) / Tarazin.Maui (WebView) ▼
        SQL Server — TarazinMaster (one DB, one schema per product)
        [central] [accounting] [inventory] [treasury]
        [payroll] [goldshop] [store]
```

## 2. Modules (7)

| Module | Route prefix | Schema |
|---|---|---|
| Central (پلتفرم مشترک) | `/central` | `central` |
| Accounting (حسابداری) | `/accounting` | `accounting` |
| Inventory (انبار آمل) | `/inventory` | `inventory` |
| Treasury (خزانه‌داری) | `/treasury` | `treasury` |
| Payroll (حقوق و دستمزد) | `/payroll` | `payroll` |
| GoldShop (طلافروشی) | `/goldshop` | `goldshop` |
| Store (فروشگاه) | `/store` | `store` |

Each module = 6 pages: home (روزانه), dashboard, entry, reports, special, settings.

## 3. Data protocol (all modules, same)

```csharp
@inject DbService Db

// query  → List<T>
var rows = await Db.QueryAsync<DailyDocumentRow>("accounting", "DailyDocuments",
    new { FromDate, ToDate, SearchText = "", DocumentType = (string?)null, SkipRows = 0, TakeSize = 100 });

// execute → int (rows affected)
await Db.ExecuteAsync("accounting", "DocumentInsert", new { LinesJson, ... });

// scalar  → object?
var count = await Db.ScalarAsync("central", "UserCount");
```

- **Script name only** — the resolver is `ScriptCatalog`, which loads embedded
  resources `Tarazin.Scripts.{schema}.{Name}.sql` from `Tarazin.Ui`
  (self-loading singleton). Never write inline SQL in a page.
- **Schema = scope guard** — a module only calls scripts of its own schema.
  Server-side scripts may read other schemas only with a
  `-- Cross-schema: x, y` header (enforced by `tools/cross-schema-scan.sh`).
- All scripts are **fully qualified**: `[accounting].[Documents]`, never `dbo`.
- Dapper parameterization (`@Name`) — no string concatenation.

## 4. Auth & session

- Login: `/login` → `AuthService.AuthenticateAsync(user, pass)` against
  `[central].[Users]` (PBKDF2). No tokens, no URL parameters, no handshake.
- Web: `UserSession` is per SignalR circuit (scoped).
- MAUI: same services, but scoped ≈ app-wide singleton (single-user app).
- Session: `UserSession` (scoped per circuit) — `IsAuthenticated`,
  `DisplayName`, `Role`, `IsAdmin`, `SignIn/SignOut`.
- Bootstrap admin `admin`/`admin` is created at startup only when `Users` is empty.

## 5. Audit

**Automatic** — every `DbService.ExecuteAsync(...)` records an audit row
(success or failure) into `[central].[AuditLog]` with a SHA-256
`PrevHash`/`RowHash` chain. No manual call needed in pages.

```csharp
// happens automatically inside DbService.ExecuteAsync:
//   _audit.RecordAsync(schema, scriptName, user, "Success"|"Error", error)
```

View at `/central/audit`. Parameters are never stored (they may contain
sensitive data). Audit failures are logged, never thrown.

## 6. Startup order

`TarazinDbInitializer.EnsureInitializedAsync(services)` (shared):
`DbService.EnsureSchemaAsync` (all `_Ensure.sql`) → `DbService.SeedAsync`
(all `_Seed.sql`) → bootstrap admin. Web: called in `Program.cs` before
`app.Run()`. MAUI: called from the shared `App.razor` OnInitializedAsync.
Interlocked guard makes it run exactly once.

## 7. Rules when adding a new module

1. Research the domain's reports first (report-first).
2. `Tarazin.Share/Models/{Module}Models.cs` — models matching script columns (ADR-003).
3. `Tarazin.Data/Scripts/{schema}/_Ensure.sql` (+ `_Seed.sql`) — idempotent DDL/data.
4. Pages under `Tarazin.Ui/Modules/{Name}/Pages/` with MudBlazor only.
5. Add NavMenu entry + Home launcher card.
6. Run `tools/cross-schema-scan.sh` before committing.
7. The result automatically appears in BOTH hosts (web + MAUI).
