# Platform Roadmap — 7-Module Tarazin Platform (Blazor Hybrid)

> **Date**: 2026-08-12 · **Branches from**: PRD v2.1 — `docs/PLATFORM_PRD.md`
> **Decisions**: ADR-001 (shared core + two hosts), ADR-002 (no event backbone),
> ADR-003 (contracts), ADR-004 (MAUI Blazor Hybrid)
> **Rule of thumb**: هر ماژول = گزارش‌محور؛ اول تحقیق گزارشات، بعد مدل‌ها و اسکریپت‌ها، بعد صفحات.

---

## 0. Target topology

```
Tarazin.Shared (RCL — UI + data layer, net10.0)
├── Tarazin.Web   → Blazor Server    https://localhost:65220 (مرورگر)
└── Tarazin.Maui  → MAUI Blazor Hybrid (BlazorWebView — ویندوز/مک/اندروید/iOS)
        └── SQL Server (docker) — TarazinMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

No separate ports per product, no webapi, no WASM clients, no HTTP data layer.

## 1. Implementation status (2026-08-12)

| Step | Status | Notes |
|---|---|---|
| Delete 11 old projects (webapi, 7 WASM clients, share, blazordeployservice, tests) | ✅ | `Tarazin.slnx` → ۳ پروژه |
| Create `Tarazin.Shared` (RCL) + move Modules/Models/Layout/Services/Scripts | ✅ | RootNamespace `Tarazin`؛ ۴۴ مسیر صفحه |
| Create `Tarazin.Web` (Blazor Server host) | ✅ | `AddServerSideBlazor` + MudBlazor + shared services |
| Create `Tarazin.Maui` (MAUI Blazor Hybrid host) | ✅ | BlazorWebView → `Tarazin.App`؛ Platforms/Resources کامل |
| Scripts as embedded resources (both hosts) | ✅ | `ScriptCatalog` خودکار در ctor؛ `TarazinDbInitializer` مشترک |
| Data layer (`ScriptCatalog`, `DbService`) | ✅ | named TSQL + Dapper, in-process |
| Auth (login, bootstrap admin, users page) | ✅ | PBKDF2؛ وب per-circuit / MAUI per-app |
| Audit page + auto-audit on every Execute | ✅ | hash chain in `[central].[AuditLog]` |
| CI: build وب (ubuntu) + build MAUI (windows + workload maui) | ✅ | `ci/ci.yml`؛ مسیر اسکن به‌روز |
| **Full manual test with live SQL Server (وب + MAUI)** | 🔲 | نیاز به محیط با dotnet/SQL |
| Android/iOS data layer (SqlClient محدود به ویندوز/مک) | 🔲 | بک‌لاگ — UI آماده است |

## 2. Backlog (next phases)

| Phase | Work |
|---|---|
| 8 | CI را به `.github/workflows/ci.yml` منتقل و سبز کنید (build وب + build MAUI) |
| 9 | تست دستی همهٔ فرم‌ها و گزارش‌ها با دیتای واقعی در وب و اپ MAUI (ویندوز) |
| 10 | لایهٔ داده برای اندروید/iOS در MAUI (SQLite/EF Core یا سرویس جدید) |
| 11 | بکاپ خودکار دیتابیس (یا پلن نگهداری) |
| 12 | مستندسازی کاربر نهایی (راهنمای هر ماژول + راهنمای نصب اپ) |

---
*تاریخ: ۱۴۰۵/۰۵/۲۱*
