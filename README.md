# ترازین — مدیریت هوشمند کسب‌وکار

> **وضعیت:** فعال — آخرین به‌روزرسانی ۱۴۰۵/۰۵/۲۷ (2026-08-18) — نسخه 2.3
> **معماری:** ۵ پروژهٔ تمیز با وابستگی یک‌طرفه — `Share ← Data ← Ui ← {Web, Maui}` — یک UI، دو هاست (وب + اپ بومی)

ترازین یک ERP یکپارچه برای طلافروشی و کسب‌وکارهای چندشعبه‌ای است: **حسابداری + انبار + خزانه + حقوق + طلافروشی + فروشگاه + ارز و معاملات ارزی + داشبورد BI + پلتفرم مشترک** — همه در یک دیتابیس `TarazinMaster` با اسکیمهٔ جدا، یک `Tarazin.Ui` مشترک و دو هاست نازک (Blazor Server و MAUI Blazor Hybrid).

---

## ✨ چه چیزی داخل است (۹ ماژول)

| ماژول | اسکیمه | مسیر | ۴ بخش استاندارد |
|-------|--------|------|-----------------|
| حسابداری | `accounting` | `/accounting` | اسناد/دفتر کل/تراز/بستن دوره + درخت حساب‌ها |
| انبار آمل | `inventory` | `/inventory` | رسید/حواله/کارتکس/انبارگردانی |
| خزانه‌داری | `treasury` | `/treasury` | دریافت/پرداخت/گردش نقدی/نرخ ارز/بستن روز |
| حقوق و دستمزد | `payroll` | `/payroll` | کارمندان/فیش/نهایی‌کردن دوره |
| طلافروشی | `goldshop` | `/goldshop` | فاکتور طلا/قیمت لحظه‌ای/اجناس |
| فروشگاه اینترنتی | `store` | `/store` | سبد/سفارش/محصولات/مشتریان |
| **ارز و معاملات ارزی** | `currency` | `/currency` | تابلو ارز/کیف پول/خرید-فروش/تبدیل/معاملات ترکیبی/ارزش لحظه‌ای |
| داشبورد BI | `bi` | `/bi` | ۱۴ تب اجرایی/مالی/طلا/ارز/انبار/... + هشدار + چاپ Stimulsoft |
| پلتفرم مشترک | `central` | `/central` | کاربران/نقش‌ها/اخبار/بلاگ/گالری/ممیزی + شرکت مالی/سال مالی |

*هر ماژول: `/dashboard` + `/entry` + `/special` + `/reports` + `/settings` — گزارش‌ها منبع طراحی مدل‌ها هستند (Report-first).*

**ماژول ارز (§34-§63) — درجه‌یک:**
مرکز قیمت واحد (`PriceRates` با ۷ نرخ: آنلاین/دستی/سیستم/خرید/فروش/حسابداری/میانی)، کیف پول هر ارز، خرید/فروش هم‌زمان با طلا، معاملات ترکیبی، موتور تبدیل با کارمزد، دریافت آنلاین از `tablo tala` (ایران + جهانی) با نگاشت قابل ویرایش، ارزش لحظه‌ای کل دارایی و سود/زیان ارزی — جزئیات در `docs/CURRENCY_MODULE.md`.

---

## 🏗️ معماری ۵ پروژه

```
Tarazin.Share  (مدل‌ها — بدون وابستگی)
   ↑
Tarazin.Data   (Dapper + ScriptCatalog + 270 اسکریپت نامدار Embedded + ممیزی)
   ↑
Tarazin.Ui     (RCL — همهٔ صفحات MudBlazor + App.razor + Services)
   ↑                ↑
Tarazin.Web    Tarazin.Maui
Blazor Server   MAUI Blazor Hybrid (BlazorWebView)
```

* قوانین: UI فقط در `Tarazin.Ui/Modules/...`، مدل فقط در `Tarazin.Share`، داده فقط در `Tarazin.Data/Scripts/{schema}/`، هیچ SQL خام در Razor و هیچ HTTP برای انتقال عملیات کسب‌وکار (فقط broker امنیتی MAUI و `PriceFeedService` بازار خارجی). مرز اسکیمه با `tools/cross-schema-scan.sh` چک می‌شود. — جزئیات در `docs/PROJECT.md` و `docs/adr/`.*

---

## 🚀 اجرای سریع

```bash
# 1. تنظیم اتصال SQL Server در Tarazin.Web/appsettings.json
# مقدارهای YOUR_SQL_SERVER، YOUR_SQL_USER و YOUR_SQL_PASSWORD را با
# مشخصات SQL Server نصب‌شدهٔ خودتان جایگزین کنید.

# 2. اجرای وب در محیط توسعه
dotnet run --project Tarazin.Web

# 3. انتشار برای IIS
dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish
# پوشهٔ publish را در IIS به‌عنوان سایت ASP.NET Core ثبت کنید.

# 4. اپ بومی (ویندوز — نیاز به workload)
dotnet workload install maui
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-windows10.0.19041.0
```

