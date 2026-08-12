# PRD – Unified Multi-Product Platform (Hermes Edition)
# PRD – پلتفرم یکپارچه چندمحصوله (نسخهٔ هرمس)

> **Status**: Adopted — 2026-08-12 · **Supersedes**: PRD v1.0 (2026-08-12) architectural assumptions
> **Binding decisions**: [ADR-001](adr/ADR-001-single-webapi-architecture.md), [ADR-002](adr/ADR-002-events-outbox-and-sagas.md), [ADR-003](adr/ADR-003-contracts-and-contract-tests.md)
> **Work plan**: [PLATFORM_ROADMAP.md](PLATFORM_ROADMAP.md)

**EN** – This document is the original product PRD mapped onto the Hermes
platform. Every product goal, contract, and integration scenario is preserved;
the *mechanisms* (microservices, Kafka, Kubernetes, React) are replaced by
Hermes mechanisms (single webapi + named TSQL, per-schema outbox, docker
compose, Blazor WASM). Where a mechanism changes, the ADR explains why.

**FA** – این سند همان PRD محصولات است که روی پلتفرم هرمس پیاده می‌شود. تمام
اهداف محصول، قراردادها و سناریوهای یکپارچگی حفظ شده؛ اما *سازوکارها*
(میکروسرویس، کافکا، کوبرنیتس، ری‌اکت) با سازوکارهای هرمس (یک webapi +
اسکریپت‌های TSQL نامدار، outbox به‌ازای هر اسکیمه، docker compose، بلِیزِر WASM)
جایگزین شده‌اند. هر جا سازوکاری تغییر کرده، ADR دلیلش را توضیح داده است.

---

## Products / محصولات (7)

| # | Product / محصول | Hermes app / پروژه | Schema / اسکیمه | Status / وضعیت |
|---|---|---|---|---|
| 1 | Accounting / حسابداری | `accounting/` | `accounting` | ✅ پیاده‌سازی‌شده (قراردادهای ChartOfAccount / TaxRule) |
| 2 | Warehouse Mgmt – Amol Anbar / انبار آمل | `inventory/` | `inventory` | ✅ پیاده‌سازی‌شده |
| 3 | Treasury / خزانه‌داری | `treasury/` | `treasury` | ✅ پیاده‌سازی‌شده |
| 4 | Payroll & HR / حقوق و دستمزد | `payroll/` | `payroll` | ✅ پیاده‌سازی‌شده |
| 5 | Gold-Shop Mgmt / مدیریت طلافروشی | `goldshop/` | `goldshop` | ✅ پیاده‌سازی‌شده |
| 6 | E-Commerce Store / فروشگاه اینترنتی | `store/` | `store` | ✅ پیاده‌سازی‌شده |
| 7 | Core Platform Services / پلتفرم مشترک | `central-client/` + `webapi/` + `share/` + `blazordeployservice/` | `central` | ✅ پیاده‌سازی‌شده (فاز ۰: outbox، audit، قراردادها، compose، CI، تست‌ها) |

> وضعیت «پیاده‌سازی‌شده» = کد/اسکریپت کامل در مخزن؛ تأیید نهایی با
> `docker compose up` + `dotnet test` در CI (که در این sandbox به دلیل مسدود بودن
> دسترسی به NuGet/Microsoft قابل اجرا نبود — workflow آماده است).

> **Note**: «انبار امول» در PRD اصلی به‌صورت «امول» نوشته شده؛ نام صحیح فارسی
> «انبار آمل» است. نام محصول و اسکیمه (`inventory`) تغییری نمی‌کند.

---

## 1. Vision / دیدگاه کلی

**EN** – Deliver a single, extensible platform that hosts all seven business
applications. Each product is a *bounded context* — a client-only Blazor WASM
app and **one private SQL schema** — that communicates only through
well-versioned named scripts and the event backbone. No product reads another
product's schema directly: the schema lock in the project registry makes that
impossible for clients, and the CI cross-schema gate (ADR-003) audits server
scripts.

