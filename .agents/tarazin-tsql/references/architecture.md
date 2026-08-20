# Tarazin architecture — v2.1 (Blazor Hybrid)

## Topology

```
Tarazin.Share (models) ← Tarazin.Data (data layer) ← Tarazin.Ui (UI RCL)
├── Tarazin.Web   → dotnet run --project Tarazin.Web   https://localhost:65220
└── Tarazin.Maui  → dotnet build -f net8.0-windows10.0.19041.0 (ویندوز)
        ├── HTTPS broker: login/refresh/revoke + POST /connection/encrypted
        │   (رشتهٔ اتصال فقط رمزگذاری‌شده — AES per-session از توکن جلسه)
        └── SQL Server — TarazinMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

One shared core, two connection providers:

- Web reads `ConnectionStrings:DefaultConnection` only from server-side
  deployment secrets and performs database initialization.
- **MAUI law (قانون):** the SQL connection string reaches MAUI **only from
  the API, in encrypted form** (`POST /api/mobile/connection/encrypted`,
  AES key derived per-session from the bearer token). `RemoteCredentialSession`
  decrypts it in process memory only and hands it to the shared UI/data layer
  (`ISqlConnectionProvider` → `DbService`) for execution. `Tarazin.Maui/appsettings.json`
  contains only the public HTTPS `ServerEndpoint` + public `CustomerGuid`.
  A plaintext credential/connection path must not be used;
  `UseEncryptedMaster=false` is rejected at startup.

## Startup sequence (Web only)

1. `ScriptCatalog` ctor (in `Tarazin.Data`) loads embedded `Tarazin.Scripts.{schema}.{Name}.sql`.
2. `TarazinDbInitializer.EnsureInitializedAsync(services)` runs every
   `{schema}/_Ensure.sql` and `{schema}/_Seed.sql`.
3. An initial admin is created only when users are empty and a strong bootstrap
   password was supplied by deployment; no default password exists.

MAUI does not initialize the database (`OpenMasterConnectionAsync` always
refuses); initialization stays Web-only.

## Services

| Service | Scope | Purpose |
|---|---|---|
| `ScriptCatalog` | singleton | script store: `TryGet(schema, name, out sql)` |
| `DbService` | scoped | `QueryAsync<T>` / `QueryFirstOrDefaultAsync<T>` / `ExecuteAsync` / `ScalarAsync` |
| `AuthService` | scoped | `AuthenticateAsync(user, pass)` → `UserRow?` |
| `UserSession` | scoped | per-circuit (web) / per-app (MAUI) session state |
| `AuditService` | scoped | tenant-owned audit rows; chain correctness remains a release gate |
| `PasswordHasher` | static | PBKDF2 hash/verify |

## Key conventions

- Script folders = schemas (`accounting`, `inventory`, `treasury`, `payroll`,
  `goldshop`, `store`, `central`).
- Page code: `@inject DbService Db` — never `HttpClient` for data.
- UI: MudBlazor components only (`MudTable`, `MudDatePicker`, `MudSelect`,
  `MudTextField`, `MudPaper`, `MudGrid`, `MudSnackbar`, …).
- RTL: `dir="rtl"` in `Tarazin.Web/Pages/_Host.cshtml` and
  `Tarazin.Maui/wwwroot/index.html`; Persian culture via
  `CultureInfo.GetCultureInfo("fa-IR")` on date pickers.
