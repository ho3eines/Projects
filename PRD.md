# PRD: ترازین — مدیریت هوشمند کسب‌وکار (Blazor Hybrid Platform)

## Overview
این سند معماری مصوب «ترازین» است: **۵ پروژه با لایه‌بندی یک‌طرفه** —
`Tarazin.Share` (مدل‌ها/قراردادها) ← `Tarazin.Data` (لایهٔ داده) ← `Tarazin.Ui`
(رابط کاربری مشترک، RCL) ← **دو هاست نازک** که همان UI را میزبانی می‌کنند:
1. **هاست وب** (`Tarazin.Web`) — Blazor Server در مرورگر.
2. **هاست MAUI** (`Tarazin.Maui`) — MAUI Blazor Hybrid (دسکتاپ ویندوز/مک و موبایل).

هیچ وب‌سرویس، هیچ کلاینت WASM جدا و هیچ لایهٔ HTTP برای داده وجود ندارد. رابط
کاربری با **MudBlazor** ساخته می‌شود تا تیم درگیر طراحی دستی نشود.

## Scope
- **محصولات (7)** — حسابداری، انبار آمل، خزانه‌داری، حقوق و دستمزد، طلافروشی،
  فروشگاه اینترنتی، پلتفرم مشترک (اخبار/بلاگ/گالری/کاربران/ممیزی).
- هر محصول = یک **ماژول** (`Tarazin.Ui/Modules/{Name}/`) با صفحات و یک **اسکیمهٔ
  SQL مستقل** (`Tarazin.Data/Scripts/{schema}/`).
- **مدل‌ها فقط در `Tarazin.Share`** (namespace: `Tarazin.Models`) — قرارداد دامنه.
- داده فقط از طریق **اسکریپت‌های TSQL نامدار** (Embedded Resource در `Tarazin.Data`)
  که در همان پروسه با Dapper اجرا می‌شوند — بدون HTTP، بدون توکن، بدون لایهٔ API.

## Architecture (High Level)
| لایه | مسئولیت | سازوکار |
|------|---------|---------|
| Share | مدل‌ها و قراردادهای مشترک (POCO) | `Tarazin.Share` (بدون وابستگی) |
| Data access | اجرای اسکریپت‌های نامدار روی SQL Server | `Tarazin.Data` — DbService + Dapper (در همان پروسه) |
| UI (مشترک) | همهٔ صفحات، فرم‌ها، جداول، مودال، اعتبارسنجی | `Tarazin.Ui` (RCL) + MudBlazor |
| Host وب | میزبانی UI در مرورگر | `Tarazin.Web` — Blazor Server (SignalR) |
| Host MAUI | میزبانی UI در اپ بومی | `Tarazin.Maui` — BlazorWebView (Blazor Hybrid) |
| Scripts | منطق دامنه و گزارش‌ها (report-first) | `Tarazin.Data/Scripts/{schema}/{Name}.sql` (Embedded) |
| DB | یک دیتابیس `TarazinMaster` با اسکیمهٔ جدا برای هر محصول | SQL Server (docker compose) |
| Auth | ورود با نام کاربری/رمز از جدول `[central].[Users]` | `AuthService` + PBKDF2 |
| Audit | ثبت تمام عملیات با زنجیرهٔ هش | `AuditService` → `[central].[AuditLog]` |

## Key Rules (قوانین کلیدی)
1. **وابستگی یک‌طرفه**: `Share ← Data ← Ui ← {Web, Maui}` — هرگز برعکس.
2. **UI فقط در `Tarazin.Ui`** — صفحات جدید آنجا ساخته می‌شوند تا هر دو هاست
   خودکار بگیرندش؛ هاست‌ها فقط پوسته‌اند.
3. **مدل‌ها فقط در `Tarazin.Share`**؛ **داده فقط در `Tarazin.Data`**.
4. **دو هاست، یک هسته** — `AddTarazinUiServices()` در `Program.cs` (وب) و
   `MauiProgram.cs` (MAUI)؛ `App.razor` مشترک در هر دو رندر می‌شود.
5. **MudBlazor تنها کتابخانهٔ UI است** — Bootstrap دستی، CSS سفارشی و جدول سفارشی ممنوع.
6. **هر ماژول فقط اسکیمهٔ خودش را لمس می‌کند** (`DbService` با `{schema}`).
7. **هیچ SQL خام در صفحات نیست** — همه چیز از `Data/Scripts/{schema}/{Name}.sql`
   (Embedded Resource در `ScriptCatalog`).
8. **Report-first**: قبل از ساخت هر ماژول، گزارش‌های موردنیاز دامنه تحقیق و سپس مدل‌ها
   و اسکریپت‌ها طراحی می‌شوند.
9. چهار بخش استاندارد هر ماژول: **ورود عملیات**، **عملیات ویژه**، **گزارشات**، **امکانات**.

## What was removed (delete-list)
- همهٔ پروژه‌های قدیمی: `webapi`، ۷ کلاینت WASM، `share`، `blazordeployservice`، `tests`.
- وب‌سرویس/توکن/هندشیک/رمزنگاری AES بین کلاینت و سرور.
- بک‌بون رویدادها (Outbox) — cross-module عملیات مستقیماً و تراکنشی انجام می‌شود.
- Bootstrap سفارشی و کامپوننت‌های دست‌ساز (DataGrid و...) — همه با MudBlazor جایگزین شدند.

## MAUI Blazor Hybrid (خلاصه)
- `Tarazin.Maui/MainPage.xaml` → `BlazorWebView` با `RootComponent` = `Tarazin.App` (مشترک).
- `wwwroot/index.html` → رانتایم `_framework/blazor.webview.js` + استاتیک‌های MudBlazor و RCL.
- پیکربندی: `appsettings.json` به‌صورت Embedded خوانده می‌شود.
- **محدودیت پلتفرم**: `Microsoft.Data.SqlClient` روی ویندوز/مک پشتیبانی می‌شود؛ برای
  اندروید/iOS لایهٔ داده باید به وب‌سرویس/Provider دیگر برود (بک‌لاگ). جزییات:
  `skills/blazor/blazor-maui-hybrid/SKILL.md`.

## Acceptance Criteria
1. `dotnet build Tarazin.Web/Tarazin.Web.csproj` — بدون خطا (شامل Share/Data/Ui).
2. `dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net10.0-windows10.0.19041.0`
   روی ویندوز با `dotnet workload install maui` — بدون خطا.
3. با `docker compose up -d` + `dotnet run` همهٔ ۷ ماژول از یک آدرس باز می‌شوند.
4. در صفحات، هیچ رشتهٔ SQL و هیچ `HttpClient` برای داده وجود ندارد.
5. اسکریپت‌های هر اسکیمه از اسکیمهٔ دیگر بدون اعلام قبلی استفاده نمی‌کنند
   (`tools/cross-schema-scan.sh` پاس شود).
6. ورود با کاربر bootstrap (admin/admin در اولین اجرا) و مدیریت کاربران کار می‌کند
   (در هر دو هاست).

---
*نسخه ۲.۲ — ۲۰۲۶/۰۸/۱۲ — لایه‌بندی Share/Data/Ui + هاست وب (Blazor Server) + هاست MAUI.*