* مدیریت اتصال SQL در Web است؛ رشتهٔ اتصال از secret استقرار `TARAZIN_SQL_CONNECTION` می‌آید و `appsettings.json` منبع credential تولید نیست. `bootstrap password` فقط از secret استقرار می‌آید.
* Web اتصال را به MAUI از طریق کنترلر `api/{guid}` می‌دهد (تصمیم محصول: رشتهٔ اتصال کامل). `Tarazin.Maui/appsettings.json` فقط endpoint عمومی HTTPS را دارد و هیچ رشتهٔ اتصال/credential در آن نیست؛ MAUI هنگام ورود، `CustomerGuid` را به broker امن Web (`/api/mobile/connection/login`) می‌دهد، سپس اتصال SQL را از `api/{guid}` می‌گیرد و فقط در حافظه نگه می‌دارد.
* ⚠️ چون `api/{guid}` رشتهٔ اتصال کامل (با رمز) را می‌دهد، باید فقط روی HTTPS سرو شود و توصیه می‌شود در production با یک bearer secret یا IP allow-list گیت شود تا دانستن یک GUID به‌تنهایی دسترسی SQL ندهد.
* اولین initialization فقط در Web اجرا می‌شود: `_Ensure.sql` → `_Seed.sql` → نقش‌ها/دسترسی‌ها → ساخت مدیر اولیه با password تزریق‌شده. هیچ رمز پیش‌فرضی وجود ندارد.
* اسکریپت‌های نامدار Embedded هستند (`Tarazin.Scripts.{schema}.{name}.sql`)؛ MAUI پس از آماده‌سازی credential همان عملیات مستقیم `DbService` را حفظ می‌کند.

---

## 🔐 دسترسی (RBAC)

کاتالوگ در `Tarazin.Share/Permissions.cs` — ۴۶ دسترسی `module.action` + ۱۰ دسترسی `rates.*` + ۸ نقش پیش‌فرض (مدیر سیستم، حسابدار، صندوق‌دار...). جداول `[central].[Permissions/Roles/RolePermissions]` و `Users.RoleId`. `UserSession.HasPermission/CanView` گارد مرکزی در `MainLayout` + فیلتر منو. مدیریت در `/central/roles` (چک‌باکس گروه‌بندی‌شده) و `/central/users`.

---

## 💱 تابلو ارز و طلا — از کجا می‌خواند؟

جدول `currency.PriceSources` — دو منبع فعال:

* `TABLOTALA` → `https://admin.tablotala.app/api/tv/price?type=IR` (داخلی، تومان→ریال با Factor 10)
* `TABLOTALA_FR` → `https://admin.tablotala.app/api/tv/price?type=FR` (جهانی، برابری ارزها/انس)

هر منبع `Endpoint` + `MappingsJson` (`[{ItemKey, Path:"data[type=IRG18].price", Factor}]`) دارد و از `/currency/special` قابل ویرایش است. `PriceFeedService` JSON رسمی را می‌خواند، `FeedApply.sql` فقط `OnlineRate` را می‌زند، `PriceFeedScheduler` هر 300 ثانیه خودکار. تبدیل آنلاین→سیستم فقط با `Override` (§46). تابلو در `/currency/prices` (ارز/طلا/سکه/فلزات + مقایسه منابع) با دکمهٔ «بروزرسانی آنلاین ارز و طلا».

---

## 📁 ساختار

```
Tarazin.slnx
├── Tarazin.Share/      → SharedModels, CurrencyModels, Permissions, ...
├── Tarazin.Data/       → DbService, ScriptCatalog, PriceFeedService, Scripts/{9 schema}/*.sql
├── Tarazin.Ui/         → App.razor, Layout, Services, Modules/{9}/Pages, Components, Theme
├── Tarazin.Web/        → Program.cs, Pages/_Host.cshtml, appsettings.json
├── Tarazin.Maui/       → MauiProgram.cs, MainPage.xaml, Platforms, Resources
├── docs/               → PROJECT.md, CURRENCY_MODULE.md, BI_MODULE.md, HANDWRITING.md, WORKLOG_2026-08-18.md, SECURITY.md, ...
├── PRD.md / PRD_All_Projects.md
└── ci/ci.yml + tools/cross-schema-scan.sh
```

---

## 📝 آخرین تغییرات (۱۴۰۵/۰۵/۲۷)

* **شرکت مالی:** ورود مجدد کاربر دوم دیگر به «ایجاد» نمی‌رود — `AccountingContextService` حالت `NeedsSelection` + دیالوگ «انتخاب شرکت مالی» در `MainLayout` (+ تخصیص خودکار سال جاری).
* **نقش‌ها:** `RoleEditorDialog` چک‌باکس‌ها را درست نشان می‌دهد (`OnParametersSetAsync` + `HashSet` + `localItem` capture) و تغییرات نقش خود کاربر بی‌درنگ در `UserSession` اعمال می‌شود.
* **ارز:** تابلو ارز هم مثل طلا بروزرسانی آنلاین دارد — ۱۴ mapping ارزی به `TABLOTALA` اضافه شد + دکمهٔ آنلاین در `/currency/prices`.
* **مستندات:** `docs/HANDWRITING.md` (دست‌خط نویسنده)، `docs/WORKLOG_2026-08-18.md`، و همین `README` تکمیل شد.

تاریخچهٔ کامل: `docs/WORKLOG_2026-08-18.md` — دست‌خط: `docs/HANDWRITING.md` — تصمیم‌ها: `docs/adr/`.

---

## ✅ پیش‌نیاز و تست

* .NET SDK 8.0.100 + SQL Server نصب‌شده روی سرور یا شبکه + IIS برای استقرار وب
* `dotnet build Tarazin.Web/Tarazin.Web.csproj` — بدون خطا
* `tools/cross-schema-scan.sh` — بدون ارجاع بین‌اسکیمه‌ای غیرمجاز
* ورود: نام کاربری bootstrap و password تزریق‌شده از secret store → `/diag` برای عیب‌یابی امن اتصال

---

*ساخته شده با MudBlazor 9.8.0 — RTL فارسی — یک UI، دو هاست — ترازین.*
