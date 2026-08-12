# ADR-001: The 7-product platform runs on the Hermes single-webapi model

- **Status**: Accepted
- **Date**: 2026-08-12
- **Deciders**: Platform Architecture Team (PRD v1.0), repo conventions (`docs/PROJECT.md`, `.agents/hermes-tsql/SKILL.md`)
- **Technical story**: implements PRD §2 (High-Level Architecture) within the Hermes topology.

---

## Context

PRD v1.0 describes a microservice topology: API Gateway (Kong/Traefik + OIDC),
service mesh (Istio/Linkerd), Kafka + Avro + Schema Registry, one deployable per
product, per-service PostgreSQL + Debezium CDC, React 18 micro-frontends, and
GitOps on Kubernetes.

The repository is **Hermes**: one shared `webapi` (the only backend), a central
client for login/launch, and **client-only Blazor WASM** product apps that never
talk to a per-product API. All data flows through named TSQL scripts locked to a
per-product SQL schema. These rules are documented in `docs/PROJECT.md` and the
`hermes-tsql` skill, and are enforced by the codebase (schema lock from the
project registry, `NamedScriptRules`, CORS allow-list, HMAC user JWTs).

The two topologies are not the same. Adopting the PRD literally would mean
re-writing the whole platform, contradicting the repository's own documented
architecture, and — critically for Blazor WASM — shipping every secret that a
microservice gateway would normally keep server-side (any per-client API key,
OIDC client secret, or service credential is extractable from WASM).

## Decision

We **keep the Hermes single-webapi model** as the realization of the PRD. Each
PRD layer is mapped to a concrete Hermes mechanism; where the PRD layer has no
equivalent, the PRD **goal** is met another way (see ADR-002, ADR-003).

| PRD §2 layer | PRD assumption | Hermes realization |
|---|---|---|
| API Gateway | Kong/Traefik, OIDC, rate-limit | `webapi` — `AuthController` (handshake + login), `DataController` (encrypted named scripts), `HandshakeGuard` (rate-limit 5/min/IP), CORS allow-list |
| Service Mesh | mTLS, retries, circuit-break | Not adopted (single deployable). Resilience = idempotent consumers + outbox (ADR-002); TLS on webapi + dev certs |
| Event Backbone | Kafka, Avro, Schema Registry | Per-schema `Outbox` tables + `OutboxProcessor` hosted service + idempotent consumers (ADR-002) |
| Core Services | Party, ChartOfAccounts, Currency, TaxEngine, AuditLog | `[central]` schema + `share/` DTOs + named scripts; AuditLog as webapi sidecar (ADR-002) |
| Product Services | 7 deployables, independent CI/CD | 7 WASM clients, same solution; one shared CI pipeline with per-product contract tests |
| Data Layer | PostgreSQL per service, CDC → read-models | One SQL Server (`HermesMaster`), one schema per product (`[accounting]`, `[inventory]`, …); server-side cross-schema scripts act as read-model projection |
| Front-End Shell | React 18 + Module Federation | `central-client` launcher + `blazordeployservice` shared UI (Bootstrap 5.3, Persian components) |
| DevOps | Kubernetes 1.29, ArgoCD, Helm | `docker compose` for local; GitHub Actions CI; GitOps/K8s deferred (roadmap Phase 6) |

### How the PRD's *goals* are preserved

- **Bounded contexts** — every product owns exactly one SQL schema; the registry
  maps app → schema; a session can never touch another schema, so no product
  reads another product's tables directly (PRD AC #3 holds by construction).
- **Versioned contracts** — named scripts + DTOs + `contracts.json` manifest
  (ADR-003) replace Protobuf/OpenAPI, with the same backward-compat intent.
- **No direct cross-product reads** — a client can only run scripts of its own
  schema. Cross-product reads happen in *server-side* scripts of the owning
  schema (the Hermes equivalent of "reads go through Core Services").
- **Eventual consistency** — outbox + idempotent consumers (ADR-002) meet the
  PRD's integration scenarios (§4) without Kafka.

### Explicitly not adopted (and why)

| PRD item | Reason |
|---|---|
| Kafka / Avro / Schema Registry | Single SQL Server already provides the transaction + schema; outbox gives the same guarantees with far less ops (ADR-002) |
| Keycloak OIDC + OPA | WASM cannot hide client secrets; existing HMAC-JWT + central login + RBAC in `UserDirectory` covers AuthN/AuthZ. 15-min tokens + refresh is a backlog item (P0-08) |
| React 18 / Module Federation | Repo mandate: Blazor WASM + Bootstrap 5.3 only |
| Kubernetes / ArgoCD / Helm | Out of scope for a local-first ERP; `docker compose` + CI first, GitOps later (Phase 6) |
| Debezium CDC | Replaced by the webapi audit sidecar + outbox writes in the same transaction (ADR-002) |

## Consequences

**Positive**
- Zero new infrastructure; every product inherits auth, encryption, schema lock, CORS, audit.
- PRD AC #1 (`docker compose up`) and AC #3 (no direct DB cross-reads) become naturally testable.
- New product = new folder + registry row + scripts; small, reviewable diff.

**Negative**
- Cross-schema joins in scripts are the only "integration" mechanism; a query
  hitting another schema must be written as a server-side script, never ad-hoc.
- SQL Server remains a single point of failure (mitigation: backups, compose
  healthcheck, future read replicas — not in scope for v1).

**Neutral**
- The PRD's "one deployable per product" becomes "one WASM bundle per product",
  but release still happens per product via the shared pipeline.

## Alternatives considered

1. **Full PRD microservice re-platform** — rejected: contradicts `docs/PROJECT.md`
   and the `hermes-tsql` skill; secrets-in-WASM problem for any client-scoped key;
   large cost for a single-tenant ERP.
2. **Hybrid (Kafka only for events)** — rejected for v1: outbox covers every PRD
   integration scenario with less infrastructure; can be swapped in later without
   changing client code (events are already decoupled behind scripts).
