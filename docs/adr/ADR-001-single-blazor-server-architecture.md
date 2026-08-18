# ADR-001: The 7-product platform is ONE Blazor Server project (no webapi, no WASM clients)

- **Status**: Accepted
- **Date**: 2026-08-12 (supersedes ADR-001-single-webapi-architecture, 2026-08-12)

> **Security clarification (2026-08-18):** «no webapi» در این ADR یعنی نبودن
> API عمومی CRUD/transport برای دادهٔ کسب‌وکار. amendment امنیتی ADR-004 یک
> broker محدود Web برای login/refresh/revoke و صدور credential موقت MAUI اضافه
> می‌کند؛ عملیات کسب‌وکار همچنان مستقیم و in-process است.
- **Deciders**: Product owner + Platform Architecture Team
- **Technical story**: replaces the v1.5 topology (7 WASM clients + 1 webapi +
  shared library + NuGet package) with a single deployable.

---

## Context

v1.5 had 11 projects in one solution: `webapi` (the only backend), `share`
(shared DTOs), `blazordeployservice` (NuGet UI/services package), `central-client`
and 6 product WASM clients, plus a contract-test project. Every data call went
client → webapi over HTTP with a handshake, AES envelope, HMAC signature and a
per-schema project registry. Pain points observed:

- **Management burden**: 11 csproj files, per-project `appsettings.json`,
  per-project ports and CORS entries; every small change touched multiple repos.
- **Duplicate files**: the six product clients carried near-identical App.razor,
  MainLayout, launch settings, and CSS.
- **Web-service complexity**: tokens in URLs, session tables, replay windows,
  AES keys that must live in a WASM bundle (extractable), schema-lock plumbing —
  all to connect a UI to a database that the team already owns.
- **UI rework**: hand-rolled Bootstrap 5.3 + custom DataGrid/PersianDatePicker
  meant constant design work.

## Decision

**Delete all of it.** Ship exactly one **Blazor Server** project (`Tarazin`,
net10.0). Products become modules (`Modules/{Name}/` in `Tarazin.Ui`), each
with its own SQL schema (`Data/Scripts/{schema}/` in `Tarazin.Data`). Models
live in `Tarazin.Share`; data access runs **in the same process** via Dapper
executing **named TSQL scripts**. UI is **MudBlazor only**. See ADR-005 for
the Share/Data split.

| v1.5 component | v2 replacement |
|---|---|
| `webapi` controllers + `IRequestService` transport | `DbService` + `ScriptCatalog` (in-process, in `Tarazin.Data`) |
| 7 WASM clients | `Tarazin.Ui/Modules/{7}/Pages` |
| `share` DTOs | `Tarazin.Share/Models/SharedModels.cs` |
| `blazordeployservice` NuGet + Bootstrap | MudBlazor package |
| `tests/Tarazin.ContractTests` (webapi-shaped) | removed; CI = build + `tools/cross-schema-scan.sh` |
| per-project ports 65218–65233 | one port (65220) |
| Outbox + processor (ADR-002 v1) | retired — see ADR-002 |

## Consequences

- One process = one failure domain; mitigations: startup `_Ensure`/`_Seed`,
  audit trail, simple ops (one service to run, one to back up).
- Team parallelism via module folders + schema boundaries instead of repos.
- All secrets stay server-side; the WASM "keys in the bundle" class of
  vulnerabilities disappears.
- Migrating to MudBlazor removes the custom UI components.

## Alternatives considered

- Keeping webapi + WASM (status quo): rejected — complexity without benefit when
  the UI and DB are owned by the same team.
- Blazor WASM standalone per product (v1): rejected — duplicated UI, HTTP layer,
  secret exposure.
- Blazor Web App with per-page interactivity: possible later evolution; the
  classic `AddServerSideBlazor` host was chosen for simplicity and MudBlazor
  compatibility.