**FA** – ارائه یک پلتفرم واحد و قابل گسترش که هفت محصول تجاری را میزبانی کند.
هر محصول یک *bounded context* — یک اپ بلِیزِر WASM (فقط کلاینت) و **یک اسکیمهٔ
خصوصی SQL** — است که فقط از طریق اسکریپت‌های نامدار نسخه‌دار و بک‌بون رویدادها
ارتباط برقرار می‌کند. هیچ محصولی مستقیم اسکیمهٔ محصول دیگر را نمی‌خواند: قفل
اسکیمه در پروژه‌رجیستری این را برای کلاینت‌ها غیرممکن و دروازهٔ CI اسکریپت‌ها را
حسابرسی می‌کند (ADR-003).

## 2. High-Level Architecture / معماری سطح بالا

| Layer / لایه | PRD assumption | Hermes realization / پیاده‌سازی هرمس |
|---|---|---|
| API Gateway | Kong/Traefik + OIDC | `webapi` — `AuthController` (handshake + login)، `DataController` (اسکریپت نامدار رمزشده)، `HandshakeGuard` (محدودیت ۵/دقیقه/IP)، CORS |
| Service Mesh | Istio/Linkerd | اعمال نمی‌شود — یک deployable؛ تاب‌آوری با idempotent مصرف‌کننده‌ها + outbox |
| Event Backbone | Kafka + Avro | جدول `Outbox` در هر اسکیمه + سرویس `OutboxProcessor` در webapi (ADR-002) |
| Core Services | Party, ChartOfAccounts, Currency, TaxEngine, AuditLog | اسکیمهٔ `central` + DTOهای `share` + اسکریپت‌های نامدار؛ AuditLog به‌صورت sidecar (ADR-002) |
| Product Services | ۷ سرویس مستقل | ۷ کلاینت WASM در همان solution؛ CI مشترک با تست قرارداد به‌ازای هر محصول |
| Data Layer | PostgreSQL + CDC | یک SQL Server (`HermesMaster`)؛ یک اسکیمه به‌ازای هر محصول؛ read-model از طریق اسکریپت‌های سمت سرور |
| Front-End Shell | React 18 + Module Federation | `central-client` (لاuncher) + `blazordeployservice` (UI مشترک، Bootstrap 5.3) |
| DevOps | Kubernetes + ArgoCD | `docker compose` برای اجرای محلی + GitHub Actions؛ GitOps در فاز ۶ (آینده) |

> **Rule / قانون** – *No direct DB access across services.* در هرمس: کلاینت فقط
> اسکریپت‌های اسکیمهٔ خودش را اجرا می‌کند (قفل اسکیمه از رجیستری)؛ هر خواندن
> بین‌محصولی از طریق اسکریپت‌های سمت سرورِ اسکیمهٔ مالک انجام می‌شود و توسط
> تست قرارداد و تحلیل ایستا بررسی می‌گردد.

## 3. Shared Domain Contracts / قراردادهای دامنه مشترک

| Contract | Owner / مالک | Consumers / مصرف‌کننده‌ها | Hermes artifact / مصنوع هرمس |
|---|---|---|---|
| `Party` (Customer, Vendor, Employee) | Core (`central`) | All | `[central].[Parties]` + `PartySearch/PartyUpsert` + DTO `PartyRow` |
| `ChartOfAccount` | Accounting | Treasury, Payroll, GoldShop, E-Com | `[accounting].[ChartOfAccounts]` + اسکریپت‌ها + DTO `ChartOfAccountRow` |
| `CurrencyRate` | Treasury | Accounting, GoldShop, E-Com | `[treasury].[CurrencyRates]` + اسکریپت‌ها + DTO `CurrencyRateRow` |
| `TaxRule` | Accounting | Payroll, GoldShop, E-Com | `[accounting].[TaxRules]` + اسکریپت‌ها + DTO `TaxRuleRow` |
| `InventoryMovement` | Warehouse | Accounting, GoldShop, E-Com | `[inventory].[InventoryMovements]` + اسکریپت‌ها + DTO `InventoryMovementRow` |
| `PayrollRun` | Payroll | Accounting, Treasury | `[payroll].[PayrollRuns]` + اسکریپت‌ها + DTO `PayrollRunRow` |
| `GoldPrice` | GoldShop | Accounting, E-Com | `[goldshop].[GoldPrices]` + اسکریپت‌ها + DTO `GoldPriceRow` |
| `Order` / `Cart` | E-Com | Warehouse, Accounting, Treasury | `[store].[Orders]` + `[store].[CartItems]` + اسکریپت‌ها + DTO `OrderRow` |

