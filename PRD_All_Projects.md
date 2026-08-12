# PRD – Unified Multi‑Product Platform
**Products (7)**  
1. Accounting (حسابداری)  
2. Warehouse Management – Amol Anbar (انبار امول)  
3. Treasury (خزانه‌داری)  
4. Payroll & HR (حقوق و دستمزد)  
5. Gold‑Shop Management (نرم‌افزار مدیریت طلا فروشی)  
6. E‑Commerce Store (فروشگاه اینترنتی)  
7. Core Platform Services (پلتفرم مشترک)

---  

## 1. Vision / دیدگاه کلی
**EN** – Deliver a single, extensible micro‑service platform that hosts all seven business applications.  Each product is a *bounded context* that communicates only through well‑versioned APIs and an event backbone.  No product owns a private database schema that other products read directly.  

**FA** – ارائه یک پلتفرم میکروسرویس واحد و قابل گسترش که هفت محصول تجاری را میزبانی کند. هر محصول یک *bounded context* است که تنها از طریق APIهای نسخه‑دار و یک بکبون رویدادها (event backbone) با دیگران صحبت می‌کند. هیچ محصولی اسکیمای دیتابیس خصوصی ندارد که بقیه مستقیماً بخوانند.

---  

## 2. High‑Level Architecture / معماری سطح بالا
| Layer / لایه | Responsibility / وظیفه | Tech Stack / تکنولوژی |
|--------------|------------------------|------------------------|
| **API Gateway** | Auth, routing, rate‑limit, request/response transformation | Kong / Traefik + OIDC |
| **Service Mesh** | mTLS, observability, retries, circuit‑break | Istio / Linkerd |
| **Event Backbone** | Async integration, eventual consistency | Kafka (Avro schemas, Schema Registry) |
| **Core Services** | Shared domain: Party, ChartOfAccounts, Currency, TaxEngine, AuditLog | .NET 8 / Java 21 (polyglot allowed) |
| **Product Services** | One deployable per product (7 services) | Same stack as core, independent CI/CD |
| **Data Layer** | Each service owns its DB (PostgreSQL); read‑models via CDC → Elasticsearch / ClickHouse | PostgreSQL 16, Debezium CDC |
| **Front‑End Shell** | Micro‑frontend host (Module Federation) – one SPA per product, shared UI library | React 18 + Vite + Tailwind |
| **DevOps** | GitOps (ArgoCD), Helm charts, shared pipelines | Kubernetes 1.29, Helm, Kustomize |

> **Rule** – *No direct DB access across services*.  All cross‑product reads go through **Core Services** or **Event projections**.

---  

## 3. Shared Domain Contracts / قراردادهاهای دامنه مشترک
| Contract | Owner | Consumers | Versioning |
|----------|-------|-----------|------------|
| `Party` (Customer, Vendor, Employee) | Core | All | v1 → v2 (add `nationalId`) |
| `ChartOfAccount` | Accounting | Treasury, Payroll, GoldShop, E‑Com | v1 |
| `CurrencyRate` | Treasury | Accounting, GoldShop, E‑Com | v1 |
| `TaxRule` | Accounting | Payroll, GoldShop, E‑Com | v1 |
| `InventoryMovement` | Warehouse | Accounting, GoldShop, E‑Com | v1 |
| `PayrollRun` | Payroll | Accounting, Treasury | v1 |
| `GoldPrice` | GoldShop | Accounting, E‑Com | v1 |
| `Order` / `Cart` | E‑Com | Warehouse, Accounting, Treasury | v1 |

All contracts are **Protobuf/Avro** + **OpenAPI** for REST facades.  Schema Registry enforces backward compatibility.

---  

## 4. Integration Patterns / الگوهای یکپارچگی
| Scenario | Pattern | Details |
|----------|---------|---------|
| Create Sales Invoice (E‑Com → Accounting) | **Command → Event** | `OrderPlaced` event → Accounting creates `SalesInvoice` (idempotent) |
| Stock Reservation (Warehouse ← GoldShop/E‑Com) | **Saga (orchestrated)** | `ReserveStock` command → `StockReserved` / `StockRejected` events |
| Payroll Posting (Payroll → Accounting + Treasury) | **Dual‑write via Event** | `PayrollFinalized` → Accounting posts GL, Treasury moves cash |
| Daily Gold Price Sync (GoldShop → all) | **Pub/Sub** | `GoldPriceUpdated` topic, consumers rebuild read‑models |
| Audit Trail (All) | **Side‑car CDC** | Debezium → `AuditLog` topic → immutable store (Append‑only) |

