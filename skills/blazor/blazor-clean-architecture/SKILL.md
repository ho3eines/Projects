---
name: blazor-clean-architecture
description: Clean, single-project architecture for Blazor Server + MudBlazor.
version: 2.0.0
author: Hossein Esfandyari, Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  tarazin:
    tags: [blazor, architecture, blazor-server, mudblazor, dapper, modules]
    related_skills: [tarazin-project-architecture, blazor-data-access]
---

# Blazor Clean Architecture Skill (v3 — shared core + hosts)

Implements a clean, maintainable **shared core** (`Tarazin.Ui` Razor Class
Library) with clear layers, hosted by two thin shells — `Tarazin.Web` (Blazor
Server) and `Tarazin.Maui` (MAUI Blazor Hybrid). No webapi, no WASM clients.

## When to Use

- Starting a new module in Tarazin (or any Blazor Server app) that must be
  maintainable and testable
- Migrating from multi-project / WASM + API to one Blazor Server process
- Dapper-based data layer with named scripts and schema isolation
- MudBlazor UI with zero hand-rolled design

## Solution Structure

```
Tarazin.Share/          # ← models/contracts (class lib, namespace Tarazin.Models)
└── Models/             # SharedModels.cs + {Module}Models.cs

Tarazin.Data/           # ← data layer (class lib, refs Share)
├── DbService.cs        # Query/Execute/Scalar (Dapper)
├── ScriptCatalog.cs    # embedded named scripts (Tarazin.Scripts.{schema}.{name}.sql)
├── AuditService.cs     # hash-chained audit
├── ICurrentUser.cs     # current-user abstraction (no UI dependency)
├── TarazinDbInitializer.cs
└── Scripts/{schema}/   # named TSQL (embedded resources — report-first)

Tarazin.Ui/             # ← UI core (RCL, RootNamespace: Tarazin; refs Share+Data)
├── App.razor           # Router + Mud providers + shared init (hosts render this)
├── _Imports.razor      # shared usings (Tarazin.* + MudBlazor)
├── Layout/             # MainLayout (MudLayout) + NavMenu (MudNavMenu)
├── Services/           # UserSession, AuthService, ServiceCollectionExtensions
├── Modules/{Name}/Pages/   # one folder per product/bounded context
└── wwwroot/css/app.css # tiny MudBlazor overrides (served by both hosts)

Tarazin.Web/            # thin web host (Blazor Server): Program.cs + _Host.cshtml
Tarazin.Maui/           # thin MAUI host (Blazor Hybrid): MauiProgram + MainPage.xaml
```

## Dependency Rules (inside the core)

- **Pages** → Services + Models (+ MudBlazor components)
- **Services** → ScriptCatalog/DbService → SQL Server
- **Models** → nothing (pure POCOs)
- **Scripts** → the database (fully schema-qualified, `@param` only)

No page calls another module's schema directly; cross-schema reads happen in
server-side scripts with a `-- Cross-schema:` header (verified by
`tools/cross-schema-scan.sh`).

## Key Principles

1. **Separation of concerns by folder, not by project** — the repo stays one
   deployable, but layers are visible and enforceable (scan + review).
2. **Named scripts are the repository layer** — pages describe *what* (script
   name + params), scripts describe *how* (SQL). Change SQL without touching
   the page.
3. **Models are the contract** — Dapper maps columns → properties; the compiler
   checks page usage, the scan checks schema boundaries.
4. **MudBlazor components are the only UI primitives** — no hand-rolled grid,
   date picker, or modal.

## Migrating from the old WASM+API layout

| Old (v1/v1.5) | New (v3) |
|---|---|
| `src/Client` WASM | `Tarazin.Ui/Modules/*/Pages` |
| `src/Server` WebAPI + controllers | `Tarazin.Ui/Services/DbService` (in-process) |
| `src/Data` class library | `Tarazin.Data/Scripts/` (embedded) + `DbService` |
| `src/Business` class library | script logic (TSQL) + page handlers |
| `src/Shared` contracts | `Tarazin.Share/Models/SharedModels.cs` |
| `tests/` xUnit against API | build + `tools/cross-schema-scan.sh` (CI) |

## References
- `tarazin-project-architecture` — the master structure skill
- `blazor-data-access` — DbService / script conventions
- `blazor-create-project` — adding a module