- نسخه‌بندی: پسوند `_V2` برای اسکریپت‌ها و DTOهای جدید؛ نگه‌داشتن نسخهٔ قدیمی تا
  مهاجرت کامل مصرف‌کننده‌ها (فقط افزودن فیلد، هرگز حذف) — ADR-003.
- رجیستری قراردادها: `contracts.json` سروشده در `/api/contracts`؛ رجیستری
  اسکیمه‌ها: بخش `Hermes:Projects` در `appsettings.json`.

## 4. Integration Patterns / الگوهای یکپارچگی

| Scenario / سناریو | PRD pattern | Hermes implementation / پیاده‌سازی |
|---|---|---|
| Create Sales Invoice (E-Com → Accounting) | Command → Event | `OrderPlaced` در outbox اسکیمهٔ `store` → `[accounting].[SalesInvoiceFromOrder]` (idempotent روی `OrderId`) |
| Stock Reservation (Warehouse ← GoldShop/E-Com) | Saga (orchestrated) | اسکریپت سرویس‌محور `StoreReserveStock` → `StockReserved` / `StockRejected`؛ جبران با `[inventory].[ReleaseStock]` |
| Payroll Posting (Payroll → Accounting + Treasury) | Dual-write via Event | `PayrollFinalized` → دو مصرف‌کننده: `[accounting].[GLPostFromPayroll]` و `[treasury].[CashMoveFromPayroll]` |
| Daily Gold Price Sync (GoldShop → all) | Pub/Sub | `GoldPriceUpdated` → بازسازی read-modelها (`GoldPriceSnapshot` در accounting و store) |
| Audit Trail (All) | Side-car CDC | ثبت خودکار هر فراخوانی IsExec در `[central].[AuditLog]` با زنجیرهٔ هش — بدون CDC (ADR-002) |

## 5. Security & Compliance / امنیت و انطباق

| PRD item | Hermes realization |
|---|---|
| Central OIDC (Keycloak) + 15-min JWT | لاگین متمرکز در `central-client` + JWT امضاشده با HMAC (`Auth:Key`)؛ **بک‌لاگ (P0-08)**: کاهش `AccessTokenMinutes` به ۱۵ دقیقه + refresh-token rotation |
| RBAC + ABAC در گیت‌وی (OPA) | RBAC در `UserDirectory` (نقش روی کاربر)؛ **بک‌لاگ**: جدول `[central].[ScriptPermissions]` برای مجوز به‌ازای اسکریپت |
| Encryption-at-rest (LUKS/TDE) + TLS 1.3 | رمزنگاری AES حمل‌ونقل (handshake + Data) + HTTPS؛ **بک‌لاگ**: TDE و TLS 1.3 در تولید |
| Audit (hash-chain) | `[central].[AuditLog]` با زنجیرهٔ هش — از هفتهٔ اول (P0-03) |
| Persian tax rules + GDPR-style APIs | موتور مالیاتی جدول‌محور در `TaxRules` (بارگذاری مجدد از DB، بدون rebuild)؛ APIهای دادهٔ شخصی در `central-client` (بک‌لاگ) |

## 6. Observability / نظارت

