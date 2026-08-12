# ADR-002: Event backbone = per-schema outbox + webapi processor; audit = sidecar

- **Status**: Accepted
- **Date**: 2026-08-12
- **Relates to**: PRD §4 (Integration Patterns), §5 (Audit), ADR-001
- **Technical story**: implements PRD §4 scenarios (Command→Event, Saga,
  Dual-write, Pub/Sub, Audit) inside the single-webapi model.

---

## Context

PRD §4 asks for Kafka-style asynchronous integration: `OrderPlaced` →
Accounting creates `SalesInvoice`; `ReserveStock` saga; `PayrollFinalized`
dual-write; `GoldPriceUpdated` pub/sub; and a CDC-based immutable `AuditLog`.

Hermes constraints (ADR-001): one webapi, one SQL Server, clients only run
named scripts in their own schema. We need async, eventually-consistent
integration with **idempotent consumers** and a **tamper-evident audit trail**,
without Kafka and without Debezium.

## Decision

### 1. Outbox (the event backbone)

Every product schema gets an `Outbox` table (created by its `_Ensure.sql`):

```sql
CREATE TABLE [schema].[Outbox] (
    OutboxId      BIGINT IDENTITY(1,1) PRIMARY KEY,
    EventType     NVARCHAR(100) NOT NULL,          -- e.g. 'OrderPlaced'
    EventKey      NVARCHAR(200) NOT NULL,          -- e.g. OrderId=12345
    Payload       NVARCHAR(MAX) NOT NULL,          -- JSON (UTF-8), versioned via PayloadVersion
    PayloadVersion INT NOT NULL DEFAULT 1,
    CreatedAt     DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME(),
    ProcessedAt   DATETIME2 NULL,
    Attempts      INT NOT NULL DEFAULT 0,
    LastError     NVARCHAR(MAX) NULL
);
CREATE INDEX IX_Outbox_Ready ON [schema].[Outbox](ProcessedAt, OutboxId) WHERE ProcessedAt IS NULL;
```

- **Producer rule**: a mutating script (`IsExec = true`, e.g. `OrderPlace`)
  writes its business rows **and** the outbox row **in the same transaction**
  (same script/batch). The database transaction is the atomicity boundary that
  Kafka would provide via transaction APIs.
- **Consumer**: a new webapi hosted service, `OutboxProcessor`, polls each
  product's ready outbox rows (batch, every 1–5 s), and dispatches them by
  `EventType` to consumer scripts in the **target** schema. This is the only
  place where cross-schema writes happen, and it is server-side code, matching
  "reads/writes through Core Services".
- **Idempotency**: every consumer table that reacts to an event carries a unique
  `IdempotencyKey` (typically `EventKey` + event type). Consumer scripts insert
  `WHERE NOT EXISTS` on that key, so redelivery is a no-op.
- **Dead-letter**: after N attempts (`MaxAttempts`), rows stay unprocessed with
  `LastError`; `/health` exposes outbox depth so an alert fires instead of
  silently losing events.

### 2. PRD §4 scenarios mapped

| PRD scenario | Hermes implementation |
|---|---|
| Create Sales Invoice (E-Com → Accounting) | `[store].[Orders]` write + `OrderPlaced` outbox row in same script → `OutboxProcessor` runs `[accounting].[SalesInvoiceFromOrder]` (idempotent on `OrderId`) |
| Stock Reservation (Warehouse ← GoldShop/E-Com) | Orchestrated saga: `StoreReserveStock` (store schema) calls `[inventory].[ReserveStock]` server-side; success → `StockReserved`, failure → `StockRejected` outbox events; compensating script `[inventory].[ReleaseStock]` on cancel (saga step 2) |
| Payroll Posting (Payroll → Accounting + Treasury) | `[payroll].[PayrollRuns]` finalize writes `PayrollFinalized` outbox → two consumer scripts: `[accounting].[GLPostFromPayroll]` + `[treasury].[CashMoveFromPayroll]`, each idempotent — the PRD's dual-write |
| Daily Gold Price Sync (GoldShop → all) | `[goldshop].[GoldPrices]` upsert emits `GoldPriceUpdated` → consumers refresh read-model rows (`[accounting].[GoldPriceSnapshot]`, `[store].[GoldPriceSnapshot]`); page loads can also join the owning table directly via server-side script if freshness matters more |
| Audit Trail (all) | see §3 — no CDC |

### 3. Audit sidecar (no Debezium)

`webapi`'s `DataController` records **every mutating call** (IsExec) into
`[central].[AuditLog]` — including the event-apply writes of `OutboxProcessor`:

```sql
CREATE TABLE [central].[AuditLog] (
    AuditId     BIGINT IDENTITY(1,1) PRIMARY KEY,
    PrevHash    CHAR(64) NOT NULL,           -- SHA-256 hex of previous row
    RowHash     CHAR(64) NOT NULL,           -- SHA-256 of this row's payload
    SchemaName  NVARCHAR(100) NOT NULL,
    ScriptName  NVARCHAR(200) NOT NULL,
    Parameters  NVARCHAR(MAX) NULL,          -- JSON (may be redacted)
    UserTokenId NVARCHAR(100) NULL,
    RequestId   NVARCHAR(100) NULL,
    Outcome     NVARCHAR(20) NOT NULL,       -- Success / Error
    CreatedAt   DATETIME2 NOT NULL DEFAULT SYSUTCDATETIME()
);
```

- `RowHash` chains to `PrevHash` → tamper-evident (a modified row breaks the chain).
- Central exposes `AuditSearch` script to `central-client` (who/what/when).
- CDC is unnecessary: the audit capture point is the API boundary, not the log.

### 4. Delivery guarantees

| Guarantee | Mechanism |
|---|---|
| At-least-once delivery | outbox rows only marked `ProcessedAt` after consumer success |
| Exactly-once *effect* | idempotency keys on every consumer write |
| Ordering per key | `EventKey`-ordered dispatch; consumers keyed by same key are processed sequentially |
| No loss on crash | outbox row committed with business data (same tx); processor resumes unprocessed rows |

## Consequences

**Positive**: no Kafka/CDC to operate; every scenario in PRD §4 is implemented
with scripts a product team already knows how to write; events are replayable
(reset `ProcessedAt`); SLO "event processing < 5 s" maps to a simple batch interval.

**Negative**: outbox polling is pull-based (not sub-millisecond pub/sub — fine for
these domains); cross-schema consumer scripts must be reviewed carefully (they
are the only cross-schema writers); `OutboxProcessor` needs the same auth/logging
treatment as any webapi service.

## Alternatives considered

- Kafka + Debezium: rejected (ADR-001) — infra cost, no benefit at this scale.
- Direct synchronous cross-schema calls from product scripts: rejected — would
  couple products and violate bounded contexts; outbox keeps producers decoupled.
- Trigger-based fan-out inside SQL: rejected — logic in triggers is untestable
  with named scripts and hard to dead-letter.
