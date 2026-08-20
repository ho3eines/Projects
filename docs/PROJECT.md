# 📘 ترازین — مدیریت هوشمند کسب‌وکار (Master Blueprint — Blazor Hybrid)

> **Last updated**: 2026-08-12 (v2.2 — لایه‌بندی Share/Data/Ui)
> **قانون طلایی**: ۵ پروژهٔ تمیز با وابستگی یک‌طرفه — **Share (مدل‌ها) ← Data (داده) ←
> Ui (رابط مشترک) ← {Web, Maui} (هاست‌ها)**. هر محصول یک ماژول و یک اسکیمه؛ UI = MudBlazor.

---

## 🧭 Overview

پلتفرم یکپارچهٔ سازمان با **هفت محصول** که در **۵ پروژه** با لایه‌بندی روشن ساخته شده:

1. **`Tarazin.Share`** — مدل‌ها و قراردادهای مشترک (POCO؛ بدون هیچ وابستگی).
2. **`Tarazin.Data`** — لایهٔ داده: `DbService` (Dapper) + `ScriptCatalog`
   (اسکریپت‌های TSQL نامدار به‌صورت Embedded) + ممیزی.
3. **`Tarazin.Ui`** — رابط کاربری مشترک (RCL): همهٔ صفحات ماژول‌ها + چیدمان + سرویس‌های
   نشست/ورود. **همین UI در هر دو هاست رندر می‌شود.**
4. **`Tarazin.Web`** — هاست وب (Blazor Server در مرورگر).
5. **`Tarazin.Maui`** — هاست بومی (MAUI Blazor Hybrid در BlazorWebView).

عملیات کسب‌وکار فقط از طریق **اسکریپت‌های TSQL نامدار** (Embedded در
`Tarazin.Data`) و Dapper انجام می‌شوند. Web آن‌ها را با provider سمت سرور اجرا
می‌کند. MAUI پس از ورود موفق در `POST /api/mobile/login`، رشتهٔ اتصال سرور را
رمزگذاری‌شده (AES با کلید مشتق از رمز ورود) دریافت، در حافظه رمزگشایی می‌کند و
همان عملیات مستقیم و نامدار را اجرا می‌کند؛ این endpoint یک API عمومی CRUD یا
انتقال‌دهندهٔ دادهٔ کسب‌وکار نیست.

> 📋 **PRD محصولات**: `PRD.md` · `PRD_All_Projects.md`
> 🗺️ **برنامهٔ کار**: `docs/PLATFORM_ROADMAP.md`
> 🧩 **تصمیم‌های معماری**: `docs/adr/` (ADR-001..005)
> 🤖 **راهنمای عامل**: `.agents/tarazin-tsql/SKILL.md`
> 📱 **راهنمای MAUI**: `skills/blazor/blazor-maui-hybrid/SKILL.md`

---

## 🗂️ Directory Layout

