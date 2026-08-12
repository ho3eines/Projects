# PRD – پلتفرم یکپارچه ترازین (نسخهٔ تک‌پروژه‌ای)
**Single Blazor Server + MudBlazor — جایگزین کامل معماری چندپروژه‌ای + WebAPI**

> **وضعیت**: مصوب — ۲۰۲۶/۰۸/۱۲ — **جایگزین** PRD v1.0 (میکروسرویس) و v1.5 (تک‌وب‌سرویس + WASM)
> **سند مرجع معماری**: `docs/PROJECT.md` · **برنامهٔ کار**: `docs/PLATFORM_ROADMAP.md`
> **تصمیم‌ها**: `docs/adr/` (ADR-001 تک‌پروژه، ADR-002 بدون رویداد/outbox، ADR-003 قراردادها)

---

## 1. چرا بازطراحی شد؟ (مشکلات معماری قبلی)

| مشکل | راه‌حل جدید |
|------|-------------|
| ۱۱ پروژه در solution → مدیریت سخت و فایل‌های تکراری زیاد | **یک پروژهٔ Blazor Server** به نام `TarazinApp` |
| ۷ کلاینت WASM + ۱ وب‌سرویس + ۱ کتابخانهٔ مشترک + ۱ پکیج | همه داخل یک پروژه؛ هر محصول یک **ماژول** |
| درگیر شدن با وب‌سرویس (handshake، توکن، AES، CORS) | حذف کامل لایهٔ HTTP؛ Dapper مستقیم در همان پروسه |
| Bootstrap/HTML دستی و کامپوننت‌های سفارشی | **MudBlazor** (طراحی رایگان، RTL، جدول، مودال، فرم) |
| بک‌بون رویدادها (Outbox، processor) پیچیده | حذف؛ عملیات بین‌ماژولی مستقیم و تراکنشی |

## 2. محصولات / ماژول‌ها (7)

| # | محصول | ماژول | اسکیمه | مسیر |
|---|--------|-------|--------|------|
| 1 | حسابداری | `Modules/Accounting` | `accounting` | `/accounting` |
| 2 | انبار آمل | `Modules/Inventory` | `inventory` | `/inventory` |
| 3 | خزانه‌داری | `Modules/Treasury` | `treasury` | `/treasury` |
| 4 | حقوق و دستمزد | `Modules/Payroll` | `payroll` | `/payroll` |
| 5 | طلافروشی | `Modules/GoldShop` | `goldshop` | `/goldshop` |
| 6 | فروشگاه اینترنتی | `Modules/Store` | `store` | `/store` |
| 7 | پلتفرم مشترک (وبسایت، کاربران، ممیزی) | `Modules/Central` | `central` | `/central` |

هر ماژول استاندارداً ۶ صفحه دارد:
`/home` (فهرست روزانه)، `/dashboard`، `/entry` (ورود عملیات)، `/reports`،
`/special` (عملیات ویژه)، `/settings` (امکانات و جداول پایه).

## 3. معماری سطح بالا

```
┌────────────────────────────────────────────────────────────┐
│  TarazinApp (یک پروژهٔ Blazor Server — net10.0)             │
│  ┌───────────┐  ┌───────────────┐  ┌────────────────────┐  │
│  │ MudBlazor │  │ Modules/{7}   │  │ Services           │  │
│  │ UI kit    │  │ Pages + Models│  │ DbService, Auth…   │  │
│  └───────────┘  └──────┬────────┘  └─────────┬──────────┘  │
│                        │                    │ Dapper       │
│               Data/Scripts/{schema}/*.sql ──┘              │
└───────────────────────────────┬────────────────────────────┘
                                │ (یک ConnectionString)
                        SQL Server — TarazinMaster
                [central] [accounting] [inventory] [treasury]
                [payroll] [goldshop] [store]   (اسکیمهٔ جدا)
```

- **بدون HTTP برای داده**: `DbService.QueryAsync<T>(schema, scriptName, params)`.
- **اسکیمه = مرز ماژول**: ماژول حسابداری فقط اسکریپت‌های `accounting/` را صدا می‌زند.
- **قراردادهای دامنه**: مدل‌های مشترک در `TarazinApp/Models/SharedModels.cs`
  (Party, ChartOfAccount, CurrencyRate, TaxRule, InventoryMovement, PayrollRun,
  GoldPrice, Order) — ستون‌های اسکریپت‌ها باید با همین نام‌ها هم‌نام باشند (ADR-003).

## 4. داده و یکپارچگی

- یک دیتابیس `TarazinMaster`، یک اسکیمه برای هر ماژول؛ `_Ensure.sql` و `_Seed.sql`
  در استارت‌آپ اجرا می‌شوند (idempotent).
- عملیات بین‌ماژولی (مثلاً فاکتور فروش → انبار/حسابداری) مستقیم در سمت سرور و در
  همان تراکنش انجام می‌شود؛ **بک‌بون رویدادها حذف شد** (ADR-002).
- **گزارش‌محوری**: قبل از هر ماژول، گزارش‌های دامنه مشخص، سپس مدل‌ها و اسکریپت‌ها.

## 5. امنیت و نشست

- ورود با نام کاربری/رمز در همان پروسه (`AuthService` + PBKDF2)؛
  نشست به ازای هر circuit Blazor در حافظه (`UserSession`).
- هیچ رازی به مرورگر نمی‌رود؛ **مشکل WASM «کلیدها داخل کلاینت» به‌کلی از بین رفت**.
- همهٔ عملیات تغییردهنده در `[central].[AuditLog]` با زنجیرهٔ هش ثبت می‌شود (ADR-002).
- `docs/SECURITY.md` تهدیدها و چک‌لیست تولید را شرح می‌دهد.

## 6. استقرار و CI

- `docker compose up -d` → فقط SQL Server؛ سپس `dotnet run --project TarazinApp`.
- CI (`ci/ci.yml`): restore + build تک‌پروژه + `tools/cross-schema-scan.sh`.

## 7. معیارهای پذیرش

1. `dotnet build Tarazin.slnx` با یک پروژه پاس می‌شود.
2. همهٔ ۷ ماژول از یک آدرس در دسترس‌اند و داده‌ی واقعی نشان می‌دهند.
3. جستجوی کد: هیچ `HttpClient` برای داده و هیچ SQL خام در `.razor` وجود ندارد.
4. `tools/cross-schema-scan.sh` پاس (بدون ارجاع بین‌اسکیمه‌ای غیرمجاز).
5. ورود bootstrap و مدیریت کاربران کار می‌کند؛ ممیزی ردیف ثبت می‌کند.

---
*نسخه ۲.۰ — ۱۴۰۵/۰۵/۲۱ — تیم معماری ترازین*
