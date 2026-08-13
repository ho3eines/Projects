# PRD – پلتفرم یکپارچه ترازین (نسخهٔ Blazor Hybrid — ۵ پروژه)
**Share + Data + Ui + هاست وب (Blazor Server) + هاست MAUI (Blazor Hybrid) — جایگزین کامل معماری چندپروژه‌ای + WebAPI**

> **وضعیت**: مصوب — ۲۰۲۶/۰۸/۱۲ — **جایگزین** PRD v1.0 (میکروسرویس) و v1.5 (تک‌وب‌سرویس + WASM)
> **سند مرجع معماری**: `docs/PROJECT.md` · **برنامهٔ کار**: `docs/PLATFORM_ROADMAP.md`
> **تصمیم‌ها**: `docs/adr/` (ADR-001..005)

---

## 1. چرا بازطراحی شد؟ (مشکلات معماری قبلی)

| مشکل | راه‌حل جدید |
|------|-------------|
| ۱۱ پروژه در solution → مدیریت سخت و فایل‌های تکراری زیاد | **۵ پروژه با لایه‌بندی یک‌طرفه**: Share ← Data ← Ui ← {Web, Maui} |
| ۷ کلاینت WASM + ۱ وب‌سرویس + ۱ کتابخانهٔ مشترک + ۱ پکیج | UI یک‌جا در `Tarazin.Ui`؛ هر محصول یک **ماژول** |
| نبود تفکیک مدل/داده/ارائه | **`Tarazin.Share`** (مدل‌ها) و **`Tarazin.Data`** (لایهٔ داده) پروژه‌های مستقل |
| درگیر شدن با وب‌سرویس (handshake، توکن، AES، CORS) | حذف کامل لایهٔ HTTP؛ Dapper مستقیم در همان پروسه |
| Bootstrap/HTML دستی و کامپوننت‌های سفارشی | **MudBlazor** (طراحی رایگان، RTL، جدول، مودال، فرم) |
| بک‌بون رویدادها (Outbox، processor) پیچیده | حذف؛ عملیات بین‌ماژولی مستقیم و تراکنشی |
| نبود نسخهٔ بومی (دسکتاپ/موبایل) | **MAUI Blazor Hybrid** — همان UI در BlazorWebView |

## 2. محصولات / ماژول‌ها (9)

| # | محصول | ماژول (در `Tarazin.Ui/Modules/`) | اسکیمه | مسیر |
|---|--------|-------|--------|------|
| 1 | حسابداری | `Accounting` | `accounting` | `/accounting` |
| 2 | انبار آمل | `Inventory` | `inventory` | `/inventory` |
| 3 | خزانه‌داری | `Treasury` | `treasury` | `/treasury` |
| 4 | حقوق و دستمزد | `Payroll` | `payroll` | `/payroll` |
| 5 | طلافروشی | `GoldShop` | `goldshop` | `/goldshop` |
| 6 | فروشگاه اینترنتی | `Store` | `store` | `/store` |
| 7 | ارز و معاملات ارزی (مرکز نرخ، کیف پول، تبدیل، ارزش لحظه‌ای) | `Currency` | `currency` | `/currency` |
| 8 | داشبورد و Business Intelligence (مرکز فرماندهی، هشدار، چاپ Stimulsoft) | `Bi` | `bi` | `/bi` |
| 9 | پلتفرم مشترک (وبسایت، کاربران، ممیزی) | `Central` | `central` | `/central` |

هر ماژول استاندارداً ۶ صفحه دارد:
`/home` (فهرست روزانه)، `/dashboard`، `/entry` (ورود عملیات)، `/reports`،
`/special` (عملیات ویژه)، `/settings` (امکانات و جداول پایه).
همین صفحات بدون تغییر در **وب** و **اپ MAUI** رندر می‌شوند.

## 3. معماری سطح بالا

