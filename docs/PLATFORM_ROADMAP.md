# Platform Roadmap — 7-Product Hermes Platform

> **Date**: 2026-08-12 · **Branches from**: PRD v2.0 (Hermes Edition) — `docs/PLATFORM_PRD.md`
> **Decisions**: ADR-001 (single webapi), ADR-002 (outbox/audit), ADR-003 (contracts & tests)
> **Rule of thumb**: هر محصول = گزارش‌محور؛ اول تحقیق گزارشات، بعد مدل‌ها و اسکریپت‌ها، بعد صفحات (Hermes Rule #7).

---

## 0. Target topology (after Phase 0–5)

```
localhost
├── central-client  :65219/:65221   (login + launcher — محصول ۷: پلتفرم مشترک)
├── accounting      :65218/:65220   (محصول ۱ — موجود)
├── inventory       :65224/:65225   (محصول ۲ — انبار آمل)
├── treasury        :65226/:65227   (محصول ۳ — خزانه‌داری)
├── payroll         :65228/:65229   (محصول ۴ — حقوق و دستمزد)
├── goldshop        :65230/:65231   (محصول ۵ — طلافروشی)
├── store           :65232/:65233   (محصول ۶ — فروشگاه اینترنتی)
└── webapi          :65222/:65223   (تنها بک‌اند)
        └── SQL Server (docker)  HermesMaster  →  [central] [accounting] [inventory] [treasury] [payroll] [goldshop] [store]
```

## 1. Product registry plan (values fixed at planning time)

| App / اپ | Folder / پوشه | Schema | ProjectGuid | HTTPS / HTTP ports | SharedKey (placeholder — rotate on activation) |
|---|---|---|---|---|---|
| accounting | `accounting/` | `accounting` | `8f3c2a11-6b4e-4d9f-a1c7-2e0b9d4f8a31` | 65218 / 65220 | `Hermes-Accounting-Handshake-2026-K7mQ2pL9xR4vN8wC` (موجود) |
| central | `central-client/` | `central` | `1b7e9c44-0d2a-4f18-9e55-6c8a1d3b0f22` | 65219 / 65221 | `Hermes-Central-Handshake-2026-B3tY6hJ1sF5dA0uE` (موجود) |
| inventory | `inventory/` | `inventory` | `462cbfaa-c4aa-4248-acd7-44cab2bb982c` | 65224 / 65225 | `Hermes-Inventory-Handshake-2026-…` |
| treasury | `treasury/` | `treasury` | `25ba213c-d564-436a-aba4-7960dc65ca58` | 65226 / 65227 | `Hermes-Treasury-Handshake-2026-…` |
| payroll | `payroll/` | `payroll` | `f02962a5-a4c4-4f42-adae-06b2f91e4b6e` | 65228 / 65229 | `Hermes-Payroll-Handshake-2026-…` |
| goldshop | `goldshop/` | `goldshop` | `8dd13c7b-1fb6-42f4-943a-7cc9c0204afb` | 65230 / 65231 | `Hermes-Goldshop-Handshake-2026-…` |
| store | `store/` | `store` | `0a9bc93f-8eb3-416c-abaa-666f8181331f` | 65232 / 65233 | `Hermes-Store-Handshake-2026-…` |

**Every new product must also**: add its CORS origin to `Hermes:CorsOrigins` in
`webapi/appsettings.json`; add its URL to `share/HermesApps.cs`; add its
launcher card to `central-client/Pages/Index.razor`; create
`webapi/Data/Scripts/{schema}/_Ensure.sql` + `_Seed.sql`; reference
`blazordeployservice` + `share`; add to `Hermes.slnx`; update
`.agents/hermes-tsql/references/architecture.md` (ports & GUIDs table).

---

## 2. Implementation status (2026-08-12)

| Phase | Status | Notes |
|---|---|---|
| P0-01 Registry + ports | ✅ | 5 پروژه در `Hermes:Projects`، CORS، `HermesApps.cs`، `references/architecture.md` |
| P0-02 Outbox | ✅ | جدول Outbox در همه اسکیمه‌ها + `OutboxProcessor` + مسیرهای رویداد در `Outbox:Routes` |
| P0-03 Audit sidecar | ✅ | `[central].[AuditLog]` با زنجیره هش + ثبت خودکار IsExec + صفحه Audit در central-client |
| P0-04 Contracts manifest | ✅ | `contracts.manifest.json` + `GET /api/contracts` + ۸ DTO در `share` |
| P0-05 Contract tests | ✅ | `tests/Hermes.ContractTests` (شکل، backward-compat، idempotency، E2E) |
| P0-06 docker compose | ✅ | `docker-compose.yml` (SQL Server + webapi) + `webapi/Dockerfile` |
| P0-07 CI + static analysis | ✅ | `ci/ci.yml` (برای فعال‌سازی: انتقال به `.github/workflows/ci.yml` توسط maintainer — توکن GitHub App این sandbox مجوز `workflows` ندارد) + `tools/cross-schema-scan.sh` (اسکن ۸۴ اسکریپت: OK) |
| v2 سازگاری (2026-08-12) | ✅ | کلاینت‌ها به پروتکل v2 منتقل شدند: `RequestServiceCompat.cs` (API قدیمی روی v2)، رفع `RunScriptAsync`/`ResolveProjectGuid`، رفع دیکریپت loginToken در AuthController، پشتیبانی پوشهٔ per-schema در `ExecuteScriptAsync`، ثبت DI سشن v2، `EnsureDatabaseAsync` در startup، appsettings هفت کلاینت v2، `tools/seed-projects-hermes7.ps1` (ثبت ۷ محصول در `dbo.Projects` → HermesMaster + اسکیمه) |
| P0-08 Ops hardening | 🔲 بک‌لاگ | metrics، feature flags، refresh rotation (۱۵ دقیقهٔ توکن انجام شد) — بقیه برای فاز بعدی |
| P1–P5 محصولات | ✅ | انبار، خزانه، حقوق، طلافروشی، فروشگاه — صفحات ۶‌گانه + مدل‌ها + اسکریپت‌ها |
| تکمیل حسابداری (۲۰۲۶/۰۸/۱۲) | ✅ | Entry (سند روزنامهٔ دومرحله‌ای)، Reports (دفتر روزنامه/کل/تراز آزمایشی)، SpecialOperations (بستن دوره) + جدول `DocumentLines` + اسکریپت‌ها + مدل‌ها |
| تکمیل central-client (۲۰۲۶/۰۸/۱۲) | ✅ | News / Blog / Gallery — جدول‌ها + اسکریپت‌های List/Upsert + صفحات |
| Auto-seed پروژه‌ها (۲۰۲۶/۰۸/۱۲) | ✅ | `ProjectSeedInitializer` → ثبت خودکار ۷ پروژه در `dbo.Projects` هنگام startup (تکمیل AC#1 بدون گام دستی) |
| P6 E2E / hardening | 🔲 بک‌لاگ | تست E2E نوشته شده (AC #2)؛ اجرای سخت‌گیرانهٔ <8s در CI با `HERMES_STRICT_E2E=1`؛ DAST و GitOps برای بعد |

> اجرای محلی: `docker compose up --build` ← پس از بالا آمدن webapi در
> `http://localhost:65222`، ۷ پروژه به‌صورت خودکار در `dbo.Projects` ثبت می‌شوند؛
> سپس کلاینت‌ها را با `dotnet run` در پوشه هر محصول بالا بیاورید و از central-client
> (`:65219`) وارد شوید.

## 3. Phases & work items

### Phase 0 — Platform foundations (پلتفرم مشترک، محصول ۷)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P0-01 | Registry + ports plan | 5 new rows in `Hermes:Projects`, CORS origins, `HermesApps.cs` URLs, `architecture.md` port table | handshake of each new app succeeds once its folder exists | — |
| P0-02 | Outbox infrastructure (ADR-002) | `Outbox` table template in each `_Ensure`; `OutboxProcessor` hosted service; idempotency helper scripts (`ApplyOnce` pattern); dead-letter + `/health` outbox depth | outbox rows drain < 5 s; replay is no-op | — |
| P0-03 | Audit sidecar (ADR-002) | `[central].[AuditLog]` + hash chain; `DataController` records every IsExec call; `AuditSearch` script for central-client | every mutation logged with `PrevHash/RowHash`; tamper test passes | — |
| P0-04 | Contracts manifest + DTOs | `contracts.json` source + generator; `/api/contracts` endpoint; DTOs in `share/common/Models` for the 8 PRD contracts (ADR-003) | manifest served; DTO names match SQL aliases | P0-02 |
| P0-05 | Contract test harness | `tests/Hermes.ContractTests` (xUnit): shape, backward-compat, consumer, idempotency tests (ADR-003) | tests run locally & in CI; red on shape change | P0-04, P0-06 |
| P0-06 | docker compose (AC #1) | `docker-compose.yml`: SQL Server 2022 (HermesMaster, sa + env vars), webapi (env-driven connection string), healthchecks | `docker compose up` → `/health` OK + all scripts ensure | — |
| P0-07 | CI + static analysis (AC #3, #4, #5) | GitHub Actions: build/test; cross-schema SQL scan (allow-list header); `contracts.json` freshness check; CodeQL SAST | PR gate green; 0 critical SAST | P0-05, P0-06 |
| P0-08 | Ops hardening | Serilog JSON logs + `RequestId` correlation; `/metrics`; `FeatureFlags` config; AuthN: 15-min token + refresh rotation; TDE/TLS notes | logs correlated; metrics endpoint; tokens rotate | — |

### Phase 1 — Warehouse (انبار آمل) — reference vertical slice

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P1-01 | Report research (Rule #7) | report list doc for انبار: کارتکس کالا، گردش انبار، موجودی (به‌تفکیک انبار)، رسید/حواله، مغایرت، ارزش موجودی | approved list | — |
| P1-02 | Models & scripts | `_Ensure` (Items, Warehouses, Movements, Outbox), `_Seed`; `ItemSearch`, `StockCard`, `MovementInsert` (پست موجودی + outbox `InventoryMovement`), `ReserveStock`/`ReleaseStock` (ADR-002) | scripts run; stock math correct; inventory-movement contract (AC #1/#4) | P0-02, P0-06 |
| P1-03 | Pages | Index (اسناد روز انبار: رسید/حواله + فیلتر از/تا)، Dashboard، Entry، Reports، Settings (کالا/انبار)، SpecialOperations (انبارگردانی) | all pages load via named scripts; seed data visible | P1-02 |
| P1-04 | Registry + launcher | appsettings row, CORS, `HermesApps`, central-client card (فعال), `Hermes.slnx` | از central-client می‌توان با توکن وارد انبار شد | P0-01, P1-03 |
| P1-05 | Contract tests (InventoryMovement) | shape + consumer tests for `InventoryMovement` | green in CI | P0-05 |

### Phase 2 — Treasury (خزانه‌داری)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P2-01 | Report research | صورت مغایرت بانکی، جریان نقد، موجودی صندوق/بانک، چک‌های دریافتی/پرداختی، تنخواه | approved list | — |
| P2-02 | Models & scripts | `_Ensure` (Banks, BankAccounts, CashBoxes, CurrencyRates, CashMovements, Cheques, Outbox) + `_Seed`; `CurrencyRateSearch/Upsert` (contract مالک), `CashMovementInsert` | scripts green; `CurrencyRate` contract (AC #1/#4) | P0-02, P0-06 |
| P2-03 | Pages | Index (گردش روز صندوق/بانک)، Entry (دریافت/پرداخت/انتقال/تنخواه)، Reports، Settings (بانک‌ها/صندوق‌ها/ارزها)، SpecialOperations (بستن روز) | pages load; seed data visible | P2-02 |
| P2-04 | Registry + launcher + contract tests | همانند P1-04/P1-05 برای treasury | handshake + tests green | P0-01, P0-05 |

### Phase 3 — Payroll & HR (حقوق و دستمزد)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P3-01 | Report research | لیست حقوق، فیش حقوقی، سنوات/عیدی، مالیات حقوق، بیمه تأمین اجتماعی، مرخصی/غیبت | approved list | — |
| P3-02 | Models & scripts | `_Ensure` (Employees, Contracts, SalaryItems, PayrollRuns, Outbox) + `_Seed`; `PayrollRunSearch` (contract), `PayrollFinalize` → outbox `PayrollFinalized` | script green; `PayrollRun` contract | P0-02, P0-06 |
| P3-03 | Pages | Index (آخرین دوره‌ها)، Entry (پرسنل/قرارداد/محاسبه حقوق)، Reports، Settings، SpecialOperations (بستن دوره، انتقال به حسابداری و خزانه) | pages load | P3-02 |
| P3-04 | Cross-product consumers | `[accounting].[GLPostFromPayroll]` + `[treasury].[CashMoveFromPayroll]` (idempotent, ADR-002) | dual-write test: finalize → GL + cash rows, replay no-op | P0-02, P2-02 |
| P3-05 | Registry + launcher + tests | همانند قبل + consumer tests برای P3-04 | green | P0-01, P0-05 |

### Phase 4 — Gold-Shop (طلافروشی)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P4-01 | Report research | فاکتور فروش طلا (اجرت/سود/مالیات)، موجودی طلا و ارز، حباب سکه، قیمت روز، سود/زیان | approved list | — |
| P4-02 | Models & scripts | `_Ensure` (GoldItems, GoldPrices, SaleInvoices, Outbox) + `_Seed`; `GoldPriceSearch/Upsert` (contract مالک) → outbox `GoldPriceUpdated`; `SaleInvoiceCreate` → `ReserveStock` (ساگا) | scripts green; `GoldPrice` contract; رزرو انبار کار می‌کند | P0-02, P1-02, P0-06 |
| P4-03 | Pages | Index (فروش روز)، Entry (فاکتور فروش، قیمت روز)، Reports، Settings (طلاجنس‌ها/اجرت‌ها)، SpecialOperations (تسعیر) | pages load | P4-02 |
| P4-04 | Price sync consumers | `[accounting].[GoldPriceSnapshot]` + `[store].[GoldPriceSnapshot]` refresh on `GoldPriceUpdated` | pub/sub test: upsert price → snapshots updated < 5 s | P0-02 |
| P4-05 | Registry + launcher + tests | همانند قبل | green | P0-01, P0-05 |

### Phase 5 — E-Commerce Store (فروشگاه اینترنتی)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P5-01 | Report research | سفارش‌ها، فروش، مشتریان، کوپن/تخفیف، وضعیت ارسال | approved list | — |
| P5-02 | Models & scripts | `_Ensure` (Customers, Products, CartItems, Orders, OrderItems, Outbox) + `_Seed`; `CartUpsert`, `OrderPlace` → outbox `OrderPlaced`; `OrderSearch` (contract مالک) | scripts green; `Order`/`Cart` contract | P0-02, P0-06 |
| P5-03 | Pages | فروشگاه (فهرست محصول + سبد خرید + تسویه)، پنل: Index (سفارش‌های روز)، Entry، Reports، Settings، SpecialOperations (لغو سفارش → جبران رزرو) | checkout flow works end-to-end در localhost | P5-02, P1-02 |
| P5-04 | Invoice consumer | `[accounting].[SalesInvoiceFromOrder]` (idempotent on `OrderId`) | سفارش → فاکتور حسابداری؛ replay no-op | P0-02 |
| P5-05 | Registry + launcher + tests | همانند قبل + consumer tests P5-04 | green | P0-01, P0-05 |

### Phase 6 — Cross-product E2E & hardening (معیارهای پذیرش)

| ID | Work item | Deliverable | Acceptance | Depends |
|----|-----------|-------------|------------|---------|
| P6-01 | E2E gold-order scenario (AC #2) | automated test: store OrderPlaced → inventory reserve → accounting invoice → treasury cash → gold price update; measure total | completes < 8 s; assert all 5 artifacts | P1–P5 |
| P6-02 | SLO checks (AC #2, PRD §6) | script latency p99 < 200 ms; outbox drain < 5 s (load test in CI, soft gate) | metrics collected, thresholds green | P0-08, P6-01 |
| P6-03 | Static analysis gate (AC #3) | cross-schema scan whitelist audited; zero undocumented references | scan green | P0-07 |
| P6-04 | API portal (AC #4) | `contracts.json` + per-product doc pages published (docs + `/api/contracts`) | all 8 contracts documented, v1/v2 examples | P0-04, P1–P5 |
| P6-05 | Security sweep (AC #5) | CodeQL + (first) DAST run; rotate placeholder SharedKeys; admin password change documented | 0 critical | P0-07 |
| P6-06 | GitOps forward-plan (optional) | ADR-004 candidate: Kubernetes/ArgoCD packaging decision, canary for webapi | decision record | P6-02 |

---

## 3. Backlog summary (ordering)

```
P0-06 → P0-02 → P0-03 → P0-04 → P0-05 → P0-01 → P0-07 → P0-08
   │
   └── P1 (vertical slice, reference) ──► P2 ──► P3 ──► P4 ──► P5 ──► P6
```

- P0-06 first (compose) so every later step runs against a real database.
- P1 is the **reference product**: it exercises outbox, audit, contracts, tests,
  and the full page set; phases 2–5 copy its skeleton.

---

## 4. Per-product page blueprint (هر محصول، طبق Rule #7)

| Section | Content rule |
|---|---|
| `Pages/Index.razor` | اسناد/رویدادهای روز با فیلتر **از تاریخ / تا تاریخ** (پیش‌فرض امروز) + جستجو + گرید؛ کلیک روی ردیف → بازکردن سند |
| `Pages/Dashboard.razor` | نمای کلی همهٔ بخش‌ها |
| `Pages/Entry/` | عملیات ورود (ثبت سند/حرکت/فاکتور/سفارش) — Modal-first |
| `Pages/Reports/` | همهٔ گزارشات مصوب از تحقیق P{phase}-01 |
| `Pages/Settings/` | جداول پایه (کالا، انبار، بانک، پرسنل، ارز، …) |
| `Pages/SpecialOperations/` | عملیات الزامی (انبارگردانی، بستن روز/دوره، تسعیر، لغو سفارش) |

UI: فقط HTML + Bootstrap 5.3 + کامپوننت‌های `blazordeployservice`
(`PersianDatePicker`, `SearchableList`, `IAlertService`, `Modal`) — بدون
MudBlazor/Radzen/Tailwind. متن‌ها فارسی، راست‌چین.

---

## 5. Acceptance criteria traceability (PRD §9)

| AC | PRD wording | Delivered by |
|----|-------------|--------------|
| 1 | `docker compose up` + contract tests | P0-06, P0-05 (+P1-05…P5-05) |
| 2 | E2E gold order < 8 s | P6-01, P6-02 |
| 3 | Zero direct DB cross-reads | P0-07 (gate), P0-01 (schema lock), P6-03 (audit) |
| 4 | All APIs documented | P0-04 (manifest), P6-04 (portal) |
| 5 | SAST/DAST 0 critical | P0-07 (CodeQL), P6-05 (sweep + DAST) |

## 6. Definition of done (هر کار)

- [ ] اسکریپت‌های `_Ensure`/`_Seed` اجراشده (محلی + CI) — `IF NOT EXISTS` امن برای اجرای مجدد
- [ ] تست قرارداد مربوطه سبز (شکل + backward-compat + idempotency)
- [ ] صفحه‌ها با دادهٔ seed قابل مشاهده؛ بدون خطای کنسول
- [ ] ارجاع بین‌اسکیمه‌ای فقط با allow-list سربرگ (تحلیل ایستا)
- [ ] docs به‌روز (`PLATFORM_PRD.md` جدول وضعیت، `architecture.md` پورت/GUID)

## 7. Open questions for product teams (به‌هنگام شروع هر فاز)

1. انبار آمل: موجودی به‌تفکیک انبار/محل (location) یا فقط انبار واحد؟ (پیش‌فرض: انبار واحد + ستون location اختیاری)
2. خزانه‌داری: نیاز به چک‌های مدت‌دار و تنخواه‌گردان در v1؟ (پیش‌فرض: بله، جدول چک + تنخواه)
3. حقوق: محاسبهٔ مالیات/بیمه بر اساس قوانین ۱۴۰۵ (جدول‌محور در `TaxRules`) — تأیید فرمول‌ها با کارشناس
4. طلافروشی: اجرت و سود به‌صورت درصد/مبلغ ثابت؟ (پیش‌فرض: هر دو، قابل‌تنظیم در Settings)
5. فروشگاه: پرداخت آنلاین در v1 یا فقط درگاه شبیه‌سازی‌شده؟ (پیش‌فرض: شبیه‌سازی، چون WASM-only)

---

*Roadmap v1.0 — 2026-08-12 · نسخهٔ ۱.۰ — ۱۴۰۵/۰۵/۲۱ — Platform Architecture Team*
