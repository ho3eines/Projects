# ADR-005: Separate `Tarazin.Share` (models) and `Tarazin.Data` (data access) projects

- **Status**: Accepted
- **Date**: 2026-08-12
- **Relates to**: ADR-001 (shared core), ADR-003 (contracts), ADR-004 (MAUI host)
- **Technical story**: splits the single UI core into a clean 3-layer core +
  2 hosts, per the product owner's request ("یک پروژه Share, Data لازم داره").

---

## Context

v2.1 had one `Tarazin.Ui` RCL holding everything: modules (UI), models,
services (including `DbService`) and SQL scripts. That works, but:

- Models (contracts) and data access are **core, UI-independent concerns** —
  co-locating them with the UI makes the UI assembly a dependency for any
  future non-UI consumer (tests, a future API service, tooling).
- It was impossible to express "models only" or "data only" dependencies;
  everything dragged in MudBlazor.
- Naming became confusing once a separate "Share" project was requested.

## Decision

Split the core into **three projects** (plus the two existing hosts = five total) with one-way dependencies:

```
Tarazin.Share  ──► (no dependencies)            # models/contracts (namespace Tarazin.Models)
Tarazin.Data   ──► Tarazin.Share                # DbService, ScriptCatalog, AuditService,
                                                # PasswordHasher, ICurrentUser, TarazinDbInitializer,
                                                # Scripts/**/*.sql (embedded)
Tarazin.Ui     ──► Tarazin.Share + Tarazin.Data # modules, layout, UserSession, AuthService,
                                                # AddTarazinUiServices()
Tarazin.Web    ──► Tarazin.Ui                   # web host
Tarazin.Maui   ──► Tarazin.Ui                   # MAUI host
```

Key points:

1. **`Tarazin.Share`** is a plain class library (`Microsoft.NET.Sdk`) — no
   Blazor/MudBlazor/Dapper references. Namespace stays `Tarazin.Models` so
   pages and scripts keep their existing column/property contract (ADR-003).
2. **`Tarazin.Data`** is a plain class library with Dapper + SqlClient +
   config/logging abstractions. It depends on `Tarazin.Share` only. The
   embedded scripts live here (`Scripts/**/*.sql` → resource
   `Tarazin.Scripts.{schema}.{name}.sql`) and `ScriptCatalog` self-loads from
   its own assembly.
3. **Data never references UI**: `DbService` no longer takes `UserSession`;
   it takes `ICurrentUser` (defined in `Tarazin.Data`). The UI layer's
   `UserSession` implements it and the UI DI registration wires them:
   `AddTarazinUiServices()` → `AddTarazinDataServices()` + UI services.
4. **`Tarazin.Ui`** keeps all Razor assets, MudBlazor, `App.razor`, session &
   auth services, and the combined registration both hosts call.
5. Registration split: `AddTarazinDataServices()` (Data) registers
   `ScriptCatalog`, `DbService`, `AuditService`; `AddTarazinUiServices()` (Ui)
   calls it and adds `UserSession`, `ICurrentUser`, `AuthService`.

## Consequences

- Clean one-way dependency graph; each layer is testable/consumable in
  isolation (future: unit tests against `Tarazin.Data`, a headless script
  runner, or a service API without pulling the UI).
- Hosts stay thin: they only call `AddTarazinUiServices()` and render
  `Tarazin.App`.
- Model moves are now physically constrained to `Tarazin.Share`; SQL/DDL to
  `Tarazin.Data`; pages to `Tarazin.Ui` (enforced by review + the
  cross-schema scan).

## Alternatives considered

- Keep everything in `Tarazin.Ui`: rejected — no layer isolation, drags UI
  dependencies into data code.
- Rename `Tarazin.Ui` back to `Tarazin.Shared` alongside a `Tarazin.Share`
  project: rejected — `Share` vs `Shared` would be permanently confusing.
