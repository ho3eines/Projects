# ترازین — مدیریت هوشمند کسب‌وکار

> **وضعیت:** فعال — آخرین به‌روزرسانی ۱۴۰۵/۰۵/۲۷ (2026-08-18) — نسخه 2.3
> **معماری:** ۵ پروژهٔ تمیز با وابستگی یک‌طرفه — `Share ← Data ← Ui ← {Web, Maui}` — یک UI، دو هاست (وب + اپ بومی)
>
> 🧑‍💻 **توسعه‌دهنده؟ قبل از هر تغییر/دریافت پارامتر، اول `.claude/skills/tarazin-development/SKILL.md` را کامل بخوان** (اسکیل رسمی پروژه — با `/tarazin-development` هم قابل فراخوانی است) — معماری، لایهٔ داده، قواعد MudBlazor 9.8.0، دسترسی‌ها و الگوهای مودال/نوبار همه در آن سند است و هر تغییری باید مطابق آن باشد.

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

---

*ساخته شده با MudBlazor 9.8.0 — RTL فارسی — یک UI، دو هاست — ترازین.*
