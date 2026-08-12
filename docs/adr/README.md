# Architecture Decision Records — Hermes Platform

| # | Decision | Status | Date |
|---|----------|--------|------|
| [ADR-001](ADR-001-single-webapi-architecture.md) | The 7-product PRD is realized on the Hermes single-webapi model (no per-product microservices) | Accepted | 2026-08-12 |
| [ADR-002](ADR-002-events-outbox-and-sagas.md) | Event backbone = per-schema outbox + webapi processor; audit = webapi sidecar with hash chain (no Kafka/CDC) | Accepted | 2026-08-12 |
| [ADR-003](ADR-003-contracts-and-contract-tests.md) | Shared domain contracts = canonical named scripts + `share` DTOs + `contracts.json` manifest + xUnit contract tests | Accepted | 2026-08-12 |

> The PRD (v1.0, 2026-08-12) is the product vision. These ADRs are the binding
> architectural decisions that map that vision onto this repository. Product
> teams MUST read ADR-001–003 before starting work. The living spec is
> `docs/PLATFORM_PRD.md`; the work plan is `docs/PLATFORM_ROADMAP.md`.
