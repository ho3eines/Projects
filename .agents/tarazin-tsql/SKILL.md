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

UI is **MudBlazor**. Business-data access is **Dapper over named TSQL scripts**
executed in the current host process — there is no public CRUD Web API or WASM
data layer. The narrow MAUI credential broker is the only security API: it
validates customer/user/company authorization and delivers the SQL connection
string **only in encrypted form** (per-session AES from the bearer token).
Scripts are **embedded resources** in
`Tarazin.Data` so both hosts work without a content root.

```
┌──────────────────────────────────────────────────────────────┐
│ Tarazin.Share (models)                                       │
│ Tarazin.Data (DbService + ScriptCatalog + embedded scripts)  │
│ Tarazin.Ui (RCL — Modules/ Layout/ Services/)                │
│   Modules/{Name}/Pages/*.razor  (MudBlazor UI)                │
│        │ DbService.QueryAsync<T>(schema, script)              │
│   Scripts/{schema}/{Name}.sql (embedded in Data) ── Dapper ─┐ │
└─────────────────────────────────────────────────────────────┼──┘
        host: Web (server-only SQL secret) / MAUI (encrypted connection string from API only) ▼
        SQL Server — TarazinMaster (one DB, one schema per product)
        [central] [accounting] [inventory] [treasury]
        [payroll] [goldshop] [store]
```

## 2. Modules (9)

| Module | Route prefix | Schema |
|---|---|---|
| Central (پلتفرم مشترک) | `/central` | `central` |
| Accounting (حسابداری) | `/accounting` | `accounting` |
| Inventory (انبار آمل) | `/inventory` | `inventory` |
| Treasury (خزانه‌داری) | `/treasury` | `treasury` |
| Payroll (حقوق و دستمزد) | `/payroll` | `payroll` |
| GoldShop (طلافروشی) | `/goldshop` | `goldshop` |
| Store (فروشگاه) | `/store` | `store` |
| Currency (ارز و معاملات ارزی) | `/currency` | `currency` |
| BI (داشبورد و هوش تجاری) | `/bi` | `bi` |

Each module = 6 pages: home (روزانه), dashboard, entry, reports, special, settings.
The Currency module additionally has `/currency/prices` (مرکز نرخ‌ها و قیمت‌ها),
`/currency/wallets` (کیف پول), `/currency/convert` (تبدیل ارز) and
`/currency/combined` (معاملات ترکیبی) — see `docs/CURRENCY_MODULE.md`.
The BI module has `/bi` (مرکز فرماندهی — ۱۴ تب)، `/bi/alerts` (هشدارها) and
`/bi/reports` (چاپ با Stimulsoft) — see `docs/BI_MODULE.md`.

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
  resources `Tarazin.Scripts.{schema}.{Name}.sql` from `Tarazin.Data`
  (self-loading singleton). Never write inline SQL in a page.
- **Schema = scope guard** — a module only calls scripts of its own schema.
  Server-side scripts may read other schemas only with a
  `-- Cross-schema: x, y` header (enforced by `tools/cross-schema-scan.sh`).
- All scripts are **fully qualified**: `[accounting].[Documents]`, never `dbo`.
- Dapper parameterization (`@Name`) — no string concatenation.

## 4. Auth & session

- Web login: `/login` → `AuthService.AuthenticateAsync(user, pass)` against
  `[central].[Users]` (PBKDF2), using only server-side SQL configuration.
- MAUI login also requires `CustomerGuid`. `RemoteCredentialSession` calls the
  HTTPS broker login endpoint with nonce/timestamp and credentials; the broker
  validates active customer/user/company and authorization, opens a bounded
  bearer session, and the connection string is then fetched **only** via
  `POST /api/mobile/connection/encrypted` (AES per-session, key derived from
  the token), decrypted in memory, and executed by the shared UI (`DbService`).
  Sign-out revokes the session; nothing is persisted by MAUI or sent in a URL.
- Web: `UserSession` is per SignalR circuit (scoped).
- MAUI: the decrypted connection string is memory-only; `UserSession` is scoped
  to the native app service scope.
- Bootstrap creation requires a strong deployment secret. There is no default
  bootstrap password in source or configuration.

## 5. Audit

**Automatic** — every `DbService.ExecuteAsync(...)` attempts to record an
owner-scoped audit row (success or failure) in `[central].[AuditLog]`. No manual
call is needed in pages. This is not yet a correct tamper-evident chain:
`RowHash` omits `PrevHash`, and predecessor lookup/insertion are not serialized.
ADR-002 treats that defect as a release gate.

```csharp
// happens automatically inside DbService.ExecuteAsync:
//   _audit.RecordAsync(schema, scriptName, user, "Success"|"Error", error)
```

View at `/central/audit`. Parameters are never stored (they may contain
sensitive data). Audit failures are logged, never thrown.

## 6. Startup order

`TarazinDbInitializer.EnsureInitializedAsync(services)` runs only in the Web
host: `DbService.EnsureSchemaAsync` (all `_Ensure.sql`) →
`DbService.SeedAsync` (all `_Seed.sql`) → optional bootstrap admin from a
strong deployment secret. MAUI credentials explicitly cannot initialize
schemas (`OpenMasterConnectionAsync` always refuses); MAUI starts the
encrypted connection-string delivery at login.

## 7. Rules when adding a new module

1. Research the domain's reports first (report-first).
2. `Tarazin.Share/Models/{Module}Models.cs` — models matching script columns (ADR-003).
3. `Tarazin.Data/Scripts/{schema}/_Ensure.sql` (+ `_Seed.sql`) — idempotent DDL/data.
4. Pages under `Tarazin.Ui/Modules/{Name}/Pages/` with MudBlazor only.
5. Add NavMenu entry + Home launcher card.
6. Run `tools/cross-schema-scan.sh` before committing.
7. The result automatically appears in BOTH hosts (web + MAUI).
