# ADR-003: Shared domain contracts = C# models + named scripts (no IDL)

- **Status**: Accepted
- **Date**: 2026-08-12 (supersedes ADR-003-contracts-and-contract-tests, 2026-08-12)
- **Relates to**: PRD §3 (Shared Domain Contracts), ADR-001

---

## Context

PRD §3 defines 8 shared contracts — `Party`, `ChartOfAccount`, `CurrencyRate`,
`TaxRule`, `InventoryMovement`, `PayrollRun`, `GoldPrice`, `Order`/`Cart` — with
owners, consumers and a "v1 → v2, add fields, never break" versioning rule.

v1.5 represented contracts as `share` DTOs + a JSON manifest + xUnit contract
tests against a webapi. With ADR-001 there is no `share` project and no webapi
to test over HTTP.

## Decision

A **contract** is:

1. A C# model in `Tarazin.Shared/Models/SharedModels.cs` (or a module models file)
   — property names are the canonical column aliases.
2. The named TSQL scripts in `Data/Scripts/{schema}/` that produce/consume those
   shapes — script column aliases **must** match the model property names.
3. Dapper maps by column name → property name, so the model is the schema
   contract the page code compiles against.

Backward compatibility rule: adding a **new** field = add nullable property to
the model and `ISNULL(..., NULL)` column in scripts; never reorder/rename existing
fields without a new script name (`Name_V2.sql` pattern kept from v1).

`tools/cross-schema-scan.sh` enforces that a script in schema A never reads
schema B tables unless declared in a `-- Cross-schema:` header comment.

## Consequences

- No IDL, no manifest file, no separate test project — the compiler is the
  contract checker (models used by pages must exist).
- Contract drift is caught at build time (missing property) and by the
  cross-schema scan (schema leakage).
- v2 fields already in use: `PartyRow.NationalId` (v2), `PartySearch_V1.sql`
  (v1 view) — pattern preserved.
