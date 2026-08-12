# ADR-004: MAUI Blazor Hybrid host — one shared UI, two hosts

- **Status**: Accepted
- **Date**: 2026-08-12
- **Relates to**: PRD v2.1 (Blazor Hybrid), ADR-001 (shared core), ADR-003 (contracts)
- **Technical story**: adds a native desktop/mobile shell on top of the shared UI.

---

## Context

ADR-001 established one Blazor Server project (`Tarazin.Web`) hosting all seven
modules with the UI built in MudBlazor. The product owner wants the same
application as a **native desktop/mobile app** (Windows, Android, iOS, macOS)
without duplicating any UI code — the classic **MAUI Blazor Hybrid** scenario
(one Razor component library, two hosts: browser + WebView).

MAUI Blazor Hybrid renders Blazor components in a `BlazorWebView` with the
components executing **in-process on the native runtime** (no server, no SignalR).
That means any component/service that works in-process (MudBlazor UI, Dapper,
DI) can be shared as-is; only host plumbing differs.

## Decision

Restructure the repo into **three projects**:

| Project | Kind | Role |
|---|---|---|
| `Tarazin.Shared` | Razor Class Library (RCL), `RootNamespace=Tarazin` | ALL UI: `Modules/`, `Layout/`, `Models/`, `Services/`, `Data/Scripts/` (embedded resources), `App.razor` (Router + MudBlazor providers + init) |
| `Tarazin.Web` | ASP.NET Core Blazor Server | Thin web shell: `Program.cs`, `Pages/_Host.cshtml`, `appsettings.json` |
| `Tarazin.Maui` | .NET MAUI (Blazor Hybrid) | Thin native shell: `MauiProgram.cs`, `MainPage.xaml` (BlazorWebView → `Tarazin.App`), `wwwroot/index.html`, `Platforms/`, `Resources/` |

Key mechanisms:

1. **Shared services** — `AddTarazinSharedServices()` in `Tarazin.Shared/Services/ServiceCollectionExtensions.cs` registers `ScriptCatalog` (singleton, self-loads embedded scripts), `DbService`, `AuditService`, `AuthService`, `UserSession` (scoped). Both hosts call it.
2. **Shared startup** — `TarazinDbInitializer.EnsureInitializedAsync(IServiceProvider)` runs `_Ensure.sql` → `_Seed.sql` → bootstrap admin, guarded by `Interlocked` so both hosts (and web prerender) are safe. Web calls it in `Program.cs`; MAUI via `App.razor` `OnInitializedAsync`.
3. **Scripts as embedded resources** — `Data/Scripts/**/*.sql` are `EmbeddedResource` in the RCL (`Tarazin.Data.Scripts.{schema}.{name}.sql`); `ScriptCatalog` loads them from the assembly so the packaged MAUI app never needs a content root. Files remain in the repo for editing/tooling (`tools/cross-schema-scan.sh`).
4. **Shared static assets** — `Tarazin.Shared/wwwroot/css/app.css` is served by both hosts at `_content/Tarazin.Shared/css/app.css` (web static assets + BlazorWebView RCL assets).
5. **Namespaces** — RCL root `Tarazin` (pages keep `Tarazin.Modules.*`); web host `Tarazin.Web`; MAUI `Tarazin.Maui` — no ambiguity across assemblies.
6. **MAUI config** — `Tarazin.Maui/appsettings.json` is embedded and loaded via `builder.Configuration.AddJsonStream(...)` so the shared layer reads `ConnectionStrings`/`Tarazin:*` identically.

## Consequences

- **One UI, two products**: every new page/module is written once in
  `Tarazin.Shared` and instantly available in the browser and the native app.
- **Platform constraint (important)**: `Microsoft.Data.SqlClient` supports
  Windows/Linux/macOS, **not** Android/iOS. Therefore the MAUI host's data
  features work on **Windows desktop** (and macOS) out of the box; for
  Android/iOS the data layer must be swapped (e.g. a future API service or an
  ORM that supports SQLite) — tracked as backlog, the UI is already ready.
- **Scoped ≠ per-circuit in MAUI**: in the MAUI host there are no Blazor
  circuits; scoped services behave like app-wide singletons (fine for a
  single-user desktop app).
- **CI**: web build (ubuntu) + MAUI build (windows-latest with
  `dotnet workload install maui`, `-f net10.0-windows10.0.19041.0`) +
  cross-schema scan.

## Alternatives considered

- Duplicate UI in a separate MAUI project: rejected — the whole point of
  Blazor Hybrid is one component set.
- MAUI app pointing its WebView at the hosted web URL: rejected — offline /
  native integration, and it would resurrect a client-server data layer.
- Keeping everything in one csproj (MAUI can't host an ASP.NET Core server
  project): not possible — RCL is the required sharing unit.
