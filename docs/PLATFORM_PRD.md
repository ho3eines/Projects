# PRD – Tarazin — Smart Business Management Platform (v2.2 — Blazor Hybrid, 5 projects)
# PRD – ترازین — مدیریت هوشمند کسب‌وکار (نسخهٔ ۲.۲ — Blazor Hybrid، ۵ پروژه)

> **Status**: Adopted — 2026-08-12 · **Supersedes**: PRD v1.0 (microservices), v1.5 (single webapi + WASM)
> **Binding decisions**: [ADR-001](adr/ADR-001-single-blazor-server-architecture.md),
> [ADR-002](adr/ADR-002-no-event-backbone-direct-sql.md),
> [ADR-003](adr/ADR-003-contracts-shared-models-and-scripts.md),
> [ADR-004](adr/ADR-004-maui-blazor-hybrid.md),
> [ADR-005](adr/ADR-005-share-data-layer-projects.md)
> **Work plan**: [PLATFORM_ROADMAP.md](PLATFORM_ROADMAP.md)

**EN** – Five projects with one-way dependencies host all seven business
applications: `Tarazin.Share` (models/contracts) ← `Tarazin.Data` (data layer:
Dapper + embedded named TSQL scripts) ← `Tarazin.Ui` (shared UI, Razor Class
Library) ← two thin hosts: the web app (`Tarazin.Web`, Blazor Server) and the
MAUI app (`Tarazin.Maui`, MAUI Blazor Hybrid in a BlazorWebView). Each product
is a *bounded context*: a module (`Modules/{Name}/` in `Tarazin.Ui`) and one
private SQL schema (`Data/Scripts/{schema}/` in `Tarazin.Data`, embedded
resources). There is no web service, no WASM client, no HTTP data layer: UI
and data access run in the same process. The UI is built exclusively with
MudBlazor.

**FA** – پنج پروژه با وابستگی یک‌طرفه همهٔ هفت محصول تجاری را میزبانی می‌کنند:
`Tarazin.Share` (مدل‌ها/قراردادها) ← `Tarazin.Data` (لایهٔ داده: Dapper +
اسکریپت‌های TSQL نامدار Embedded) ← `Tarazin.Ui` (رابط کاربری مشترک — RCL) ←
دو هاست نازک: وب (`Tarazin.Web` — Blazor Server) و اپ MAUI (`Tarazin.Maui` —
MAUI Blazor Hybrid داخل BlazorWebView). هر محصول یک *bounded context* است: یک
ماژول (`Modules/{Name}/` در `Tarazin.Ui`) و یک اسکیمهٔ SQL خصوصی
(`Data/Scripts/{schema}/` در `Tarazin.Data` — Embedded). هیچ وب‌سرویس، هیچ
کلاینت WASM و هیچ لایهٔ HTTP برای داده وجود ندارد: UI و لایهٔ داده در یک
پروسه‌اند. رابط کاربری فقط با MudBlazor ساخته می‌شود.

---

## Products / محصولات (7)

| # | Product / محصول | Module / ماژول (در `Tarazin.Ui/`) | Schema / اسکیمه | Route / مسیر | Status |
|---|---|---|---|---|---|
| 1 | Accounting / حسابداری | `Modules/Accounting` | `accounting` | `/accounting` | ✅ پیاده‌سازی‌شده |
| 2 | Warehouse Mgmt – Amol Anbar / انبار آمل | `Modules/Inventory` | `inventory` | `/inventory` | ✅ پیاده‌سازی‌شده |
| 3 | Treasury / خزانه‌داری | `Modules/Treasury` | `treasury` | `/treasury` | ✅ پیاده‌سازی‌شده |
| 4 | Payroll & HR / حقوق و دستمزد | `Modules/Payroll` | `payroll` | `/payroll` | ✅ پیاده‌سازی‌شده |
| 5 | Gold-Shop Mgmt / طلافروشی | `Modules/GoldShop` | `goldshop` | `/goldshop` | ✅ پیاده‌سازی‌شده |
| 6 | E-Commerce Store / فروشگاه | `Modules/Store` | `store` | `/store` | ✅ پیاده‌سازی‌شده |
| 7 | Core Platform / پلتفرم مشترک | `Modules/Central` | `central` | `/central` | ✅ پیاده‌سازی‌شده |

## 1. Vision / دیدگاه کلی

**EN** – Deliver a single, extensible UI core that runs everywhere: browser and
native desktop/mobile. Each product is a bounded context (module + schema).
Cross-module work happens directly in server-side scripts, in one process — no
async event backbone, no message queue.

**FA** – ارائهٔ یک هستهٔ UI واحد و قابل گسترش که همه‌جا اجرا می‌شود: مرورگر و
دسکتاپ/موبایل بومی. هر محصول یک bounded context است (ماژول + اسکیمه). کار
بین‌ماژولی مستقیم در اسکریپت‌های سمت سرور و در یک پروسه انجام می‌شود — بدون
بک‌بون رویداد.