| PRD item | Hermes realization |
|---|---|
| Prometheus + Grafana | **P0-08**: endpoint `/metrics` (شمارندهٔ درخواست، تأخیر، عمق outbox) + Grafana |
| OpenTelemetry → Jaeger | **P0-08**: همبستگی با `RequestId` در لاگ‌های ساخت‌یافته JSON (Serilog) — بدون tracer جدا |
| Structured JSON → Loki | لاگ‌های JSON ساخت‌یافته با `traceId`/`requestId` (P0-08) |
| SLOs | تأخیر p99 هر اسکریپت < ۲۰۰ms؛ پردازش رویداد (تخلیهٔ outbox) < ۵ ثانیه؛ سناریوی E2E طلا < ۸ ثانیه (AC #2) |

## 7. Deployment & Release Strategy / استراتژی استقرار

| PRD item | Hermes realization |
|---|---|
| Monorepo | همین مخزن: پلتفرم (`webapi`, `central-client`, `share`, `blazordeployservice`) + محصولات در پوشه‌های ریشه |
| GitOps / ArgoCD | **فاز ۶** (آینده). اکنون: `docker compose up` + GitHub Actions |
| Canary | به‌ازای محصولات WASM معنادار نیست (کلاینت)؛ برای `webapi` در فاز ۶ |
| DB Migrations (Flyway) | اسکریپت‌های idempotent `_Ensure.sql` (اجراشده در startup) — معادل Flyway؛ فقط افزودن ستون (backward-compatible) |
| Feature Flags | **P0-08**: بخش `FeatureFlags` در appsettings (یا جدول `[central].[FeatureFlags]`) |

## 8. Risks & Mitigations / ریسک‌ها و کاهش‌ها

| Risk / ریسک | Impact | Mitigation در هرمس |
|---|---|---|
| Schema drift / انحراف اسکیمه بین محصولات | خرابی داده | تست قرارداد + تحلیل ایستا در CI (ADR-003) |
| Distributed transaction complexity | وضعیت ناسازگار | Saga سرویس‌محور + مصرف‌کننده‌های idempotent (ADR-002) |
| Team autonomy vs shared platform | گلوگاه | مالکیت صریح: تیم پلتفرم = webapi/central/share؛ تیم محصول = اسکیمه و صفحات خود |
| Persian tax/legal changes | عدم انطباق | TaxEngine جدول‌محور با بارگذاری مجدد داغ (بدون deploy) |
| SQL Server تک‌نقطه | قطعی سرویس | healthcheck در compose + بکاپ؛ ریپلیکا در فاز ۶ |

## 9. Acceptance Criteria / معیارهای پذیرش

| # | PRD criterion | Hermes interpretation / تفسیر هرمس | Where / کجا |
|---|---|---|---|
| 1 | All 7 services start via `docker compose up` + contract tests | همهٔ ۷ اپ (۵ محصول جدید + accounting + central) در compose بالا بیایند و `tests/Hermes.ContractTests` سبز باشد | P0-05, P0-06 |
| 2 | E2E gold order < 8 s | سناریوی تست: ثبت سفارش طلا در store → رزرو انبار → صدور فاکتور حسابداری → ثبت نقد خزانه → به‌روزرسانی قیمت طلا؛ کل مسیر < ۸ ثانیه | P6-01 |
| 3 | Zero direct DB cross-reads (static analysis) | قفل اسکیمه (رجیستری) + اسکن CI روی اسکریپت‌ها؛ ارجاع بین‌اسکیمه‌ای فقط با اعلان allow-list سربرگ | P0-07 |
| 4 | All APIs documented (OpenAPI/Protobuf) | `contracts.json` در `/api/contracts` + DTOهای `share` + راهنمای هر محصول در docs | P0-04, P0-07 |
| 5 | SAST/DAST: 0 critical | اسکن CodeQL (و در ادامه DAST) در CI؛ دروازهٔ ۰ بحرانی | P0-07 |

## 10. Glossary / واژه‌نامه

| EN | FA | Hermes meaning |
|----|----|----------------|
| Bounded Context | محدودهٔ بندی | یک محصول = یک اپ WASM + یک اسکیمهٔ SQL خصوصی |
| Event Backbone | بک‌بون رویدادها | جدول `Outbox` هر اسکیمه + `OutboxProcessor` در webapi |
| Saga | ساگا (تراکنش توزیعی) | زنجیرهٔ اسکریپت‌های سرویس‌محور با جبران (compensation) |
| CDC | Change Data Capture | استفاده نمی‌شود؛ به‌جای آن audit sidecar در webapi |
| Micro-frontend | مایکروفرانت‌اند | کلاینت‌های Blazor WASM + `blazordeployservice` |
| Named script | اسکریپت نامدار | فایل `{schema}/{Name}.sql` — تنها سطح دادهٔ کلاینت |
| Outbox | صندوق خروجی | جدول رویداد هر محصول که با دادهٔ کسب‌وکار در یک تراکنش نوشته می‌شود |

---

*Document version 2.0 (Hermes Edition) — 2026‑08‑12 · نسخهٔ ۲.۰ — ۱۴۰۵/۰۵/۲۱*

*Prepared by Platform Architecture Team / تهیه‌شده توسط تیم معماری پلتفرم*

> اصلاح: تاریخ شمسی نسخهٔ ۱.۰ (۱۴۰۳/۰۵/۲۱) با تاریخ میلادی آن (۲۰۲۶‑۰۸‑۱۲) ناهماهنگ بود؛ نسخهٔ ۲.۰ از ۱۴۰۵/۰۵/۲۱ استفاده می‌کند که معادل 2026‑08‑12 است.
