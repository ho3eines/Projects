# Platform Roadmap — 7-Module Hermes Platform (Single Blazor Server)

> **Date**: 2026-08-12 · **Branches from**: PRD v2.0 — `docs/PLATFORM_PRD.md`
> **Decisions**: ADR-001 (single project), ADR-002 (no event backbone), ADR-003 (contracts)
> **Rule of thumb**: هر ماژول = گزارش‌محور؛ اول تحقیق گزارشات، بعد مدل‌ها و اسکریپت‌ها، بعد صفحات.

---

## 0. Target topology (single process)

```
dotnet run --project HermesApp   (Blazor Server — https://localhost:65220)
        │
        └── SQL Server (docker) — HermesMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]
```

No separate ports per product, no webapi, no WASM clients.

## 1. Refactor status (2026-08-12)

| Step | Status | Notes |
|---|---|---|
| Delete 11 old projects (webapi, 7 WASM clients, share, blazordeployservice, tests) | ✅ | `Hermes.slnx` → فقط `HermesApp` |
| Create `HermesApp` (Blazor Server, net10.0) | ✅ | classic `AddServerSideBlazor` + MudBlazor |
| MudBlazor shell (MainLayout, NavMenu, RTL, providers) | ✅ | `MudThemeProvider/Dialog/Snackbar` |
| Data layer (`ScriptCatalog`, `DbService`) | ✅ | named TSQL + Dapper, in-process |
| Move 99 SQL scripts into `HermesApp/Data/Scripts/{schema}` | ✅ | `_Ensure`/`_Seed` run at startup |
| Auth (login, bootstrap admin, users page) | ✅ | PBKDF2, per-circuit `UserSession` |
| Modules 1–7 pages (home/dashboard/entry/reports/special/settings) | ✅ | همه با MudBlazor |
| Audit page + `AuditService` | ✅ | hash chain in `[central].[AuditLog]` |
| docker-compose (SQL Server only) + CI (build + scan) | ✅ | `tools/cross-schema-scan.sh` path updated |
| **Full manual test with live SQL Server** | 🔲 | نیاز به محیط با dotnet/SQL (این sandbox بسته بود) |
| Production hardening (backup, metrics, HTTPS config) | 🔲 | بک‌لاگ |

## 2. Backlog (next phases)

| Phase | Work |
|---|---|
| 8 | CI را به `.github/workflows/ci.yml` منتقل و یک بار سبز کنید |
| 9 | تست دستی همهٔ فرم‌ها و گزارش‌ها با دیتای واقعی |
| 10 | بکاپ خودکار دیتابیس (یا پلن نگهداری) |
| 11 | مستندسازی کاربر نهایی (راهنمای هر ماژول) |

---
*تاریخ: ۱۴۰۵/۰۵/۲۱*
