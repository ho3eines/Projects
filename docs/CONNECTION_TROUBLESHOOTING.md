# عیب‌یابی اتصال به SQL Server

> پاسخ کوتاه به سؤال «اصلاً کانکشن‌استرینگ خوانده می‌شود؟»
> **بله، خوانده می‌شود.** مسیر خواندن سالم بود؛ خطایی که می‌دیدید از جای دیگری
> می‌آمد: **دیتابیس `TarazinMaster` هرگز ساخته نمی‌شد.** جزئیات پایین‌تر.

---

## ۱. مسیر خواندن رشتهٔ اتصال (تأییدشده)

| هاست | منبع | وضعیت |
|---|---|---|
| `Tarazin.Web` | `appsettings.json` → `ConnectionStrings:DefaultConnection` | ✅ خوانده می‌شود (فایل با SDK وب به خروجی کپی می‌شود؛ حالا صریحاً هم در csproj تضمین شده) |
| `Tarazin.Maui` | `appsettings.json` به‌صورت EmbeddedResource با `LogicalName="Tarazin.Maui.appsettings.json"` | ✅ نام منطقی با نامی که `MauiProgram` می‌خواند یکی است |

مقدار هر دو یکسان است:

```
Server=localhost,1433;Database=TarazinMaster;User Id=sa;Password=Tarazin!Master2026;TrustServerCertificate=True;Encrypt=False
```

ترتیب اولویت منابع (پس از این تغییرات):

1. متغیر محیطی `TARAZIN_SQL_CONNECTION` — برای تولید/Docker/secret store
2. `ConnectionStrings:DefaultConnection` در `appsettings.json`
3. (فقط وب) `ConnectionStrings__DefaultConnection` که ASP.NET خودکار می‌خواند

---

## ۲. علت واقعی خطا

اسکریپت‌های `Tarazin.Data/Scripts/{schema}/_Ensure.sql` فقط **schema و جدول**
می‌سازند و فرض می‌کنند دیتابیس از قبل هست:

```sql
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = N'central')
    EXEC(N'CREATE SCHEMA [central]');
```

هیچ‌جای پروژه `CREATE DATABASE` وجود نداشت. پس روی یک SQL Server تازه
(مثلاً `docker compose up -d` روی volume خالی) اولین اتصال با
`Database=TarazinMaster` شکست می‌خورد:

```
Msg 4060 — Cannot open database "TarazinMaster" requested by the login.
```

و چون این استثنا از عمق Dapper بالا می‌آمد، پیامش شبیه «خطای کانکشن‌استرینگ»
به‌نظر می‌رسید — در حالی‌که رشتهٔ اتصال کاملاً درست خوانده شده بود.

---

## ۳. چه چیزی اصلاح شد

| # | تغییر | فایل |
|---|---|---|
| ۱ | ساخت خودکار دیتابیس در اولین اجرا (`EnsureDatabaseAsync` با اتصال به `master`) | `Tarazin.Data/DbService.cs` |
| ۲ | نقطهٔ واحد خواندن/اعتبارسنجی رشتهٔ اتصال + پشتیبانی از `TARAZIN_SQL_CONNECTION` | `Tarazin.Data/TarazinConnection.cs` (جدید) |
| ۳ | ترجمهٔ خطاهای SQL به پیام فارسی (`18456`, `4060`, `53`, …) | `DbService.Describe` |
| ۴ | تست اتصال بدون پرتاب استثنا | `DbService.TestConnectionAsync` |
| ۵ | صفحهٔ عیب‌یابی `/diag` — منبع رشته، مقدار ماسک‌شده، تست زنده، تعداد اسکریپت‌ها | `Tarazin.Ui/Modules/Home/Diagnostics.razor` (جدید) |
| ۶ | وب دیگر موقع نبودن SQL کرش نمی‌کند؛ لاگ می‌کند و `/diag` را نشان می‌دهد | `Tarazin.Web/Program.cs` |
| ۷ | MAUI اگر `appsettings.json` embed نشده باشد، فوراً با پیام روشن شکست می‌خورد | `Tarazin.Maui/MauiProgram.cs` |
| ۸ | تضمین کپی `appsettings.json` به خروجی | `Tarazin.Web/Tarazin.Web.csproj` |
| ۹ | اسکریپت تست اتصال بدون اجرای برنامه | `tools/test-connection.sh` |

نکتهٔ امنیتی: رمز عبور در هیچ لاگ یا صفحه‌ای چاپ نمی‌شود —
`TarazinConnection.Mask` همیشه آن را به `********` تبدیل می‌کند.

---

## ۴. روش بررسی (به‌ترتیب)

```bash
# ۱) SQL بالا باشد
docker compose up -d
docker compose ps

# ۲) تست اتصال بدون اجرای برنامه
bash tools/test-connection.sh

# ۳) اجرای وب
dotnet run --project Tarazin.Web/Tarazin.Web.csproj
```

در لاگ راه‌اندازی حالا دقیقاً این خط را می‌بینید:

```
رشتهٔ اتصال — منبع: پیکربندی ConnectionStrings:DefaultConnection | مقدار: Data Source=localhost,1433;Initial Catalog=TarazinMaster;User ID=sa;Password=********;...
راه‌اندازی دیتابیس با موفقیت انجام شد.
```

سپس در مرورگر: **`/diag`**

---

## ۵. جدول خطاهای رایج

| پیام / کد | معنی | راه‌حل |
|---|---|---|
| «رشتهٔ اتصال پیدا نشد» | نه env هست نه appsettings خوانده شده | فایل کنار خروجی نیست یا در MAUI embed نشده |
| SQL 4060 | دیتابیس وجود ندارد | حالا خودکار ساخته می‌شود؛ اگر کاربر مجوز `CREATE DATABASE` ندارد، دستی بسازید |
| SQL 18456 | رمز/کاربر اشتباه | `MSSQL_SA_PASSWORD` را با `appsettings.json` یکی کنید |
| SQL 53 / -1 / 258 | سرور در دسترس نیست | کانتینر بالا نیست یا پورت 1433 بسته است |
| «قابل تجزیه نیست» | رمز شامل `;` یا `=` است | داخل `{}` بگذارید: `Password={pa;ss}` |
| SSL/گواهی | TLS معتبر نیست | `TrustServerCertificate=True;Encrypt=False` (فقط توسعه) |

---

## ۶. تولید: بیرون بردن رمز از سورس

```bash
export TARAZIN_SQL_CONNECTION='Server=sql-prod,1433;Database=TarazinMaster;User Id=tarazin_app;Password={...};Encrypt=True'
```

این مقدار بر `appsettings.json` اولویت دارد و در هر دو هاست (وب و MAUI) کار می‌کند.
