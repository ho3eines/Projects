# 📘 Hermes — Master Blueprint (Single Blazor Server)

> **Last updated**: 2026-08-12 (v2.0 — بازطراحی کامل)
> **قانون طلایی**: یک پروژهٔ Blazor Server + MudBlazor؛ هر محصول یک ماژول و یک اسکیمه.

---

## 🧭 Overview

پلتفرم یکپارچهٔ سازمان با **هفت محصول** در **یک پروژهٔ Blazor Server** (`HermesApp`).
داده فقط از طریق **اسکریپت‌های TSQL نامدار** که در همان پروسه با Dapper اجرا
می‌شوند؛ **هیچ وب‌سرویس، هیچ کلاینت WASM، هیچ لایهٔ HTTP برای داده وجود ندارد**.
ظاهر کامل با **MudBlazor** (بدون CSS دستی).

> 📋 **PRD محصولات**: `PRD.md` · `PRD_All_Projects.md`
> 🗺️ **برنامهٔ کار**: `docs/PLATFORM_ROADMAP.md`
> 🧩 **تصمیم‌های معماری**: `docs/adr/` (ADR-001 تک‌پروژه · ADR-002 بدون رویداد · ADR-003 قراردادها)
> 🤖 **راهنمای عامل**: `.agents/hermes-tsql/SKILL.md`

---

## 🗂️ Directory Layout

```
Hermes.slnx                      ← فقط یک پروژه
HermesApp/                       ← THE پروژه (Blazor Server, net10.0)
├── Program.cs                   ← AddServerSideBlazor + AddMudServices + startup ensure/seed
├── App.razor                    ← Router + MudThemeProvider/Dialog/Snackbar
├── Pages/_Host.cshtml           ← قالب اصلی (RTL)
├── Layout/
│   ├── MainLayout.razor         ← MudLayout + MudDrawer + MudAppBar
│   └── NavMenu.razor            ← MudNavMenu (۷ ماژول)
├── Models/
│   ├── SharedModels.cs          ← قراردادهای مشترک (Party, ChartOfAccount, …)
│   ├── AccountingModels.cs      ← مدل‌های اختصاصی هر ماژول
│   ├── InventoryModels.cs
│   ├── TreasuryModels.cs
│   ├── PayrollModels.cs
│   ├── GoldShopModels.cs
│   ├── StoreModels.cs
│   └── CentralModels.cs
├── Services/
│   ├── ScriptCatalog.cs         ← بارگذاری Data/Scripts در استارت‌آپ
│   ├── DbService.cs             ← Query/Execute/Scalar با اسکریپت نامدار (Dapper)
│   ├── AuthService.cs           ← ورود از [central].[Users] (PBKDF2)
│   ├── UserSession.cs           ← نشست هر circuit
│   ├── AuditService.cs          ← ممیزی با زنجیرهٔ هش
│   └── PasswordHasher.cs
├── Modules/
│   ├── Home/Pages/              ← / (launcher) و /login
│   ├── Central/Pages/           ← /central, /central/news, /blog, /gallery, /users, /audit
│   ├── Accounting/Pages/        ← /accounting{,/dashboard,/entry,/reports,/special,/settings}
│   ├── Inventory/Pages/         ← /inventory…
│   ├── Treasury/Pages/          ← /treasury…
│   ├── Payroll/Pages/           ← /payroll…
│   ├── GoldShop/Pages/          ← /goldshop…
│   └── Store/Pages/             ← /store…
├── Data/Scripts/
│   ├── accounting/  *_Ensure.sql, *_Seed.sql, DailyDocuments.sql, …
│   ├── central/     UserAuthenticate.sql, AuditInsert.sql, NewsUpsert.sql, …
│   ├── inventory/   …
│   ├── treasury/    …
│   ├── payroll/     …
│   ├── goldshop/    …
│   └── store/       …
└── wwwroot/css/app.css          ← فقط tweakهای کوچک روی MudBlazor
docker-compose.yml               ← فقط SQL Server
ci/ci.yml                        ← build + cross-schema scan
tools/cross-schema-scan.sh       ← بررسی مرز اسکیمه‌ها
```

---

## 🔑 Key Rules

1. **فقط یک پروژه** — اضافه‌کردن پروژه/پکیج ممنوع؛ هر چیز جدید داخل `HermesApp`.
2. **فقط Blazor Server** — کال‌کردن داده = `DbService`؛ `HttpClient` برای داده ممنوع.
3. **MudBlazor** — صفحهٔ جدید فقط با کامپوننت‌های Mud؛ Bootstrap/جدول سفارشی ممنوع.
4. **اسکریپت نامدار** — صفحات SQL خام ندارند؛ همه چیز `Data/Scripts/{schema}/{Name}.sql`.
5. **مرز اسکیمه** — ماژول فقط `{schema}` خودش را صدا می‌زند؛ اسکریپت سرور می‌تواند
   با `-- Cross-schema:` خواندن بین‌اسکیمه‌ای مجاز انجام دهد (مثل مالیات طلا از حسابداری).
6. **Report-first** — قبل از کد: تحقیق گزارش‌های دامنه → مدل‌ها → اسکریپت‌ها → صفحات.

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
- نشست در `UserSession` (هر circuit) — بدون توکن، بدون URL parameter
- مدیریت کاربران در `/central/users`

## 🗄️ Data Layer
- یک ConnectionString: `ConnectionStrings:DefaultConnection` → `HermesMaster`
- در استارت‌آپ: `ScriptCatalog.Load` → `EnsureSchemaAsync` (همهٔ `_Ensure.sql`) →
  `SeedAsync` (همهٔ `_Seed.sql`) → ساخت bootstrap admin (اگر Users خالی است)
- `DbService.QueryAsync<T>(schema, name, @params)` / `ExecuteAsync` / `ScalarAsync`
- الگوی صفحات: inject `DbService` + `ISnackbar`؛ بارگذاری در `OnInitializedAsync`

## 🕵️ Audit
- `AuditService.RecordAsync(schema, script, params, user, isExec, outcome, error)`
- ذخیره در `[central].[AuditLog]` با `PrevHash`/`RowHash` (SHA-256) — مشاهده در `/central/audit`

## ❌ Explicit Bans
- ❌ پروژه/کلاس‌کتابخانه/پکیج جدید خارج از `HermesApp`
- ❌ `HttpClient`، controller، وب‌سرویس، توکن، رمزنگاری حمل‌ونقل
- ❌ Bootstrap دستی، CSS سفارشی زیاد، DataGrid سفارشی (همه MudBlazor)
- ❌ SQL خام در `.razor`
- ❌ پرسیدن دوبارهٔ ساختار از کاربر

## ✅ Workflow برای هر ماژول جدید
1. تحقیق گزارش‌های موردنیاز دامنه
2. طراحی مدل‌ها (`Models/{Module}Models.cs`)
3. نوشتن اسکریپت‌ها (`Data/Scripts/{schema}/…sql` + `_Ensure`/`_Seed`)
4. صفحات MudBlazor در `Modules/{Name}/Pages/` + افزودن به `NavMenu` و `Home`
5. اجرای `tools/cross-schema-scan.sh`