```
Tarazin.slnx                       ← ۵ پروژه
│
├── Tarazin.Share/                 ← لایهٔ ۱: مدل‌ها/قراردادها (Class Library — بدون وابستگی)
│   ├── Tarazin.Share.csproj
│   └── SharedModels.cs, AccountingModels.cs, InventoryModels.cs,
│       TreasuryModels.cs, PayrollModels.cs, GoldShopModels.cs,
│       StoreModels.cs, CentralModels.cs      (namespace: Tarazin.Models)
│
├── Tarazin.Data/                  ← لایهٔ ۲: دسترسی به داده (Class Library)
│   ├── Tarazin.Data.csproj        ← Dapper + SqlClient؛ اسکریپت‌ها Embedded
│   ├── DbService.cs               ← Query/Execute/Scalar با اسکریپت نامدار (Dapper)
│   ├── ScriptCatalog.cs           ← بارگذاری Embedded: Tarazin.Scripts.{schema}.{name}.sql
│   ├── AuditService.cs            ← ممیزی با زنجیرهٔ هش
│   ├── PasswordHasher.cs          ← PBKDF2
│   ├── ICurrentUser.cs            ← انتزاع کاربر جاری (بدون وابستگی به Ui)
│   ├── TarazinDbInitializer.cs    ← ensure/seed/bootstrap-admin (فقط Web)
│   ├── DataServiceCollectionExtensions.cs  ← AddTarazinDataServices()
│   └── Scripts/{schema}/*.sql     ← ۱۰۰ اسکریپت نامدار (EmbeddedResource)
│
├── Tarazin.Ui/                    ← لایهٔ ۳: رابط کاربری مشترک (Razor Class Library)
│   ├── Tarazin.Ui.csproj          ← MudBlazor + ref → Share, Data
│   ├── App.razor                  ← Router + MudThemeProvider/Dialog/Snackbar + init
│   ├── _Imports.razor             ← usingهای مشترک (Tarazin.Models/Services/Data + MudBlazor)
│   ├── Layout/
│   │   ├── MainLayout.razor       ← MudLayout + MudDrawer + MudAppBar
│   │   └── NavMenu.razor          ← MudNavMenu (۹ ماژول)
│   ├── Services/
│   │   ├── UserSession.cs         ← نشست (ICurrentUser)
│   │   ├── AuthService.cs         ← ورود از [central].[Users] (PBKDF2)
│   │   └── ServiceCollectionExtensions.cs  ← AddTarazinUiServices() (هر دو هاست)
│   ├── Modules/
│   │   ├── Home/Pages/            ← / (launcher) و /login
│   │   ├── Central/Pages/         ← /central, /central/news, /blog, /gallery, /users, /audit
│   │   ├── Accounting/Pages/      ← /accounting{,/dashboard,/entry,/document/{id},/chart,/reports,/special}
│   │   ├── Inventory/Pages/       ← /inventory…
│   │   ├── Treasury/Pages/        ← /treasury…
│   │   ├── Payroll/Pages/         ← /payroll…
│   │   ├── GoldShop/Pages/        ← /goldshop…
│   │   ├── Store/Pages/           ← /store…
│   │   └── Currency/Pages/        ← /currency (ارز و معاملات ارزی — PRD §34–§63)
│   └── wwwroot/css/app.css        ← استاتیک RCL → _content/Tarazin.Ui/css/app.css
│
├── Tarazin.Web/                   ← هاست وب (Blazor Server — فقط پوسته)
│   ├── Tarazin.Web.csproj         ← ref → Tarazin.Ui
│   ├── Program.cs                 ← AddServerSideBlazor + AddMudServices + AddTarazinUiServices + init
│   ├── Pages/_Host.cshtml         ← قالب RTL؛ <component type="typeof(App)"> (از Tarazin.Ui)
│   ├── _ViewImports.cshtml
│   └── appsettings.json           ← تنظیمات عمومی؛ SQL/bootstrap secret از deployment
│
└── Tarazin.Maui/                  ← هاست MAUI Blazor Hybrid (فقط پوسته)
    ├── Tarazin.Maui.csproj        ← ref → Tarazin.Ui؛ TFM های android/ios/maccatalyst/windows
    ├── MauiProgram.cs             ← AddMauiBlazorWebView + AddMudServices + AddTarazinUiServices
    ├── App.xaml / App.xaml.cs
    ├── MainPage.xaml              ← BlazorWebView + RootComponent → {x:Type tarazin:App}
    ├── wwwroot/index.html         ← RTL؛ blazor.webview.js + _content/Tarazin.Ui/css/app.css
    ├── appsettings.json           ← Embedded؛ فقط ServerEndpoint عمومی HTTPS
    ├── Resources/                 ← AppIcon, Splash, Styles
    └── Platforms/                 ← Android / iOS / MacCatalyst / Windows
docker-compose.yml                 ← فقط SQL Server
ci/ci.yml                          ← build وب (ubuntu) + build MAUI (windows + workload maui)
tools/cross-schema-scan.sh         ← بررسی مرز اسکیمه‌ها (Tarazin.Data/Scripts)
```

## 🔗 وابستگی‌ها (یک‌طرفه — هرگز برعکس)

```
Tarazin.Share ──► (هیچ‌کس)
Tarazin.Data  ──► Tarazin.Share
Tarazin.Ui    ──► Tarazin.Share + Tarazin.Data
Tarazin.Web   ──► Tarazin.Ui   (و غیرمستقیم Share/Data)
Tarazin.Maui  ──► Tarazin.Ui   (و غیرمستقیم Share/Data)
```

