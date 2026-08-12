# ADR-002: No event backbone — cross-module work is direct server-side SQL

- **Status**: Accepted
- **Date**: 2026-08-12 (supersedes ADR-002-events-outbox-and-sagas, 2026-08-12)
- **Relates to**: PRD §4 (Integration), ADR-001
- **Technical story**: removes the per-schema `Outbox` tables, the
  `OutboxProcessor` hosted service and the event routes.

---

## Context

v1.5 implemented PRD §4 integration scenarios (Command→Event, Saga, Dual-write,
Pub/Sub) with an **outbox table per schema** + a background processor that polled
outboxes and dispatched events to consumer scripts in other schemas. Consumers
were idempotent (`WHERE NOT EXISTS` on EventKey); `[central].[AuditLog]` used a
hash chain.

With ADR-001 the app is **one process** that already has direct, transactional
access to every schema. The outbox machinery exists only to decouple processes
that no longer exist.

## Decision

**Retire the event backbone.** Cross-module work is done by calling the target
script directly from the calling server-side script (or from the page via
`DbService`) in the same transaction where it matters:

| Scenario | v2 mechanism |
|---|---|
| Store order → reserve stock | `ReserveStockForOrder.sql` executed at order placement |
| Store order → accounting invoice | `SalesInvoiceFromOrder.sql` (server-side call) |
| Payroll finalize → GL + treasury | `GLPostFromPayroll.sql`, `CashMoveFromPayroll.sql` called on finalize |
| Gold price sync | `RefreshGoldPrice.sql` called after price upsert |

The `Outbox` tables remain in `_Ensure.sql` (backward-compatible DDL) but are
**dormant**: nothing writes the event rows anymore and no processor reads them.
They can be dropped in a later cleanup migration.

**Audit stays** — `AuditService` writes every mutating execution to
`[central].[AuditLog]` with a SHA-256 `PrevHash`/`RowHash` chain, preserving the
tamper-evident property without the outbox.

## Consequences

- Simpler: no hosted service, no routes table, no idempotency keys.
- Cross-module operations are synchronous and transactional (stronger than the
  old eventually-consistent flow).
- If the platform ever splits into multiple processes again, the Outbox tables
  and this ADR's predecessor can be revived — the DDL is still present.
