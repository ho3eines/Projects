# PRD: ترازین — مدیریت هوشمند کسب‌وکار (Single Blazor Server Platform)

## Overview
این سند معماری مصوب «ترازین» است: **یک پروژهٔ Blazor Server** که همهٔ محصولات را
به‌صورت ماژول در خودش دارد. هیچ وب‌سرویس، هیچ کلاینت WASM جدا، هیچ کتابخانهٔ
اشتراکی جدا و هیچ پکیج NuGet جدا وجود ندارد. رابط کاربری با **MudBlazor**
ساخته می‌شود تا تیم درگیر طراحی دستی نشود.

## Scope
- **محصولات (7)** — حسابداری، انبار آمل، خزانه‌داری، حقوق و دستمزد، طلافروشی،
  فروشگاه اینترنتی، پلتفرم مشترک (اخبار/بلاگ/گالری/کاربران/ممیزی).
- هر محصول = یک **ماژول** (`Modules/{Name}/`) با صفحات، مدل‌ها و یک **اسکیمهٔ SQL
  مستقل** (`Data/Scripts/{schema}/`).
- داده فقط از طریق **اسکریپت‌های TSQL نامدار** که در همان پروسهٔ Blazor Server با
  Dapper اجرا می‌شوند — بدون HTTP، بدون توکن، بدون لایهٔ API.

## Architecture (High Level)
| لایه | مسئولیت | سازوکار |
|------|---------|---------|
| UI | همهٔ صفحات، فرم‌ها، جداول، مودال، اعتبارسنجی | Blazor Server + MudBlazor |
| Data access | اجرای اسکریپت‌های نامدار روی SQL Server | `DbService` + Dapper (در همان پروسه) |
| Scripts | منطق دامنه و گزارش‌ها (report-first) | `TarazinApp/Data/Scripts/{schema}/{Name}.sql` |
| DB | یک دیتابیس `TarazinMaster` با اسکیمهٔ جدا برای هر محصول | SQL Server (docker compose) |
| Auth | ورود با نام کاربری/رمز از جدول `[central].[Users]` | `AuthService` + PBKDF2، نشست هر circuit |
| Audit | ثبت تمام عملیات با زنجیرهٔ هش | `AuditService` → `[central].[AuditLog]` |

## Key Rules (قوانین کلیدی)
1. **فقط یک پروژه**: `TarazinApp/` — همهٔ چیز داخل همین پوشه.
2. **فقط Blazor Server** — بدون WebAPI، بدون WASM، بدون کال‌کردن `HttpClient` برای داده.
3. **MudBlazor تنها کتابخانهٔ UI است** — Bootstrap دستی، CSS سفارشی و جدول سفارشی ممنوع.
4. **هر ماژول فقط اسکیمهٔ خودش را لمس می‌کند** (`DbService` با `{schema}`).
5. **هیچ SQL خام در صفحات نیست** — همه چیز از `Data/Scripts/{schema}/{Name}.sql`.
6. **Report-first**: قبل از ساخت هر ماژول، گزارش‌های موردنیاز دامنه تحقیق و سپس مدل‌ها
   و اسکریپت‌ها طراحی می‌شوند.
7. چهار بخش استاندارد هر ماژول: **ورود عملیات**، **عملیات ویژه**، **گزارشات**، **امکانات**.

## What was removed (delete-list)
- همهٔ پروژه‌های قدیمی: `webapi`، ۷ کلاینت WASM، `share`، `blazordeployservice`، `tests`.
- وب‌سرویس/توکن/هندشیک/رمزنگاری AES بین کلاینت و سرور.
- بک‌بون رویدادها (Outbox) — cross-module عملیات مستقیماً و تراکنشی انجام می‌شود.
- Bootstrap سفارشی و کامپوننت‌های دست‌ساز (DataGrid و...) — همه با MudBlazor جایگزین شدند.

## Acceptance Criteria
1. `dotnet build Tarazin.slnx` — بدون خطا، فقط با یک پروژه.
2. با `docker compose up -d` + `dotnet run` همهٔ ۷ ماژول از یک آدرس باز می‌شوند.
3. در صفحات، هیچ رشتهٔ SQL و هیچ `HttpClient` برای داده وجود ندارد.
4. اسکریپت‌های هر اسکیمه از اسکیمهٔ دیگر بدون اعلام قبلی استفاده نمی‌کنند
   (`tools/cross-schema-scan.sh` پاس شود).
5. ورود با کاربر bootstrap (admin/admin در اولین اجرا) و مدیریت کاربران کار می‌کند.

---
*نسخه ۲.۰ — ۲۰۲۶/۰۸/۱۲ — بازطراحی کامل از multi-project + webapi به یک پروژهٔ Blazor Server + MudBlazor.*
