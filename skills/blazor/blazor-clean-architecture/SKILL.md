---
name: blazor-clean-architecture
description: Clean, single-project architecture for Blazor Server + MudBlazor.
version: 2.0.0
author: Hossein Esfandyari, Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [blazor, architecture, blazor-server, mudblazor, dapper, modules]
    related_skills: [hermes-project-architecture, blazor-data-access]
---

# Blazor Clean Architecture Skill (v2 — single project)

Implements a clean, maintainable **single Blazor Server project** with clear
layers inside one csproj — no separate Client/Server/Shared projects, no webapi.

## When to Use

- Starting a new module in Hermes (or any Blazor Server app) that must be
  maintainable and testable
- Migrating from multi-project / WASM + API to one Blazor Server process
- Dapper-based data layer with named scripts and schema isolation
- MudBlazor UI with zero hand-rolled design

## Solution Structure

```
HermesApp/
├── Program.cs              # Composition root: services, MudBlazor, startup ensure/seed
├── App.razor               # Router + Mud providers
├── Pages/_Host.cshtml      # RTL HTML shell
├── Layout/                 # MainLayout (MudLayout) + NavMenu (MudNavMenu)
├── Models/                 # SharedModels.cs + {Module}Models.cs
├── Services/               # ScriptCatalog, DbService, AuthService, UserSession, AuditService
├── Modules/{Name}/Pages/   # one folder per product/bounded context
├── Data/Scripts/{schema}/  # named TSQL (report-first data layer)
└── wwwroot/                # MudBlazor static assets + tiny app.css
```

## Dependency Rules (inside the one project)

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

| Old (v1/v1.5) | New (v2) |
|---|---|
| `src/Client` WASM | `Modules/*/Pages` |
| `src/Server` WebAPI + controllers | `Services/DbService` (in-process) |
| `src/Data` class library | `Data/Scripts/` + `Services/DbService` |
| `src/Business` class library | script logic (TSQL) + page handlers |
| `src/Shared` contracts | `Models/SharedModels.cs` |
| `tests/` xUnit against API | build + `tools/cross-schema-scan.sh` (CI) |

## References
- `hermes-project-architecture` — the master structure skill
- `blazor-data-access` — DbService / script conventions
- `blazor-create-project` — adding a module