- **Share** = POCOها (قراردادهای دامنه، ADR-003). هیچ لایه‌ای به آن وابسته نیست جز مصرف.
- **Data** = فقط داده؛ به UI هیچ‌چیز نمی‌داند (`ICurrentUser` برای نام کاربر در ممیزی).
- **Ui** = فقط ارائه؛ همهٔ داده از `DbService` (در Data).
- هاست‌ها فقط ثبت سرویس + رندر `Tarazin.App`.

## 🔑 Key Rules

1. **UI فقط در `Tarazin.Ui`** — صفحات جدید همیشه آنجا ساخته می‌شوند تا وب و MAUI
   هر دو به‌طور خودکار بگیرندش. هاست‌ها فقط «پوسته» هستند.
2. **مدل‌ها فقط در `Tarazin.Share`** — namespace ثابت `Tarazin.Models`؛ اسکریپت‌ها
   باید با همین نام‌ها هم‌نام باشند (ADR-003).
3. **داده فقط در `Tarazin.Data`** — هیچ `DbService`/SQL در Ui یا هاست‌ها تعریف نمی‌شود.
4. **دو هاست، یک هسته** — `AddTarazinUiServices()` در `Program.cs` (وب) و
   `MauiProgram.cs` (MAUI)؛ `App.razor` مشترک در هر دو رندر می‌شود.
5. **MudBlazor** — صفحهٔ جدید فقط با کامپوننت‌های Mud؛ Bootstrap/جدول سفارشی ممنوع.
6. **اسکریپت نامدار** — صفحات SQL خام ندارند؛ همه چیز `Tarazin.Data/Scripts/{schema}/{Name}.sql`
   که در `ScriptCatalog` (EmbeddedResource) بارگذاری می‌شود.
7. **مرز اسکیمه** — ماژول فقط `{schema}` خودش را صدا می‌زند؛ اسکریپت سرور می‌تواند
   با `-- Cross-schema:` خواندن بین‌اسکیمه‌ای مجاز انجام دهد.
8. **Report-first** — قبل از کد: تحقیق گزارش‌های دامنه → مدل‌ها → اسکریپت‌ها → صفحات.

## 🧩 چهار بخش استاندارد هر ماژول
1. **ورود عملیات (Entry)** — عملیات ورود داده (ثبت سند، رسید/حواله، …)
2. **عملیات ویژه (Special Operations)** — بستن دوره، انبارگردانی، نهایی‌کردن حقوق، …
3. **گزارشات (Reports)** — همهٔ گزارش‌ها اینجا؛ منبع طراحی مدل‌ها
4. **امکانات (Settings)** — جداول پایه (حساب‌ها، کالاها، کارمندان، …)

## 🏠 صفحهٔ اصلی هر ماژول
- جعبهٔ جستجوی سند/حرکت با فیلتر **از تاریخ تا تاریخ** (پیش‌فرض امروز)
- جدول روز (MudTable) — کلیک روی ردیف، آیتم را باز می‌کند

## 📊 Dashboard
- خلاصهٔ همهٔ بخش‌های ماژول (کارت‌های آماری MudPaper)

## 🔐 Auth
- bootstrap admin فقط در اولین initialization و با password الزامی از secret store ساخته می‌شود؛ password پیش‌فرض وجود ندارد.
- وب: `AuthService` مستقیماً PBKDF2 را سمت سرور بررسی می‌کند و نشست در `UserSession` هر circuit است.
- MAUI: فرم ورود فقط نام کاربری و رمز را می‌گیرد. `POST /api/mobile/login` همان بررسی PBKDF2 ورود وب را انجام می‌دهد و پس از ورود موفق رشتهٔ اتصال سرور را رمزگذاری‌شده (کلید مشتق از رمز ورود) برمی‌گرداند؛ رشتهٔ رمزگشایی‌شده فقط در حافظهٔ اپ است.
- مدیریت کاربران در `/central/users`

