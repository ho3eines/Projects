# ADR-004: `NULL` در `central.AuditLog.CompanyId` یعنی «عملیات سطح-central/سیستمی» — هرگز backfill نکن

- **وضعیت:** پذیرفته‌شده (2026-08-24)
- **زمینه:** `_MobileSecurity.sql` هنگام فعال‌سازی RLS برای چند شرکت، ردیف‌های بدون `CompanyId` را خطرناک می‌داند و با خطای `51091` می‌ایستد تا از تخصیص اشتباه داده جلوگیری کند. اسکریپت `_MobileBackfill.sql` ردیف‌های orphan را به اولین شرکت فعال نسبت می‌دهد.
- **مشکل:** `[central].[AuditLog]` به‌طور **طراحی‌شده** ردیف‌هایی با `CompanyId = NULL` دارد — و این ردیف‌ها **نباید** backfill شوند.

---

## ۱. چرا ردیف‌های NULL در AuditLog وجود دارند؟

`DbService.ExecuteAsync` برای **هر** اجرای اسکریپت یک ردیف ممیزی می‌نویسد (`AuditService.RecordAsync`). در زمان‌های زیر **هیچ کاربر لاگین‌شده و هیچ شرکت فعالی وجود ندارد** و `ResolveAuditCompanyId` مقدار `null` برمی‌گرداند:

- راه‌اندازی سرور (`EnsureSchema`، `SeedAsync`)
- مهاجرت‌ها و همگام‌سازی‌های امنیتی (`RoleSync`، `RolePermissionSync`، `UserRoleBackfill`، خودِ `_MobileBackfill`)
- عملیات بدون نشست کاربر

یعنی ردیف‌های NULL، **ممیزیِ خودِ عملیات‌های سیستمی/مهاجرت‌ها** هستند — نه دادهٔ کاربریِ فراموش‌شده. اسکریپت `AuditLastRowHash.sql` هم همین قرارداد را می‌فهمد: `NULL` = زنجیرهٔ هش سراسریِ سرور، و برای mobile با `fn_MobileCompanyId()` تفکیک می‌شود.

## ۲. تصمیم

> **`CompanyId IS NULL` در `[central].[AuditLog]` یعنی «عملیات سطح-central/سیستمی» (بدون مالک tenant). این مقدار عمدی است؛ هیچ‌گاه backfill نشود و به هیچ شرکتی نسبت داده نشود.**

پیامدهای فنی این تصمیم:

1. **`_MobileSecurity.sql`** — گارد `51091` برای `central.AuditLog` **معاف** است (`NOT (@Schema = N'central' AND @Table = N'AuditLog')`). بقیهٔ جداول tenant-owned همچنان محافظت می‌شوند.
2. **`_MobileBackfill.sql`** — `central.AuditLog` در فهرست backfill **وجود ندارد** (عمداً). هر جدول دیگری که ردیف orphan دارد باید backfill شود.
3. **پیش‌بینی‌کنندهٔ RLS** (`fn_MobileCompanyAccess`) — ردیفِ NULL هرگز با `s.CompanyId = @CompanyId` یک موبایل مطابقت نمی‌کند؛ یعنی **ردیف‌های سیستمی برای موبایل نامرئی‌اند** و برای هویت‌های وبِ trusted (`LEFT(USER_NAME(),5) <> N'tz_m_'`) قابل مشاهده. این دقیقاً رفتار مطلوب است.

## ۳. چرا backfill اشتباه است؟

- نسبت دادن مهاجرت/seed به یک شرکت (مثلاً اولین شرکت)، **ممیزیِ سیستم را تحریف** می‌کند و کوئری‌های ممیزیِ شرکت‌محور را با نویز عملیات سیستمی آلوده می‌کند.
- زنجیرهٔ هش ممیزی (`PrevHash`/`RowHash`) بر اساس همان قرارداد ساخته می‌شود؛ دست‌زدن به مالکیت ردیف‌های قدیمی، تداوم زنجیره را برای خواننده‌های شرکت‌محور می‌شکند.

## ۴. اگر ردیف NULL واقعاً «دادهٔ orphan» باشد چه؟

این حالت مربوط به AuditLog نیست، بلکه جداول **بیزینس** (accounting/currency/payroll/store و…) است:

1. ردیف‌های orphan را با کوئری زیر پیدا کن:
   ```sql
   SELECT s.name AS sch, t.name AS tbl, COUNT(*) AS orphans
   FROM sys.tables t
   JOIN sys.schemas s ON s.schema_id = t.schema_id
   WHERE COL_LENGTH(s.name + N'.' + t.name, N'CompanyId') IS NOT NULL
     AND (s.name IN (N'accounting',N'assets',N'bi',N'branch',N'currency',
                     N'goldshop',N'inventory',N'payroll',N'store',N'treasury')
          OR (s.name = N'central' AND t.name IN (N'AuditLog', N'Parties')))
   GROUP BY s.name, t.name
   HAVING COUNT(*) > 0;
   ```
2. اگر جدولی غیر از `central.AuditLog` برگشت داده شد، ردیف‌های آن را **به‌صورت صریح** به شرکت درست backfill کن (یا ستون `CompanyId` را اگر غایب است اضافه کن) — طبق الگوی `_MobileBackfill.sql`.
3. `central.AuditLog` را **حذف از خروجی** بگذار؛ NULLهای آن عمدی است.

## ۵. نقاط اجرایی این قرارداد

| فایل | نقش |
|------|-----|
| `docs/adr/ADR-004-auditlog-null-company.md` | این سند |
| `Tarazin.Data/Scripts/central/_MobileSecurity.sql` | معافیت گارد 51091 برای AuditLog |
| `Tarazin.Data/Scripts/central/_MobileBackfill.sql` | عدم backfill برای AuditLog |
| `Tarazin.Data/Scripts/central/AuditLastRowHash.sql` | `NULL` = زنجیرهٔ سراسری |
| `Tarazin.Data/AuditService.cs` | نوشتن ردیف ممیزی با `CompanyId` اختیاری (`null` در عملیات سیستمی) |
| `docs/Handoff_ModuleBreakdown.md` (بخش ۱۰) | ارجاع به `docs/adr/` |

## ۶. معیارهای پذیرش (تست)

- `sqlcmd -i .../_MobileRlsSeed.sql` (ساخت ردیف orphan + اطمینان از چند-شرکت) → `_MobileSecurity` باید با `51091` متوقف شود (گارد زنده است).
- `_MobileBackfill` → اجرای مجدد `_MobileSecurity` باید موفق شود و پالیسی‌های RLS ساخته شوند.
- `SELECT COUNT(*) FROM [central].[AuditLog] WHERE CompanyId IS NULL` بعد از backfill **تغییر نکند**.
- اجرای دوبارهٔ `_MobileSecurity` (idempotency) بدون خطا (شمارهٔ 3729 نداشته باشد).