---  

## 5. Security & Compliance / امنیت و انطباق
* **AuthN** – Central OIDC (Keycloak) + short‑lived JWT (15 min) + refresh token rotation.  
* **AuthZ** – RBAC + ABAC policies evaluated in API Gateway (OPA).  
* **Data Protection** – Encryption‑at‑rest (LUKS + Transparent DB encryption), TLS 1.3 everywhere.  
* **Audit** – Every mutating command logged to `AuditLog` (tamper‑evident via hash‑chain).  
* **Regulatory** – Persian‑locale tax rules engine, GDPR‑style data‑subject APIs.

---  

## 6. Observability / نظارت
* **Metrics** – Prometheus + Grafana dashboards per service + golden signals.  
* **Traces** – OpenTelemetry → Jaeger (100 % sampling for error traces).  
* **Logs** – Structured JSON → Loki, correlated via `traceId`.  
* **SLOs** – 99.9 % API latency < 200 ms, 99.95 % event processing < 5 s.

---  

## 7. Deployment & Release Strategy / استراتژی استقرار
* **Monorepo** – `platform/` (core, infra) + `products/<name>/`  
* **GitOps** – Each product has its own ArgoCD Application; core platform promoted separately.  
* **Canary** – Istio traffic‑split 5 % → 100 % after automated contract tests.  
* **Database Migrations** – Flyway per service, run in pre‑deploy hook, backward‑compatible.  
* **Feature Flags** – LaunchDarkly / Unleash for gradual rollout.

---  

## 8. Risks & Mitigations / ریسک‌ها و کاهش‌ها
| Risk | Impact | Mitigation |
|------|--------|------------|
| Schema drift between services | Data corruption | Schema Registry + contract tests in CI |
| Distributed transaction complexity | Inconsistent state | Saga orchestration + idempotent consumers |
| Team autonomy vs shared platform | Bottlenecks | Clear ownership: Core team owns platform, product teams own services |
| Persian‑specific tax/legal changes | Compliance failure | Config‑driven TaxEngine, hot‑reload rules |

---  

## 9. Acceptance Criteria / معیارهای پذیرش
1. All 7 product services start locally via `docker compose up` and pass contract tests.  
2. End‑to‑end scenario: *Customer places gold order on E‑Com → Warehouse reserves → Accounting issues invoice → Treasury records cash → GoldShop updates price* completes in < 8 s.  
3. Zero direct DB cross‑reads detected by static analysis.  
4. All APIs documented in OpenAPI + Protobuf, published to internal portal.  
5. Security scan (SAST/DAST) shows **0 critical** findings.  

---  

## 10. Glossary / واژه‌نامه
| EN | FA |
|----|----|
| Bounded Context | محدودهٔ بندی |
| Event Backbone | بکبون رویدادها |
| Saga | ساگا (تراکنش توزیعی) |
| CDC | Change Data Capture |
| Micro‑frontend | مایکروفرانت‌اند |

---  

*Document version 1.0 – 2026‑08‑12*  
*Prepared by Platform Architecture Team*  

---  

# PRD – پلتفرم یکپارچه چندمحصوله (نسخه فارسی)

## 1. دیدگاه کلی
ارائه یک پلتفرم میکروسرویس واحد و قابل گسترش که هفت محصول تجاری را میزبانی کند. هر محصول یک *bounded context* است که تنها از طریق APIهای نسخه‑دار و یک بکبون رویدادها (event backbone) با دیگران صحبت می‌کند. هیچ محصولی اسکیمای دیتابیس خصوصی ندارد که بقیه مستقیماً بخوانند.

## 2. معماری سطح بالا
(جدول مشابه بالا – ترجمه شده)

## 3. قراردادهاهای دامنه مشترک
(مشابه بالا)

## 4. الگوهای یکپارچگی
(مشابه بالا)

## 5. امنیت و انطباق
(مشابه بالا)

## 6. نظارت
(مشابه بالا)

## 7. استراتژی استقرار
(مشابه بالا)

## 8. ریسک‌ها و کاهش‌ها
(مشابه بالا)

## 9. معیارهای پذیرش
(مشابه بالا)

## 10. واژه‌نامه
(مشابه بالا)

---  

*نسخه ۱.۰ – ۱۴۰۳/۰۵/۲۱*  
*تهیه شده توسط تیم معماری پلتفرم*