# بررسی انطباق با PRD — گزارش حسابرسی (۲۰۲۶/۰۸/۱۲)

> **نتیجهٔ کلی**: PRD نسخهٔ ۲.۰ **از نظر ساختاری و ایستا کاملاً پیاده‌سازی شده است**؛
> موارد اجرایی (build و تست با دیتابیس واقعی) به‌دلیل نبود `dotnet`/`docker` در این
> sandbox قابل اجرا نبودند و باید در CI/محیط محلی سبز شوند.
>
> **محدودیت محیط**: SDK نصب نیست و دانلود از اینترنت در bash مسدود است
> (`SSL_ERROR_SYSCALL`)؛ بنابراین تمام بررسی‌ها ایستا انجام شد.

---

## ۱) معیارهای پذیرش PRD.md

| # | معیار | وضعیت | شواهد |
|---|-------|--------|-------|
| 1 | `dotnet build Hermes.slnx` فقط با یک پروژه | ⚠️ اجرا نشد — ساختاری پاس | `Hermes.slnx` فقط `HermesApp/HermesApp.csproj` (XML معتبر). هیچ ارجاعی به پروژه‌های حذف‌شده در کد نیست. DI کامل (همهٔ `@inject`ها ثبت شده‌اند). |
| 2 | همهٔ ۷ ماژول از یک آدرس | ⚠️ اجرا نشد — مسیرها سالم | ۴۱ مسیر یکتا؛ `NavMenu` و صفحهٔ خانه هر ۷ ماژول را دارند؛ `Program.cs` ترتیب startup کامل است. |
| 3 | بدون SQL خام و بدون HttpClient برای داده در صفحات | ✅ پاس | grep روی `HermesApp/Modules`: هیچ `HttpClient` و هیچ `SELECT/INSERT/UPDATE/DELETE` در `.razor` (موارد ظاهری فقط `MudSelect` هستند). |
| 4 | اسکن مرز اسکیمه | ✅ پاس | `tools/cross-schema-scan.sh` → ۱۰۰ اسکریپت، بدون ارجاع بین‌اسکیمه‌ای غیرمجاز. |
| 5 | ورود bootstrap (admin/admin) و مدیریت کاربران + ممیزی | ⚠️ اجرا نشد — کد کامل | `AuthService` (PBKDF2) + `UserAuthenticate`/`UserUpsert` + ساخت bootstrap فقط وقتی Users خالی است + **ممیزی خودکار** هر Execute (اصلاح در همین حسابرسی). |

## ۲) معیارهای پذیرش PRD_All_Projects.md §7

| # | معیار | وضعیت | توضیح |
|---|-------|--------|-------|
| 1 | build تک‌پروژه | ⚠️ | مثل بالا — ساختار پاس، اجرا در CI |
| 2 | ۷ ماژول با دادهٔ واقعی | ⚠️ | نیاز به SQL Server (docker compose) |
| 3 | بدون HttpClient/SQL خام | ✅ | grep پاس |
| 4 | اسکن cross-schema | ✅ | پاس |
| 5 | ورود + کاربران + ردیف ممیزی | ⚠️/✅ | کد کامل و خودکار؛ اجرا نیاز به DB |

## ۳) قوانین کلیدی PRD (Key Rules)

| قانون | وضعیت | شواهد |
|-------|--------|-------|
| فقط یک پروژه | ✅ | `Hermes.slnx` تک‌پروژه؛ پوشه‌های قدیمی حذف‌شده |
| فقط Blazor Server (بدون وب‌سرویس) | ✅ | `Program.cs`: `AddServerSideBlazor`؛ داده فقط `DbService` (Dapper in-process) |
| MudBlazor تنها UI | ✅ | csproj فقط MudBlazor/Dapper/SqlClient؛ بدون Bootstrap/کامپوننت سفارشی (grep پاس) |
| اسکریپت نامدار، بدون SQL در صفحات | ✅ | ۱۰۰ اسکریپت در `Data/Scripts/{schema}`؛ `ScriptCatalog` + `DbService` |
| مرز اسکیمه | ✅ | پارامتر schema در DbService + اسکن |
| Report-first | ✅ | اسکریپت‌های گزارش‌محور حفظ شدند |
| چهار بخش استاندارد هر ماژول | ✅ | ۶ ماژول محصول: home/dashboard/entry/reports/special/settings |
| ورود و نشست | ✅ | `AuthService` + `UserSession` (per circuit) |
| ممیزی با زنجیرهٔ هش | ✅ | `AuditService` → `[central].[AuditLog]` — حالا خودکار |

