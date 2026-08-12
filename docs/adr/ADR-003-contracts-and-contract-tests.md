# ADR-003: Shared domain contracts = named scripts + DTOs + manifest + contract tests

- **Status**: Accepted
- **Date**: 2026-08-12
- **Relates to**: PRD §3 (Shared Domain Contracts), §9 AC #1/#4, ADR-001
- **Technical story**: implements PRD §3 contract ownership/versioning inside
  the named-TSQL model.

---

## Context

PRD §3 defines 8 shared contracts — `Party`, `ChartOfAccount`, `CurrencyRate`,
`TaxRule`, `InventoryMovement`, `PayrollRun`, `GoldPrice`, `Order`/`Cart` — each
with an owner, a consumer list, and a versioning rule ("v1 → v2, add fields,
never break"). The PRD assumes Protobuf/Avro + OpenAPI + Schema Registry with
enforced backward compatibility.

Hermes has no IDL. The only data surface is named TSQL scripts (`IRequestService`
→ `POST /api/Data`), and the only "registry" is `Hermes:Projects` in
`webapi/appsettings.json` (app → schema → SharedKey).

## Decision

A **contract** is a quad:

1. **Canonical table shape** — the owning schema's `_Ensure.sql` defines the
   table(s) (e.g. `[treasury].[CurrencyRates]`). Column names are the field
   names; aliases in scripts must match DTO property names.
2. **Named scripts** — each contract exposes at least:
   - `{Thing}Search` (query, paged, `@SkipRows/@TakeSize`),
   - `{Thing}ById` (single row),
   - `{Thing}Upsert` (IsExec — producer side),
   - `{Thing}On{Event}` (IsExec — consumer side, idempotent, where applicable).
   Script location = owning schema. Consumers never write to another schema;
   they read via server-side scripts (ADR-001).
3. **DTOs in `share/common/Models/`** — one C# record per contract row shape,
   shared by all clients (e.g. `CurrencyRateRow`, `OrderRow`).
4. **`contracts.json` manifest** — generated from the `Scripts/` tree + a small
   `contracts.manifest.json` source file, served by webapi at
   `/api/contracts` (read-only, no auth needed or CORS allow-listed). Entry:

```json
{
  "name": "CurrencyRate",
  "version": 1,
  "owner": "treasury",
  "consumers": ["accounting", "goldshop", "store"],
  "scripts": {
    "search": "CurrencyRateSearch",
    "byId": "CurrencyRateById",
    "upsert": "CurrencyRateUpsert"
  },
  "fields": [
    { "name": "CurrencyCode", "type": "string", "required": true },
    { "name": "RateToIRR", "type": "decimal", "required": true }
  ],
  "compat": "backward"
}
```

### Versioning

- Bump = new scripts + new DTO, keep old ones: `CurrencyRateSearch_V2`
  (or a `_V2` suffix set), `version: 2`, `compat: "backward"` meaning "added
  fields only". Old scripts stay until every consumer migrates; a deprecation
  date is recorded in the manifest.
- `Hermes:Projects` remains the **schema registry** (app → schema → SharedKey);
  the manifest is the **contract registry**. Two registries, one source of truth
  each.
- The PRD's "Schema Registry enforces backward compatibility" becomes a CI gate
  (below), not a runtime registry.

### Contract tests (PRD AC #1, #4)

New test project `tests/Hermes.ContractTests` (xUnit), run in CI and locally
via `docker compose`:

- **Shape tests** — for every contract, execute the search script against the
  owning schema and assert the returned columns match the DTO/manifest exactly
  (name + type). Any rename/removal fails the build.
- **Backward-compat tests** — keep golden samples for v1; when v2 is added,
  assert v1 scripts still return the v1 shape (fields added in v2 are nullable/
  defaulted in v1 scripts).
- **Consumer tests** — for each consumer listed in the manifest, assert the
  consumer's scripts compile/execute against the owning schema's tables (the
  cross-schema join is exercised end-to-end).
- **Idempotency tests** — replay an event twice; assert second run changes 0 rows.

### Static analysis (PRD AC #3)

A CI script scans `webapi/Data/Scripts/*/*.sql` and flags references to schemas
other than the script's own **unless** the file declares an allow-list header:

```sql
-- Cross-schema: central(Parties), inventory(InventoryMovements)
```

This turns "zero direct DB cross-reads" into an enforceable, auditable rule:
clients can never cross schemas (schema lock), and server-side cross-schema
reads are declared, reviewed, and whitelisted.

## Consequences

**Positive**: contract evolution is code review + tests, not a broker; DTOs in
`share` are already the shared surface; `contracts.json` doubles as the internal
API portal (PRD AC #4); consumers get compile-time safety from DTOs and runtime
safety from shape tests.

**Negative**: no automatic schema registry enforcement — discipline + CI only;
manifest is hand-maintained (must be updated in the same PR as the scripts);
cross-schema consumer tests require the full compose stack (slower than pure
unit tests, still minutes).

## Alternatives considered

- Real Protobuf/Avro + registry: rejected — no RPC layer to serve them; would
  add tooling without changing the named-script surface (ADR-001).
- OpenAPI for `POST /api/Data`: rejected — the endpoint is intentionally opaque
  (encrypted payloads); the manifest is the accurate, evolvable contract.
- No manifest (scripts are the contract): rejected — invisible breaking changes;
  AC #4 requires a published portal.
