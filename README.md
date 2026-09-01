# ترازین — مدیریت هوشمند کسب‌وکار

> **وضعیت:** فعال — آخرین به‌روزرسانی ۱۴۰۵/۰۵/۲۷ (2026-08-18) — نسخه 2.3
> **معماری:** ۵ پروژهٔ تمیز با وابستگی یک‌طرفه — `Share ← Data ← Ui ← {Web, Maui}` — یک UI، دو هاست (وب + اپ بومی)
>
> 🧑‍💻 **توسعه‌دهنده؟ قبل از هر تغییر/دریافت پارامتر، اول بخش «اسکیل‌های راهنما» پایین همین README را بخوان** — چهار اسکیل رسمی پروژه (توسعه، UI/UX، گزارش‌سازی، تست بصری ویندوز) منبع واحد الگوها و قوانین هستند و هر تغییری باید مطابق آن‌ها باشد:
>
> | اسکیل (SKILL.md) | موضوع | قبل از چه کاری بخوان |
> |---|---|---|
> | **development** | معماری، لایهٔ داده، RBAC، MudBlazor 9.8.0، الگوهای مودال/نوبار | هر تغییر کد |
> | **ui-ux** | کاتالوگ کامپوننت‌های مشترک + اسکلت صفحه (جدول/فرم/داشبورد) | ساخت هر `.razor` |
> | **reporting** | گزارش‌سازی، دیالوگ چاپ، خروجی PDF (QuestPDF) | ساخت گزارش/چاپ/PDF |
> | **windows-computer-control** | تست بصری/UI-Automation ویندوز و دستگاه‌ها | تست چشمی/دستگاه |
>
> [![CI – main](https://github.com/ho3eines/Projects/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/ho3eines/Projects/actions/workflows/ci.yml)
> [![CI – develop](https://github.com/ho3eines/Projects/actions/workflows/ci.yml/badge.svg?branch=develop)](https://github.com/ho3eines/Projects/actions/workflows/ci.yml)

ترازین یک ERP یکپارچه برای طلافروشی و کسب‌وکارهای چندشعبه‌ای است: **حسابداری + انبار + خزانه + حقوق + طلافروشی + فروشگاه + ارز و معاملات ارزی + داشبورد BI + پلتفرم مشترک** — همه در یک دیتابیس `TarazinMaster` با اسکیمهٔ جدا، یک `Tarazin.Ui` مشترک و دو هاست نازک (Blazor Server و MAUI Blazor Hybrid).

---

## ✨ نقشهٔ سریع — ۹ ماژول (صفحه + اسکیمهٔ SQL)

> روی نام ماژول کلیک کن → صفحهٔ اصلی ماژول. روی اسکیمه کلیک کن → پوشهٔ اسکریپت‌های SQL همان ماژول (`Tarazin.Data/Scripts/{schema}/`). هر ماژول: `/dashboard` + `/entry` + `/special` + `/reports` + `/settings` — گزارش‌ها منبع طراحی مدل‌ها هستند (Report-first).

| ماژول | اسکیمهٔ SQL | صفحه | ۴ بخش استاندارد |
|-------|-----------|------|-----------------|
| [حسابداری](/accounting) | [`accounting/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/accounting) | [`/accounting`](/accounting) | اسناد/دفتر کل/تراز/بستن دوره + درخت حساب‌ها |
| [انبار آمل](/inventory) | [`inventory/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/inventory) | [`/inventory`](/inventory) | رسید/حواله/کارتکس/انبارگردانی |
| [خزانه‌داری](/treasury) | [`treasury/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/treasury) | [`/treasury`](/treasury) | دریافت/پرداخت/گردش نقدی/نرخ ارز/بستن روز |
| [حقوق و دستمزد](/payroll) | [`payroll/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/payroll) | [`/payroll`](/payroll) | کارمندان/فیش/نهایی‌کردن دوره |
| [طلافروشی](/goldshop) | [`goldshop/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/goldshop) | [`/goldshop`](/goldshop) | فاکتور طلا/قیمت لحظه‌ای/اجناس |
| [فروشگاه اینترنتی](/store) | [`store/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/store) | [`/store`](/store) | سبد/سفارش/محصولات/مشتریان |
| [ارز و معاملات ارزی](/currency) | [`currency/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/currency) | [`/currency`](/currency) | تابلو ارز/کیف پول/خرید-فروش/تبدیل/معاملات ترکیبی/ارزش لحظه‌ای |
| [داشبورد BI](/bi) | [`bi/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/bi) | [`/bi`](/bi) | ۱۴ تب اجرایی/مالی/طلا/ارز/انبار/... + هشدار + چاپ گزارش (QuestPDF) |
| [پلتفرم مشترک](/central) | [`central/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/central) | [`/central`](/central) | کاربران/نقش‌ها/اخبار/بلاگ/گالری/ممیزی + شرکت مالی/سال مالی |

*اسکیمه‌های جانبی: [`printing/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/printing) (قالب‌های چاپ) و [`assets/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/assets) + [`branch/`](https://github.com/ho3eines/Projects/tree/main/Tarazin.Data/Scripts/branch) (ساختار چندشعبه‌ای BI).*

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

* قوانین: UI فقط در `Tarazin.Ui/Modules/...`، مدل فقط در `Tarazin.Share`، داده فقط در `Tarazin.Data/Scripts/{schema}/`، هیچ SQL خام در Razor و هیچ HTTP برای انتقال عملیات کسب‌وکار (فقط endpoint bootstrap اتصال MAUI و `PriceFeedService` بازار خارجی). مرز اسکیمه با `tools/cross-schema-scan.sh` چک می‌شود. — جزئیات در `docs/PROJECT.md` و `docs/adr/`.*

---

## 🚀 اجرای سریع

```bash
# 1. اتصال issuer وب را فقط از secret store/متغیر محیطی تزریق کنید.
# TARAZIN_SQL_CONNECTION را در shell یا تنظیمات امن سرویس قرار دهید؛
# هیچ credentialی را در appsettings.json یا APK/EXE قرار ندهید.

# 2. اجرای وب در محیط توسعه
dotnet run --project Tarazin.Web

# 3. انتشار برای IIS
dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish
# پوشهٔ publish را در IIS به‌عنوان سایت ASP.NET Core ثبت کنید.

# 4. اپ بومی (ویندوز — نیاز به workload)
dotnet workload install maui
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-windows10.0.19041.0
# بیلد/F5 دیباگ framework-dependent است (ویندوز App SDK runtime روی دستگاه توسعه لازم است؛
# workload مائوئی VS آن را نصب/register می‌کند). MSIX ریلیز self-contained ساخته می‌شود.

# 5. انتشار اپ بومی
# ویندوز x64 (MSIX — در Visual Studio روی پروژهٔ Tarazin.Maui راست‌کلیک → Publish):
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64 -p:WindowsAppSDKSelfContained=true
# نصب MSIX روی دستگاه دیگر به گواهی امضا نیاز دارد (در wizard می‌توانید self-signed بسازید).
# برای تست سریع بدون MSIX/نصب، از publish profile پوشه‌ای استفاده کنید و exe خروجی را مستقیم اجرا کنید:
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj /p:PublishProfile=Folder-win10-x64
# اگر برنامه بالا نیامد یا صفحهٔ خطای راه‌اندازی نشان داد، لاگ را از این مسیر بخوانید:
# %LocalAppData%\Tarazin\maui-crash.log
# راهنمای کامل: docs/WINDOWS_MAUI_LAUNCH.md

# اندروید — APK امضاشدهٔ release. یک‌بار keystore بسازید (خارج از repo نگه دارید):
keytool -genkeypair -v -keystore %USERPROFILE%\tarazin-release.keystore -alias tarazin -keyalg RSA -keysize 2048 -validity 10000
# سپس (پسوردها را فقط همین‌جا/در CI secret بدهید، نه در csproj):
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-android ^
  -p:AndroidKeyStore=true ^
  -p:AndroidSigningKeyStore=%USERPROFILE%\tarazin-release.keystore ^
  -p:AndroidSigningKeyAlias=tarazin ^
  -p:AndroidSigningKeyPass=<secret> -p:AndroidSigningStorePass=<secret>
# خروجی: Tarazin.Maui/bin/Release/net8.0-android/publish/*.apk — سایدلود یا Play Console (AAB با -p:AndroidPackageFormat=aab).
# بدون keystore هم publish روی اندروید کار می‌کند ولی با debug-key امضا می‌شود (فقط برای تست).

# iOS — فقط روی macOS (Xcode + workload) یا از VS ویندوز با «Pair to Mac»:
dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-ios
# برای App Store/TestFlight یا دستگاه واقعی: حساب Apple Developer + provisioning از Xcode/VS لازم است
# (Distribution → App Store Connect در VS، یا Archive در Xcode)

# نکتهٔ حیاتی برای دستگاه‌های واقعی (Android/iOS):
# 1) ServerEndpoint پیش‌فرض https://localhost:65220 روی دستگاه به خودِ دستگاه اشاره می‌کند؛
#    آن را به نشانی HTTPS عمومی وب (کامپیوتر توسعه: IP شبکه + گواهی قابل اعتماد) عوض کنید یا
#    با متغیر محیطی TARAZIN_SERVER_ENDPOINT هنگام build تزریق کنید.
# 2) رشتهٔ اتصال SQL سرور نیز باید به DNS/IP قابل‌دسترس از دستگاه اشاره کند (localhost برای خروجی موبایل معنا ندارد).
```

* مدیریت اتصال SQL در Web است؛ رشتهٔ اتصال issuer از secret استقرار `TARAZIN_SQL_CONNECTION` می‌آید و `appsettings.json` منبع credential تولید نیست. `bootstrap password` فقط از secret استقرار می‌آید.
* اتصال SQL با `Encrypt=true` و `TrustServerCertificate=true` ساخته می‌شود (رمزنگاری کانال فعال، اعتبارسنجی گواهی غیرفعال — تصمیم ۱۴۰۵/۰۵/۲۹؛ جزئیات در `docs/SECURITY.md`).
* MAUI مستقیماً به `Data Source` همان رشتهٔ اتصالِ سرور وصل می‌شود؛ مقدار `localhost` فقط پیش‌فرض توسعهٔ محلیِ Windows است. برای دستگاه‌های دیگر، اتصال سرور باید به DNS/IP قابل‌دسترس از همان دستگاه اشاره کند.
* `Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` عمومی HTTPS دارد. ورود در هر دو هاست دقیقاً یکسان است (همان `AuthService`/PBKDF2 محلی)؛ در MAUI فقط قبل از اولین ورود، یک‌بار `POST /api/mobile/connection` (همان بررسی اعتبار سمت سرور) **رشتهٔ اتصال SQL را رمزگذاری‌شده** (AES-256 با کلید مشتق از خود رمز ورود) می‌آورد؛ رمزگشایی فقط در حافظه و اجرا با `DbService` مشترک است.
* اولین initialization فقط در Web اجرا می‌شود: `_Ensure.sql` → `_Seed.sql` → نقش‌ها/دسترسی‌ها → ساخت مدیر اولیه با password تزریق‌شده. هیچ رمز پیش‌فرضی وجود ندارد.
* اسکریپت‌های نامدار Embedded هستند (`Tarazin.Scripts.{schema}.{name}.sql`)؛ MAUI پس از دریافت رشتهٔ اتصال رمزگذاری‌شده از API، همان عملیات مستقیم `DbService` را اجرا می‌کند.

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

### 🖨️ گاردهای pymupdf — چرا step «آبی» (skip) می‌ماند؟

گاردهای RTL/A5L (`bash tools/check-rtl-headers.sh all` از درون `tools/run-checks.sh`) عمداً **اختیاری** هستند: اگر پیش‌نیازشان نباشد به‌جای Fail، رسماً **SKIP** می‌شوند (exit 0 — گام در CI به رنگ آبی/خنثی دیده می‌شود). مسیرهای skip به این ترتیب‌اند:

| حالت skip | پیام در لاگ | معنی | راه‌حل |
|---|---|---|---|
| پایتون نصب نیست | `pymupdf check skipped — Python not available (optional step).` | `py`/`python3` در PATH نیست | `py --version` یا نصب Python 3.12+ |
| ماژول pymupdf نصب نیست | `pymupdf not installed (optional step).` | پایتون هست ولی `import pymupdf` جواب نمی‌دهد | `py -m pip install pymupdf` (در CI خودکار نصب می‌شود) |
| فایل‌های dump تولید نشده‌اند | `dumped PDFs not found (run the full test suite first).` | تستِ `Dump_rtl_header_pdfs_for_pymupdf` اجرا نشده تا PDFهای نمونه در `%TEMP%/tarazin-pdf/rtl-headers/` ساخته شوند | اول `dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo` را اجرا کن |
| فایلِ یک گاردِ اختصاصی کم است | `template-a5l.pdf not found` / `table-a5l.pdf` / `template-a5l-noheader.pdf` / `table-a5l-many.pdf` / `invoice-a5l-many.pdf not found` | تستِ dump فقط بخشی از فایل‌ها را ساخته (یا پوشه پاک شده) | همان: تست کامل را اجرا کن تا هر ۵ فایلِ گارد ساخته شوند |

> ⚠️ نکتهٔ CI: در GitHub Actions پایتون و pymupdf نصب می‌شوند و فایل‌های dump از همان اجرای تستِ گام قبل می‌آیند — پس **در CI این گام‌ها نباید آبی بمانند**. اگر در CI آبی دیدی، یعنی یا `pip install pymupdf` شکست خورده یا تست dump رد شده/فایل‌ها را نساخته — خطا واقعی است، نه skip عمدی.

دستور فعال‌سازی محلی: نصب pymupdf + اجرای تست کامل (برای ساخت فایل‌های dump) + سپس `bash tools/check-rtl-headers.sh all` — بعد از آن گام‌ها سبز (اجرا) می‌شوند نه آبی.

## 🧭 اسکیل‌های راهنما (SKILL.md) — منبع اصلی قوانین کدنویسی

> برای توسعه‌دهنده، **منبع راهنما در `.claude/skills/` است** (نه فقط همین README). این چهار اسکیل، قراردادهای الزامی معماری، UI و گزارش‌سازی را یک‌جا نگه می‌دارند؛ هر صفحه/داده/گزارش جدید باید مطابق آن‌ها باشد. همه از گیت در دسترس‌اند (هر یک در `.claude/skills/{name}/SKILL.md`).

| اسکیل | فایل | موضوع آن | قبل از چه کاری بخوان |
|---|---|---|---|
| **توسعه** | `.claude/skills/tarazin-development/SKILL.md` | معماری ۵ لایه، لایهٔ داده (`DbService` + اسکریپت نامدار + اسکیمه)، RBAC، قواعد MudBlazor 9.8.0، الگوهای مودال/نوبار، قانون طلایی بیلد | هر تغییر کد |
| **UI/UX** | `.claude/skills/tarazin-ui-ux/SKILL.md` | کاتالوگ کامپوننت‌های مشترک (`PageHeader/PageToolbar/TzDataTable/StatCard/...`)، اسکلت صفحهٔ لیست/فرم/داشبورد، پالت `TarazinAccents` و قراردادهای CSS/RTL | ساخت یا ویرایش هر صفحهٔ `.razor` |
| **گزارش‌سازی** | `.claude/skills/tarazin-reporting/SKILL.md` | یک روال واحد برای گزارش‌ها (اسکلت صفحه + `ReportPrintDialog` + `PdfReportService.BuildTablePdf` + `PdfFileNames` + IPdfSaver)، قانون بیلد پس از تغییر گزارش | ساخت/ویرایش هر صفحهٔ گزارش، دیالوگ چاپ یا خروجی PDF |
| **تست بصری ویندوز** | `.claude/skills/windows-computer-control/SKILL.md` | workflow اسکرین‌شات/تخته‌یui/OCR و UI-Automation برای تست چشمی و ریسپانسیو | تست چشمی/دستگاه |

> 📇 **خلاصهٔ یک‌جای هر ۴ اسکیل + سناریوی استفاده:** [`docs/SKILLS_INDEX.md`](docs/SKILLS_INDEX.md).
>
> ⚠️ **قاعدهٔ طلایی:** اگر بین یک اسکیل و کد واقعی اختلاف دیدی، **اسکیل را به‌روز کن** نه اینکه برخلافش کد بزنی.

---

> **⚠️ قانون طلایی بیلد:** بعد از **هر تغییر در `Tarazin.Ui`** (رو `Tarazin.Ui` یا `Tarazin.Share`/`Tarazin.Data` اگر کد قرار است با `--no-build` اجرا شود) حتماً `dotnet build Tarazin.Web/Tarazin.Web.csproj` را بزن. `dotnet test` یا بیلدِ تکیِ `Tarazin.Ui` فقط `Tarazin.Ui/bin` را به‌روز می‌کند؛ کپیِ `Tarazin.Web/bin` **تازه نمی‌شود** و سرورِ `dotnet run --no-build` همان کد کهنه را سرو می‌کند (باگ «ستون‌ها درست شد ولی هدر نه»). تست/بیلد قبلی را پشت‌سرهم بگیر: `bash tools/run-checks.sh` (تست PDF + گارد `tools/check-stale-build.sh` + اسکن اسکیمه)

---

*ساخته شده با MudBlazor 9.8.0 — RTL فارسی — یک UI، دو هاست — ترازین.*
