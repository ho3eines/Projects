# Architecture Decision Records — Hermes Platform (v2)

| # | Decision | Status | Date |
|---|----------|--------|------|
| [ADR-001](ADR-001-single-blazor-server-architecture.md) | The 7-product platform is ONE Blazor Server project — no webapi, no WASM clients, no shared libs | Accepted | 2026-08-12 |
| [ADR-002](ADR-002-no-event-backbone-direct-sql.md) | No event backbone — cross-module work is direct server-side SQL in the same process | Accepted | 2026-08-12 |
| [ADR-003](ADR-003-contracts-shared-models-and-scripts.md) | Shared domain contracts = C# models + named scripts; compiler + cross-schema scan enforce them | Accepted | 2026-08-12 |

> PRD v2.0 (`docs/PLATFORM_PRD.md`) is the product vision. These ADRs are the
> binding architectural decisions for this repository. The living spec is
> `docs/PROJECT.md`; the work plan is `docs/PLATFORM_ROADMAP.md`.
> The agent-facing data skill is `.agents/hermes-tsql/SKILL.md`.