## ۴) تطبیق ستون‌های اسکریپت با مدل‌ها (ADR-003)

بازبینی شد برای همهٔ کوئری‌های استفاده‌شده در صفحات (List/Search/Dashboard/
Reportهای هر ۷ ماژول) → **همه مطابق** propertyهای مدل‌ها (Dapper mapping).
مثال: `ItemList` → `ItemRow`، `DailySales` → `DailySaleRow` (با `AS ItemTitle`)،
`DashboardSummary` هر ۶ ماژول → مدل‌های مربوطه (با aliasهای صحیح).

## ۵) باگ‌هایی که در این حسابرسی پیدا و اصلاح شد

| # | مشکل | اصلاح |
|---|-------|-------|
| 1 | `AuditService` ساخته شده بود ولی **هیچ‌جا صدا زده نمی‌شد** → ممیزی عملاً ثبت نمی‌شد (نقض AC#5) | `DbService.ExecuteAsync` حالا **خودکار** ردیف ممیزی می‌نویسد (Success/Error). برای جلوگیری از وابستگی دور/بازگشت، `AuditService` مستقل شد (اتصال اختصاصی). |
| 2 | `central/AuditSearch.sql` ستون `RowHash` را برنمی‌گرداند ولی صفحهٔ `/central/audit` آن را نمایش می‌دهد → خطای زمان اجرا | `a.RowHash` به SELECT اضافه شد |
| 3 | کامنت قدیمی `webapi/Data/Scripts` در `tools/cross-schema-scan.sh` | اصلاح به `HermesApp/Data/Scripts` |
| 4 | کلاس اضافی `h-table` روی یک MudTable | حذف شد (CSS آن هم حذف شده بود) |

## ۶) چک‌های ساختاری انجام‌شده (همه پاس)

- XML: `Hermes.slnx`، `HermesApp.csproj` معتبرند
- JSON: `appsettings.json`، `launchSettings.json` معتبرند
- ۱۰۰ اسکریپت SQL؛ هر ۷ اسکیمه `_Ensure.sql` + `_Seed.sql` دارند
- تگ‌های باز/بستهٔ تمام کامپوننت‌های Mud در همهٔ `.razor`ها متعادل‌اند
- هر فایل دقیقاً یک `@code`
- ۴۱ مسیر یکتا بدون تداخل
- همهٔ ارجاع‌های `Db.QueryAsync/Execute/Scalar` به اسکریپت‌های موجود می‌رسند
- بدون ارجاع به `webapi/IRequestService/BlazorDeployService/share/central-client` در کد
- بدون Bootstrap/کلاس‌های سفارشی قدیمی در صفحات

## ۷) ریسک‌های باقی‌مانده (باید در محیط واقعی بسته شوند)

1. **build اجرا نشد** — اولین قدم: `dotnet restore && dotnet build Hermes.slnx`
   (نسخهٔ MudBlazor 9.8.0 با net10.0 در CI تأیید شود).
2. **تست E2E با SQL واقعی** — `docker compose up -d` + ورود admin/admin + ثبت
   داده در هر ماژول + مشاهدهٔ گزارش‌ها و ردیف ممیزی.
3. اعتبارنامهٔ SQL در `appsettings.json` — در تولید به secret store منتقل شود.
4. رمز bootstrap را در اولین ورود تغییر دهید.
5. جدول‌های `Outbox` خواب‌اند (طراحی ADR-002) — پاک‌سازی اختیاری.

---
*تاریخ: ۱۴۰۵/۰۵/۲۱ — تهیه‌شده توسط حسابرسی خودکار عامل*
