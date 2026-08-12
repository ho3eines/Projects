# 📘 ترازین — مدیریت هوشمند کسب‌وکار (Master Blueprint — Blazor Hybrid)

> **Last updated**: 2026-08-12 (v2.1 — افزوده‌شدن MAUI Blazor Hybrid)
> **قانون طلایی**: یک **هستهٔ مشترک** (RCL) با همهٔ صفحات/مدل‌ها/سرویس‌ها/اسکریپت‌ها +
> دو هاست نازک: **وب (Blazor Server)** و **اپلیکیشن دسکتاپ/موبایل (MAUI Blazor Hybrid)**.
> UI = MudBlazor؛ هر محصول یک ماژول و یک اسکیمه.

---

## 🧭 Overview

پلتفرم یکپارچهٔ سازمان با **هفت محصول** که UI آن در `Tarazin.Shared` (Razor Class
Library) تعریف شده و **دوبار** میزبانی می‌شود:

1. **هاست وب** (`Tarazin.Web`) — Blazor Server: همان UI با SignalR در مرورگر.
2. **هاست MAUI** (`Tarazin.Maui`) — MAUI Blazor Hybrid: همان UI داخل BlazorWebView
   با دسترسی کامل به رانتایم .NET بومی (ویندوز/اندروید/iOS/macOS).

داده فقط از طریق **اسکریپت‌های TSQL نامدار** (به‌صورت Embedded Resource در
`Tarazin.Shared`) که در همان پروسه با Dapper اجرا می‌شوند؛ **هیچ وب‌سرویس، هیچ
لایهٔ HTTP برای داده وجود ندارد**.

> 📋 **PRD محصولات**: `PRD.md` · `PRD_All_Projects.md`
> 🗺️ **برنامهٔ کار**: `docs/PLATFORM_ROADMAP.md`
> 🧩 **تصمیم‌های معماری**: `docs/adr/` (ADR-001 · ADR-002 · ADR-003 · ADR-004 MAUI Hybrid)
> 🤖 **راهنمای عامل**: `.agents/tarazin-tsql/SKILL.md`
> 📱 **راهنمای MAUI**: `skills/blazor/blazor-maui-hybrid/SKILL.md`

---

## 🗂️ Directory Layout