## 🗄️ Data Layer
- Web اتصال مدیریتی SQL را از secret استقرار می‌گیرد (`TARAZIN_SQL_CONNECTION` یا provider تنظیمات server-side). مقدار واقعی در repository نیست.
- MAUI هیچ connection string دائمی ندارد. `ApiConnectionSession` رشتهٔ اتصال رمزگذاری‌شده را از API می‌گیرد، در حافظه رمزگشایی می‌کند و provider قابل‌جایگزینی Data را با همان تغذیه می‌کند (اعتبارسنجی گواهی طبق تصمیم ۱۴۰۵/۰۵/۲۹ غیرفعال است).
- اسکریپت‌ها Embedded در `Tarazin.Data` هستند؛ embed شدن اسکریپت به معنی embed شدن credential نیست.
- initialization دیتابیس فقط در Web اجرا می‌شود: `TarazinDbInitializer.EnsureInitializedAsync` → `_Ensure.sql`ها → `_Seed.sql`ها → RBAC → bootstrap admin → mobile RLS.
- مسیر business پس از login تغییر نکرده است: `DbService.QueryAsync<T>(schema, name, @params)` / `ExecuteAsync` / `ScalarAsync`.

## 🕵️ Audit
- **خودکار**: هر `DbService.ExecuteAsync(...)` یک ردیف ممیزی ثبت می‌کند
  (موفقیت یا خطا) — صفحات نیازی به فراخوانی دستی ندارند.
- ذخیره در `[central].[AuditLog]` با `PrevHash`/`RowHash` (SHA-256) — مشاهده در `/central/audit`
- پارامترها ذخیره نمی‌شوند؛ فقط schema/script/user/outcome/error.

## 📱 MAUI Blazor Hybrid (خلاصه)
- `Tarazin.Maui/MainPage.xaml`: `BlazorWebView` + `RootComponent` → `Tarazin.App` (از `Tarazin.Ui`)
- `wwwroot/index.html`: اسکریپت رانتایم `_framework/blazor.webview.js` (نه server.js)
- `appsettings.json` فقط `ServerEndpoint` عمومی HTTPS دارد؛ secret در package/IL قرار نمی‌گیرد.
- login رشتهٔ اتصال رمزگذاری‌شده را از `POST /api/mobile/login` می‌گیرد؛ سپس همان `DbService` و اسکریپت‌های نامدار مستقیم اجرا می‌شوند. logout باعث پاک‌سازی حافظه/pool می‌شود.
- رشتهٔ اتصال در حافظهٔ یک کلاینت compromise‌شده قابل استخراج است؛ دفاع بر TLS، احراز هویت کاربر و عدم نگه‌داری محلی است، نه رمزنگاری با کلید دائمی داخل اپ.
- سازگاری runtime مستقیم SqlClient برای هر target باید در build/E2E همان پلتفرم تأیید شود.
- **پیش‌نیاز build محلی**: TFMهای `net8.0-android/ios/maccatalyst/windows` نیازمند
  workload مربوط به MAUI هستند؛ بدون آن restore با خطای `NU1012` (Platform version is not
  present) شکست می‌خورد. نصب: `dotnet workload install maui` (یا نصب
  «Mobile development with .NET» در Visual Studio). CI این کار را در job `build-maui`
  انجام می‌دهد؛ build وب (`Tarazin.Web`) به MAUI وابسته نیست.

## ❌ Explicit Bans
- ❌ پروژه/پکیج جدید خارج از پنج‌تایی `Share / Data / Ui / Web / Maui`
- ❌ صفحهٔ جدید خارج از `Tarazin.Ui/Modules`؛ مدل جدید خارج از `Tarazin.Share`
- ❌ وابستگی معکوس (Data → Ui یا Ui → Web) و HTTP برای CRUD/business data؛ endpoint ورود MAUI و feed رسمی بازار استثناهای مشخص‌اند
- ❌ Bootstrap دستی، CSS سفارشی زیاد، DataGrid سفارشی (همه MudBlazor)
- ❌ SQL خام در `.razor` و تعریف `DbService` در هاست‌ها
- ❌ پرسیدن دوبارهٔ ساختار از کاربر

## ✅ Workflow برای هر ماژول جدید
1. تحقیق گزارش‌های موردنیاز دامنه
2. طراحی مدل‌ها (`Tarazin.Share/Models/{Module}Models.cs`)
3. نوشتن اسکریپت‌ها (`Tarazin.Data/Scripts/{schema}/…sql` + `_Ensure`/`_Seed`)
4. صفحات MudBlazor در `Tarazin.Ui/Modules/{Name}/Pages/` + افزودن به `NavMenu` و `Home`
5. اجرای `tools/cross-schema-scan.sh` — نتیجه به‌صورت خودکار در وب و MAUI می‌آید
