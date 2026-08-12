# Hermes architecture — v2 (single Blazor Server)

## Topology

```
dotnet run --project HermesApp      → https://localhost:65220 (Blazor Server)
        │
        └── SQL Server (docker compose) — HermesMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

One port, one process, one connection string
(`ConnectionStrings:DefaultConnection`).

## Startup sequence

1. `ScriptCatalog.Load(contentRoot)` — reads `Data/Scripts/{schema}/{Name}.sql`
2. `DbService.EnsureSchemaAsync()` — runs every `{schema}/_Ensure.sql`
3. `DbService.SeedAsync()` — runs every `{schema}/_Seed.sql`
4. `EnsureBootstrapAdminAsync()` — creates `admin` only when `[central].[Users]` is empty

## Services

| Service | Scope | Purpose |
|---|---|---|
| `ScriptCatalog` | singleton | script store: `TryGet(schema, name, out sql)` |
| `DbService` | scoped | `QueryAsync<T>` / `QueryFirstOrDefaultAsync<T>` / `ExecuteAsync` / `ScalarAsync` |
| `AuthService` | scoped | `AuthenticateAsync(user, pass)` → `UserRow?` |
| `UserSession` | scoped | per-circuit session state |
| `AuditService` | scoped | `RecordAsync(...)` → `[central].[AuditLog]` (hash chain) |
| `PasswordHasher` | static | PBKDF2 hash/verify |

## Key conventions

- Script folders = schemas (`accounting`, `inventory`, `treasury`, `payroll`,
  `goldshop`, `store`, `central`).
- Page code: `@inject DbService Db` — never `HttpClient` for data.
- UI: MudBlazor components only (`MudTable`, `MudDatePicker`, `MudSelect`,
  `MudTextField`, `MudPaper`, `MudGrid`, `MudSnackbar`, …).
- RTL: `dir="rtl"` in `Pages/_Host.cshtml`; Persian culture via
  `CultureInfo.GetCultureInfo("fa-IR")` on date pickers.