```
Tarazin.slnx                       ← ۳ پروژه
│
├── Tarazin.Shared/                ← هستهٔ مشترک (Razor Class Library — RootNamespace: Tarazin)
│   ├── Tarazin.Shared.csproj      ← MudBlazor + Dapper + SqlClient؛ اسکریپت‌ها Embedded
│   ├── App.razor                  ← Router + MudThemeProvider/Dialog/Snackbar + init (مشترک)
│   ├── _Imports.razor             ← usingهای مشترک (Tarazin.Models / Services / Layout / MudBlazor)
│   ├── Layout/
│   │   ├── MainLayout.razor       ← MudLayout + MudDrawer + MudAppBar
│   │   └── NavMenu.razor          ← MudNavMenu (۷ ماژول)
│   ├── Models/
│   │   ├── SharedModels.cs        ← قراردادهای مشترک (Party, ChartOfAccount, …)
│   │   ├── AccountingModels.cs … CentralModels.cs
│   ├── Services/
│   │   ├── ScriptCatalog.cs       ← بارگذاری اسکریپت‌ها از EmbeddedResource (خودکار در ctor)
│   │   ├── DbService.cs           ← Query/Execute/Scalar با اسکریپت نامدار (Dapper)
│   │   ├── AuthService.cs         ← ورود از [central].[Users] (PBKDF2)
│   │   ├── UserSession.cs         ← نشست
│   │   ├── AuditService.cs        ← ممیزی با زنجیرهٔ هش
│   │   ├── PasswordHasher.cs
│   │   ├── ServiceCollectionExtensions.cs  ← AddTarazinSharedServices() — هر دو هاست صدا می‌زنند
│   │   └── TarazinDbInitializer.cs        ← ensure/seed/bootstrap-admin یک‌بار (هر دو هاست)
│   ├── Modules/
│   │   ├── Home/Pages/            ← / (launcher) و /login
│   │   ├── Central/Pages/         ← /central, /central/news, /blog, /gallery, /users, /audit
│   │   ├── Accounting/Pages/      ← /accounting{,/dashboard,/entry,/reports,/special,/settings}
│   │   ├── Inventory/Pages/       ← /inventory…
│   │   ├── Treasury/Pages/        ← /treasury…
│   │   ├── Payroll/Pages/         ← /payroll…
│   │   ├── GoldShop/Pages/        ← /goldshop…
│   │   └── Store/Pages/           ← /store…
│   ├── Data/Scripts/              ← ۱۰۰ اسکریپت نامدار (EmbeddedResource → هم‌هاست‌ها)
│   │   ├── accounting/  *_Ensure.sql, *_Seed.sql, DailyDocuments.sql, …
│   │   ├── central/     UserAuthenticate.sql, AuditInsert.sql, NewsUpsert.sql, …
│   │   ├── inventory/ treasury/ payroll/ goldshop/ store/
│   └── wwwroot/css/app.css        ← استاتیک RCL → _content/Tarazin.Shared/css/app.css
│
├── Tarazin.Web/                   ← هاست وب (Blazor Server — RootNamespace: Tarazin.Web)
│   ├── Tarazin.Web.csproj         ← فقط ProjectReference به Tarazin.Shared
│   ├── Program.cs                 ← AddServerSideBlazor + AddMudServices + AddTarazinSharedServices + init
│   ├── Pages/_Host.cshtml         ← قالب RTL؛ <component type="typeof(App)"> (از Tarazin.Shared)
│   ├── _ViewImports.cshtml
│   ├── appsettings.json           ← ConnectionStrings + Tarazin:* (bootstrap admin)
│   └── Properties/launchSettings.json
│
└── Tarazin.Maui/                  ← هاست MAUI Blazor Hybrid (RootNamespace: Tarazin.Maui)
    ├── Tarazin.Maui.csproj        ← net10.0-{android,ios,maccatalyst,windows}; ref → Tarazin.Shared
    ├── MauiProgram.cs             ← AddMauiBlazorWebView + AddMudServices + AddTarazinSharedServices
    ├── App.xaml / App.xaml.cs     ← MAUI Application
    ├── MainPage.xaml              ← BlazorWebView + RootComponent → {x:Type tarazin:App} (مشترک)
    ├── wwwroot/index.html         ← RTL؛ blazor.webview.js + _content/Tarazin.Shared/css/app.css
    ├── appsettings.json           ← Embedded (همان ساختار وب)
    ├── Resources/                 ← AppIcon, Splash, Styles (MudBlazor UI → minimal)
    └── Platforms/                 ← Android / iOS / MacCatalyst / Windows
docker-compose.yml                 ← فقط SQL Server
ci/ci.yml                          ← build وب (ubuntu) + build MAUI (windows + workload maui)
tools/cross-schema-scan.sh         ← بررسی مرز اسکیمه‌ها (Tarazin.Shared/Data/Scripts)
```

---

## 🔑 Key Rules

1. **UI فقط در `Tarazin.Shared`** — صفحات جدید همیشه آنجا ساخته می‌شوند تا وب و MAUI
   هر دو به‌طور خودکار بگیرندش. هاست‌ها فقط «پوسته» هستند.
2. **دو هاست، یک هسته**: `Tarazin.Web` (Blazor Server) و `Tarazin.Maui` (Blazor
   Hybrid) هر دو `AddTarazinSharedServices()` را صدا می‌زنند و `App.razor` مشترک را
   رندر می‌کنند.
3. **MudBlazor** — صفحهٔ جدید فقط با کامپوننت‌های Mud؛ Bootstrap/جدول سفارشی ممنوع.
4. **اسکریپت نامدار** — صفحات SQL خام ندارند؛ همه چیز `Data/Scripts/{schema}/{Name}.sql`
   که در `ScriptCatalog` (EmbeddedResource) بارگذاری می‌شود.
