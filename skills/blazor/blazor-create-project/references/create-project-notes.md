# Create Module — Reference Notes (v2)

"Creating a project" in Hermes v2 = **adding a module to the single Blazor
Server app**. No API, no `dbo.Projects` registry, no per-project DB.

## Quick Troubleshooting

| Issue | Cause | Fix |
|-------|-------|-----|
| `Named script 'X' not found for schema 'Y'` | script file missing or wrong name/path | Add `Data/Scripts/{schema}/X.sql`; names are case-insensitive |
| Table missing at runtime | `_Ensure.sql` didn't run | Run startup ensure (it runs automatically); check the script is idempotent |
| Duplicate seed data | `_Seed.sql` not guarded | Wrap inserts in `IF NOT EXISTS (SELECT 1 FROM ...)` |
| Page route collision | two pages share `@page` | Prefix all module routes: `/{route}/...` |
| `HttpClient`/`IRequestService` not found | old transport removed | Use `DbService` |

## Checklist for a new module

| Step | File(s) |
|------|---------|
| 1. Reports research | module PRD section |
| 2. Models | `Models/{Name}Models.cs` |
| 3. DDL + seed + named scripts | `Data/Scripts/{schema}/_Ensure.sql`, `_Seed.sql`, `*.sql` |
| 4. Six MudBlazor pages | `Modules/{Name}/Pages/*.razor` |
| 5. Register | `Layout/NavMenu.razor`, `Modules/Home/Home.razor` |
| 6. Validate | `tools/cross-schema-scan.sh`, `dotnet build` |

## Database Schema (single DB, per-module schemas)

| Schema | Module | Created by |
|--------|--------|-----------|
| `central` | پلتفرم مشترک | `central/_Ensure.sql` |
| `accounting` | حسابداری | `accounting/_Ensure.sql` |
| `inventory` | انبار آمل | `inventory/_Ensure.sql` |
| `treasury` | خزانه‌داری | `treasury/_Ensure.sql` |
| `payroll` | حقوق و دستمزد | `payroll/_Ensure.sql` |
| `goldshop` | طلافروشی | `goldshop/_Ensure.sql` |
| `store` | فروشگاه | `store/_Ensure.sql` |

## Startup sequence (Program.cs)

1. `ScriptCatalog.Load(root)` — indexes all `Data/Scripts/**/*.sql`
2. `DbService.EnsureSchemaAsync()` — executes every `_Ensure.sql`
3. `DbService.SeedAsync()` — executes every `_Seed.sql`
4. `EnsureBootstrapAdminAsync()` — creates `admin` when `Users` is empty