## 2. High-Level Architecture / معماری سطح بالا

| Layer / لایه | Responsibility / وظیفه | Tech / سازوکار |
|---|---|---|
| Share | Models/contracts (POCO) | `Tarazin.Share` (namespace `Tarazin.Models`) |
| Data Access | Named-script execution, schema scope | `Tarazin.Data` — `DbService` + Dapper (in-process) |
| Presentation (مشترک) | All pages/forms/tables/modals | `Tarazin.Ui` (RCL) + **MudBlazor** |
| Host — Web | Serve the shared UI in the browser | `Tarazin.Web` — Blazor Server (SignalR) |
| Host — MAUI | Serve the shared UI in a native app | `Tarazin.Maui` — MAUI Blazor Hybrid (BlazorWebView) |
| Application | Orchestration inside pages | `Modules/*/Pages/*.razor` + `Services/` |
| Data | One DB `TarazinMaster`, one schema per product | SQL Server (docker compose) |
| Auth & Audit | Login, session, hash-chained audit | `AuthService`, `UserSession`, `AuditService` |
| DevOps | Build web + build MAUI + static analysis | `ci/ci.yml`, `tools/cross-schema-scan.sh` |

> **Rule** – No module ever embeds raw SQL or calls another module's schema
> directly. Cross-schema reads are declared in server-side scripts
> (`-- Cross-schema: …`).

## 3. Shared Domain Contracts / قراردادهای دامنه مشترک

Defined as C# models in `Tarazin.Share/Models/SharedModels.cs`; script columns must
match (ADR-003):

| Contract / قرارداد | Owner / مالک | Consumers / مصرف‌کننده‌ها |
|---|---|---|
| `PartyRow` | central | همهٔ ماژول‌ها |
| `ChartOfAccountRow` | accounting | treasury, payroll, goldshop, store |
| `CurrencyRateRow` | treasury | accounting, goldshop, store |
| `TaxRuleRow` | accounting | payroll, goldshop, store |
| `InventoryMovementRow` | inventory | accounting, goldshop, store |
| `PayrollRunRow` | payroll | accounting, treasury |
| `GoldPriceRow` | goldshop | accounting, store |
| `OrderRow` / `CartItemRow` | store | inventory, accounting, treasury |

## 4. Integration / یکپارچگی (بدون رویداد)

| Scenario / سناریو | Old (v1.5) | New (v2) |
|---|---|---|
| Sale invoice → accounting | Event via Outbox | Direct script call in the same process (server-side, transactional) |
| Stock reservation | Saga events | `ReserveStockForOrder.sql` executed server-side |
| Payroll posting | `PayrollFinalized` event → dual-write | Server-side call chain |
| Gold price sync | Pub/Sub topic | `RefreshGoldPrice.sql` called directly |
| Audit trail | Outbox + sidecar | `AuditService` → `[central].[AuditLog]` (hash chain) |

ADR-002 explains why the event backbone was retired.

## 5. Security & Compliance / امنیت

* **AuthN** – username/password → `AuthService` (PBKDF2) against `[central].[Users]`.
* **Session** – per SignalR circuit (`UserSession`); nothing secret is shipped to the browser.
* **Audit** – every mutating script recorded to `[central].[AuditLog]` with SHA-256 hash chain.
* **Schema isolation** – `DbService` takes the schema; scripts are fully qualified.
* **Server-side only** – WASM secret-leak class of problems is gone by construction.

## 6. Observability / نظارت
* Structured logs via `ILogger` per service; audit log is the business observability surface.
* `/central/audit` page for filtering operations by schema/script/outcome.

## 7. Deployment / استقرار
* `docker compose up -d` → SQL Server only.
* `dotnet run --project Tarazin` (or `dotnet publish Tarazin -c Release`).
* CI: restore + build + `tools/cross-schema-scan.sh` (GitHub Actions).

## 8. Risks & Mitigations / ریسک‌ها
| Risk | Impact | Mitigation |
|------|--------|------------|
| One process = one failure domain | All modules down together | Startup health/ensure; audit trail for diagnosis |
| Script drift across schemas | Broken cross-module flows | `tools/cross-schema-scan.sh` + code review |
| Monolith growth | Harder team parallelism | Module folders + schema boundaries + per-module pages |

## 9. Acceptance Criteria / معیارهای پذیرش
1. `dotnet build Tarazin.slnx` succeeds with exactly one project.
2. All 9 modules open from one address and show real data.
3. No `HttpClient`-for-data and no raw SQL in `.razor` files (static check).
4. `tools/cross-schema-scan.sh` passes.
5. Bootstrap login works; audit rows are recorded and viewable.

## 10. Glossary / واژه‌نامه
| EN | FA |
|----|----|
| Bounded Context | محدودهٔ بندی |
| Module | ماژول |
| Named script | اسکریپت نامدار |
| Schema | اسکیمه |

---
*Document version 2.0 – 2026-08-12 · Prepared by Platform Architecture Team*
