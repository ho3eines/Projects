# Tarazin architecture — v2.1 (Blazor Hybrid)

## Topology

```
Tarazin.Shared (RCL — UI + data layer)
├── Tarazin.Web   → dotnet run --project Tarazin.Web   https://localhost:65220
└── Tarazin.Maui  → dotnet build -f net10.0-windows10.0.19041.0 (ویندوز)
        └── SQL Server (docker compose) — TarazinMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

One shared core, one connection string
(`ConnectionStrings:DefaultConnection`), two hosts.

## Startup sequence (shared)

1. `ScriptCatalog` ctor — loads embedded `Tarazin.Data.Scripts.{schema}.{Name}.sql`
2. `TarazinDbInitializer.EnsureInitializedAsync(services)` — runs every
   `{schema}/_Ensure.sql`
3. `…` → runs every `{schema}/_Seed.sql`
4. `…` → creates `admin` only when `[central].[Users]` is empty

## Services

| Service | Scope | Purpose |
|---|---|---|
| `ScriptCatalog` | singleton | script store: `TryGet(schema, name, out sql)` |
| `DbService` | scoped | `QueryAsync<T>` / `QueryFirstOrDefaultAsync<T>` / `ExecuteAsync` / `ScalarAsync` |
| `AuthService` | scoped | `AuthenticateAsync(user, pass)` → `UserRow?` |
| `UserSession` | scoped | per-circuit (web) / per-app (MAUI) session state |
| `AuditService` | scoped | `RecordAsync(...)` → `[central].[AuditLog]` (hash chain) |
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