5. **مرز اسکیمه** — ماژول فقط `{schema}` خودش را صدا می‌زند؛ اسکریپت سرور می‌تواند
   با `-- Cross-schema:` خواندن بین‌اسکیمه‌ای مجاز انجام دهد.
6. **Report-first** — قبل از کد: تحقیق گزارش‌های دامنه → مدل‌ها → اسکریپت‌ها → صفحات.
7. **ابزار اسکن** به مسیر جدید (`Tarazin.Shared/Data/Scripts`) به‌روزرسانی شده؛
   CI شامل build وب (ubuntu) و build MAUI (windows + workload maui) است.

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
- ورود `/login` با کاربر bootstrap (`admin`/`admin` — در اولین اجرا ساخته می‌شود)
- وب: نشست در `UserSession` (هر circuit) — MAUI: نشست در سطح اپ (scoped ≈ singleton)
- مدیریت کاربران در `/central/users`

## 🗄️ Data Layer
- یک ConnectionString: `ConnectionStrings:DefaultConnection` → `TarazinMaster`
  (وب: appsettings.json — MAUI: appsettings.json Embedded)
- اسکریپت‌ها Embedded در `Tarazin.Shared` → هر دو هاست مستقل از دیسک هستند
- در استارت‌آپ: `TarazinDbInitializer.EnsureInitializedAsync` → `_Ensure.sql` ها →
  `_Seed.sql` ها → bootstrap admin (اگر Users خالی است)
- `DbService.QueryAsync<T>(schema, name, @params)` / `ExecuteAsync` / `ScalarAsync`

## 🕵️ Audit
- **خودکار**: هر `DbService.ExecuteAsync(...)` یک ردیف ممیزی ثبت می‌کند
  (موفقیت یا خطا) — صفحات نیازی به فراخوانی دستی ندارند.
- ذخیره در `[central].[AuditLog]` با `PrevHash`/`RowHash` (SHA-256) — مشاهده در `/central/audit`
- پارامترها ذخیره نمی‌شوند؛ فقط schema/script/user/outcome/error.

## 📱 MAUI Blazor Hybrid (خلاصه)
- `Tarazin.Maui/MainPage.xaml`: `BlazorWebView` + `RootComponent` → `Tarazin.App` (مشترک)
- `wwwroot/index.html`: اسکریپت رانتایم `_framework/blazor.webview.js` (نه server.js)
- داده: همان `DbService`؛ توجه: `Microsoft.Data.SqlClient` روی **ویندوز/مک** کار می‌کند؛
  برای اندروید/iOS به یک لایهٔ دادهٔ دیگر (مثلاً وب‌سرویس) نیاز است — جزییات در
  `skills/blazor/blazor-maui-hybrid/SKILL.md`.

## ❌ Explicit Bans
- ❌ پروژه/پکیج جدید خارج از سه‌گانهٔ `Tarazin.Shared / Tarazin.Web / Tarazin.Maui`
- ❌ صفحهٔ جدید خارج از `Tarazin.Shared/Modules`
- ❌ `HttpClient` برای داده، controller، وب‌سرویس، توکن، رمزنگاری حمل‌ونقل
- ❌ Bootstrap دستی، CSS سفارشی زیاد، DataGrid سفارشی (همه MudBlazor)
- ❌ SQL خام در `.razor`
- ❌ پرسیدن دوبارهٔ ساختار از کاربر

## ✅ Workflow برای هر ماژول جدید
1. تحقیق گزارش‌های موردنیاز دامنه
2. طراحی مدل‌ها (`Tarazin.Shared/Models/{Module}Models.cs`)
3. نوشتن اسکریپت‌ها (`Tarazin.Shared/Data/Scripts/{schema}/…sql` + `_Ensure`/`_Seed`)
4. صفحات MudBlazor در `Tarazin.Shared/Modules/{Name}/Pages/` + افزودن به `NavMenu` و `Home`
5. اجرای `tools/cross-schema-scan.sh` — نتیجه به‌صورت خودکار در وب و MAUI می‌آید