```
┌────────────────────────────────────────────────────────────────────┐
│ Tarazin.Share (مدل‌ها/قراردادها — بدون وابستگی)                      │
│   Models/*.cs  (namespace: Tarazin.Models)                          │
└──────────────────────────┬─────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│ Tarazin.Data (لایهٔ داده)                                           │
│   DbService (Dapper) · ScriptCatalog (اسکریپت‌های Embedded)          │
│   AuditService · PasswordHasher · ICurrentUser · TarazinDbInitializer│
│   Scripts/{schema}/*.sql  (100 اسکریپت نامدار)                      │
└──────────────────────────┬─────────────────────────────────────────┘
                           │
┌──────────────────────────▼─────────────────────────────────────────┐
│ Tarazin.Ui (RCL — رابط کاربری مشترک)                                │
│   Modules/*  Layout/*  Services/{UserSession, AuthService}          │
│   App.razor (Router + MudBlazor providers + init)                   │
└───────────────┬───────────────────────────────┬────────────────────┘
                │                               │
    ┌───────────▼──────────┐       ┌────────────▼───────────┐
    │ Tarazin.Web          │       │ Tarazin.Maui           │
    │ Blazor Server (web)  │       │ MAUI Blazor Hybrid     │
    │ Program.cs + _Host   │       │ MauiProgram + MainPage │
    │ SignalR + prerender  │       │ BlazorWebView (بومی)    │
    └───────────┬──────────┘       └────────────┬───────────┘
                │                               │
                └──────────┬────────────────────┘
                           │ DbService + Dapper (در همان پروسه)
                   SQL Server — TarazinMaster
            [central] [accounting] [inventory] [treasury]
            [payroll] [goldshop] [store] [currency] [bi]   (اسکیمهٔ جدا)
```

- **وابستگی یک‌طرفه**: `Share ← Data ← Ui ← {Web, Maui}`.
- **بدون HTTP برای داده**: `DbService.QueryAsync<T>(schema, scriptName, params)`.
- **قراردادهای دامنه**: مدل‌های مشترک در `Tarazin.Share/Models/SharedModels.cs`
  (Party, ChartOfAccount, CurrencyRate, TaxRule, InventoryMovement, PayrollRun,
  GoldPrice, Order) — ستون‌های اسکریپت‌ها باید با همین نام‌ها هم‌نام باشند (ADR-003).

## 4. داده و یکپارچگی

- یک دیتابیس `TarazinMaster`، یک اسکیمه برای هر ماژول؛ `_Ensure.sql` و `_Seed.sql`
  در استارت‌آپ اجرا می‌شوند (idempotent).
- عملیات بین‌ماژولی (مثلاً فاکتور فروش → انبار/حسابداری) مستقیم در سمت سرور و در
  همان تراکنش انجام می‌شود؛ **بک‌بون رویدادها حذف شد** (ADR-002).
- **گزارش‌محوری**: قبل از هر ماژول، گزارش‌های دامنه مشخص، سپس مدل‌ها و اسکریپت‌ها.

## 5. امنیت و نشست

- ورود با نام کاربری/رمز در همان پروسه (`AuthService` + PBKDF2).
- وب: نشست به ازای هر circuit Blazor در حافظه (`UserSession`).
- MAUI: نشست در سطح اپ (scoped ≈ singleton — تک‌کاربره).
- هیچ رازی به مرورگر/WebView نمی‌رود؛ **مشکل WASM «کلیدها داخل کلاینت» به‌کلی از بین رفت**.
- همهٔ عملیات تغییردهنده در `[central].[AuditLog]` با زنجیرهٔ هش ثبت می‌شود (ADR-002).
- `docs/SECURITY.md` تهدیدها و چک‌لیست تولید را شرح می‌دهد.

## 6. استقرار و CI

- `docker compose up -d` → فقط SQL Server.
- **وب**: `dotnet run --project Tarazin.Web` (یا publish).
- **MAUI**: `dotnet workload install maui` سپس
  `dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-windows10.0.19041.0`
  (روی ویندوز؛ سایر TFMها در VS/دستگاه‌های مربوطه).
- CI (`ci/ci.yml`): build وب (ubuntu) + build MAUI (windows + workload) +
  `tools/cross-schema-scan.sh`.

## 7. معیارهای پذیرش

1. `dotnet build Tarazin.Web/Tarazin.Web.csproj` پاس (شامل `Tarazin.Ui`).
2. build MAUI (ویندوز) با workload پاس.
3. همهٔ ۹ ماژول از یک آدرس در دسترس‌اند و دادهٔ واقعی نشان می‌دهند (وب + MAUI).
4. جستجوی کد: هیچ `HttpClient` برای داده و هیچ SQL خام در `.razor` وجود ندارد.
5. `tools/cross-schema-scan.sh` پاس (بدون ارجاع بین‌اسکیمه‌ای غیرمجاز).
6. ورود bootstrap و مدیریت کاربران کار می‌کند؛ ممیزی ردیف ثبت می‌کند.

---
*نسخه ۲.۱ — ۱۴۰۵/۰۵/۲۱ — تیم معماری ترازین*
