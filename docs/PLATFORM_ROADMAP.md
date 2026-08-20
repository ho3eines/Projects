# Platform Roadmap — 7-Module Tarazin Platform (Blazor Hybrid — 5 projects)

> **Date**: 2026-08-12 · **Branches from**: PRD v2.2 — `docs/PLATFORM_PRD.md`
> **Decisions**: ADR-001..005 (Share/Data/Ui layering + two hosts)
> **Rule of thumb**: هر ماژول = گزارش‌محور؛ اول تحقیق گزارشات، بعد مدل‌ها و اسکریپت‌ها، بعد صفحات.

---

## 0. Target topology

```
Tarazin.Share (models) ← Tarazin.Data (data layer, embedded scripts) ← Tarazin.Ui (UI RCL)
├── Tarazin.Web   → Blazor Server + mobile login endpoint (HTTPS)
└── Tarazin.Maui  → local shared login; one-time POST /api/mobile/connection → encrypted connection string → in-memory decrypt
        └── existing direct DbService operations → SQL Server / TarazinMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

No separate ports per product, no public CRUD web API, no WASM clients, and no
HTTP business-data layer. The mobile connection bootstrap endpoint is the narrow exception.

## 1. Implementation status (2026-08-12)

| Step | Status | Notes |
|---|---|---|
| Delete 11 old projects (webapi, 7 WASM clients, share, blazordeployservice, tests) | ✅ | `Tarazin.slnx` → ۵ پروژه |
| Create `Tarazin.Share` (models) + `Tarazin.Data` (data layer) + `Tarazin.Ui` (RCL) | ✅ | وابستگی یک‌طرفه؛ ۴۴ مسیر صفحه |
| Create `Tarazin.Web` (Blazor Server host) | ✅ | `AddServerSideBlazor` + MudBlazor + `AddTarazinUiServices` |
| Create `Tarazin.Maui` (MAUI Blazor Hybrid host) | ✅ | BlazorWebView → `Tarazin.App`؛ Platforms/Resources کامل |
| Scripts as embedded resources (in `Tarazin.Data`) | ✅ | `ScriptCatalog` خودکار در ctor؛ `TarazinDbInitializer` مشترک |
| Data layer (`ScriptCatalog`, `DbService`, `ICurrentUser`) | ✅ | named TSQL + Dapper, in-process؛ بدون وابستگی به Ui |
| Auth (login, bootstrap admin, users page) | ✅ ایستا | PBKDF2؛ Web per-circuit؛ MAUI broker با customer/session/nonce |
| Credential hardening + mobile RLS | ✅ ایستا / 🔲 پویا | endpoint-only config، credential موقت، revoke/cleanup، tenant ownership؛ SQL واقعی لازم است |
| Audit page + auto-audit on every Execute | ⚠️ | tenant ownership اضافه شده؛ hash-chain correctness/serialization هنوز باز است |
| CI: build Web + MAUI + source/artifact security scan | ✅ تعریف شد | `ci/ci.yml`؛ نتیجهٔ runner هنوز دریافت نشده است |
| **Full adversarial/E2E test with live SQL Server (Web + MAUI)** | 🔲 | نیازمند dotnet، SQL Server و device lab |
| Android/iOS direct SqlClient runtime | 🔲 | باید روی هر target build و اجرا شود؛ fallback ناامن ممنوع است |

## 2. Backlog (next phases)

| Phase | Work |
|---|---|
| 8 | `ci/ci.yml` را با دسترسی workflows به `ci/ci.yml` منتقل، روی runner سبز و artifact scan را بازبینی کنید |
| 9 | تست E2E/adversarial broker، RLS، فرم‌ها، گزارش‌ها و audit با SQL واقعی و Web/MAUI |
| 10 | مسیر مستقیم SqlClient را روی Android/iOS تأیید کنید؛ فقط در صورت عدم پشتیبانی، fallback بدون credential دائمی طراحی شود |
| 11 | بکاپ خودکار دیتابیس (یا پلن نگهداری) |
| 12 | مستندسازی کاربر نهایی (راهنمای هر ماژول + راهنمای نصب اپ) |

---
*تاریخ: ۱۴۰۵/۰۵/۲۱*
