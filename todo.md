# TODO — ترازین (مدیریت هوشمند کسب‌وکار) — Blazor Hybrid

> **وضعیت کلی (۱۴۰۵/۰۵/۲۱):** پیاده‌سازی کد **کامل است** (هستهٔ مشترک + هاست وب +
> هاست MAUI + صفحات گزارشات). آنچه باقی مانده، **تأیید اجرایی** است: build و تست
> دستی با دیتابیس واقعی (به‌دلیل نبود dotnet/SQL در sandbox ممکن نشد) و فعال‌سازی
> CI در GitHub Actions. مطابق Legend، وضعیت «۴» یعنی Deploy شده — هنوز چیزی Deploy
> نشده، بنابراین فازهای کد «۳» (تکمیل) هستند نه «۴».

| فاز | وضعیت (0 تا 4) | شرح کار | مسئول |
|-----|-----------------|---------|--------|
| 0 | 3 | حذف پروژه‌های قدیمی (webapi، WASMها، share، blazordeployservice، tests) و ساخت پنج‌تایی `Share / Data / Ui / Web / Maui` | @arch |
| 0 | 3 | **`Tarazin.Share`** (مدل‌ها/قراردادها) + **`Tarazin.Data`** (لایهٔ داده) به‌عنوان پروژه‌های مستقل با وابستگی یک‌طرفه | @arch |
| 0 | 3 | هستهٔ UI مشترک (`Tarazin.Ui`): MudBlazor + چیدمان (MudLayout/MudDrawer/NavMenu) + شعار «مدیریت هوشمند کسب‌وکار» | @front |
| 0 | 3 | لایهٔ داده (در `Tarazin.Data`): ScriptCatalog (Embedded) + DbService (Dapper + اسکریپت نامدار) + ممیزی خودکار + ICurrentUser | @backend |
| 0 | 3 | هاست وب (`Tarazin.Web`): Blazor Server + `AddTarazinUiServices` + init | @backend |
| 0 | 3 | **هاست MAUI (`Tarazin.Maui`)**: BlazorWebView → `Tarazin.App` + Platforms/Resources کامل | @maui |
| 0 | 3 | ماژول پلتفرم مشترک: ورود، کاربران، اخبار/بلاگ/گالری، ممیزی | @backend |
| 1 | 3 | ماژول حسابداری: اسناد روز، ثبت سند، دفتر روزنامه/کل، تراز، بستن دوره، حساب‌ها | @dev_a |
| 2 | 3 | ماژول انبار آمل: رسید/حواله، کارتکس، موجودی، انبارگردانی، کالاها | @dev_b |
| 3 | 3 | ماژول خزانه‌داری: دریافت/پرداخت، گردش نقدی، نرخ ارز، بستن روز | @dev_c |
| 4 | 3 | ماژول حقوق و دستمزد: کارمندان، فیش، نهایی‌کردن دوره، گزارشات | @dev_d |
| 5 | 3 | ماژول طلافروشی: فاکتور فروش، قیمت طلا، اجناس، گزارشات | @dev_e |
| 6 | 3 | ماژول فروشگاه: سبد خرید، سفارش، محصولات، مشتریان | @dev_f |
| 7 | 2 | بازبینی ایستا انجام شد (بدون SQL/HttpClient در صفحات، مرز اسکیمه، مسیرها، تطبیق مدل↔اسکریپت)؛ **تست دستی با محیط واقعی (وب + MAUI) مانده** | @qa_lead |
| 8 | 1 | `ci/ci.yml` (build وب + build MAUI با workload) نوشته شده؛ **فعال‌سازی در `.github/workflows/` و سبز شدن مانده** | @devops |
| 9 | 3 | مستندسازی نهایی (PRD، PLATFORM_PRD، PROJECT، ADRها، skills، .agents) **کامل**؛ انتقال به تولید مانده | @arch |

## کارهای باز (Backlog)

| # | کار | پیش‌نیاز |
|---|-----|----------|
| B1 | `dotnet build Tarazin.Web/Tarazin.Web.csproj` — تأیید build پنج‌پروژه (MudBlazor 9.8.0 روی net10.0) | محیط با SDK |
| B2 | `dotnet workload install maui` + build MAUI (ویندوز) | محیط با SDK/ویندوز |
| B3 | `docker compose up -d` + تست E2E در وب و MAUI (admin/admin، ثبت داده، گزارش، ممیزی) | SQL Server |
| B4 | لایهٔ داده برای اندروید/iOS در MAUI (SQLite/EF Core یا سرویس جدید) | تصمیم معماری |
| B5 | انتقال `ci/ci.yml` به `.github/workflows/ci.yml` و سبز شدن | دسترسی workflows |
| B6 | تغییر رمز bootstrap و انتقال اعتبارنامهٔ SQL به secret store | تولید |
| B7 | پاک‌سازی جدول‌های Outbox خواب (ADR-002) | اختیاری |

## Status Legend
- 0 = برنامه‌ریزی نشده
- 1 = در حال پیاده‌سازی
- 2 = دارای مشکل / در حال رفع
- 3 = تکمیل شده
- 4 = کامل شده و Deploy شده
