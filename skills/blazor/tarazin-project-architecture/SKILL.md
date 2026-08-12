---
name: tarazin-project-architecture
description: Master structure for ALL Tarazin work — shared core (RCL) + web (Blazor Server) + MAUI (Blazor Hybrid), MudBlazor.
category: blazor
tags: [architecture, tarazin, blazor-hybrid, blazor-server, maui, mudblazor, modules, dapper, tsql, schema]
version: 3.0.0
author: Ho3ein (Hermes Agent)
license: MIT
platforms: [windows, android, ios, maccatalyst]
metadata:
  tarazin:
    tags: [architecture, tarazin, blazor-hybrid, blazor-server, maui, mudblazor, modules, schemas, named-scripts, dapper]
    related_skills: [blazor-create-project, blazor-data-access, blazor-clean-architecture, blazor-maui-hybrid]
---

# 🏛 Tarazin Master Project Architecture (v3 — Blazor Hybrid)

The canonical, permanent structure for ALL user projects. Read this first before
starting any new page, module, component, or service. Do not ask the user to
re-explain these rules.

## When to Use

- Starting ANY new page, component, or module for the user
- User mentions: project structure, module, schema, MudBlazor, MAUI, Blazor Hybrid, report-first
- Before writing ANY code, check this skill to confirm the architecture rules

## ⚠️ Path Clarification

- `D:\tarazin\` = user's projects root on D drive
- The Tarazin platform = **three projects**: `Tarazin.Shared/` (RCL — ALL UI +
  data layer), `Tarazin.Web/` (web host, Blazor Server), `Tarazin.Maui/` (MAUI
  Blazor Hybrid host). See `skills/blazor/blazor-maui-hybrid/SKILL.md`.

## 📁 Directory Structure (FIXED)

```
Tarazin.slnx                          ← ۳ پروژه: Shared + Web + Maui
Tarazin.Shared/                       ← THE core (Razor Class Library, RootNamespace: Tarazin)
├── Tarazin.Shared.csproj            ← MudBlazor + Dapper + SqlClient؛ اسکریپت‌ها Embedded
├── App.razor                        ← Router + MudThemeProvider/Dialog/Snackbar + init (مشترک)
├── _Imports.razor                   ← usingهای مشترک
├── Layout/                          ← MainLayout (MudLayout) + NavMenu (۷ ماژول)
├── Models/                          ← ALL models (Shared + one file per module)
├── Services/                        ← DbService, ScriptCatalog, AuthService, UserSession,
│                                     AuditService, PasswordHasher, ServiceCollectionExtensions,
│                                     TarazinDbInitializer
├── Modules/
│   ├── Home/Pages/                  ← / and /login
│   ├── Central/Pages/               ← پلتفرم مشترک
│   ├── Accounting/Pages/            ← حسابداری
│   ├── Inventory/Pages/             ← انبار آمل
│   ├── Treasury/Pages/              ← خزانه‌داری
│   ├── Payroll/Pages/               ← حقوق و دستمزد
│   ├── GoldShop/Pages/              ← طلافروشی
│   └── Store/Pages/                 ← فروشگاه
├── Data/Scripts/{schema}/           ← named TSQL per product schema (EmbeddedResource)
└── wwwroot/css/app.css              ← tiny MudBlazor overrides (استاتیک RCL)
Tarazin.Web/                          ← هاست وب (Blazor Server — فقط پوسته)
├── Tarazin.Web.csproj              ← ref → Tarazin.Shared
├── Program.cs                       ← AddServerSideBlazor + AddMudServices + AddTarazinSharedServices
├── Pages/_Host.cshtml               ← RTL html shell (App از Tarazin.Shared)
└── appsettings.json
Tarazin.Maui/                         ← هاست MAUI Blazor Hybrid (فقط پوسته)
├── Tarazin.Maui.csproj             ← ref → Tarazin.Shared؛ TFM های android/ios/maccatalyst/windows
├── MauiProgram.cs                   ← AddMauiBlazorWebView + AddMudServices + AddTarazinSharedServices
├── MainPage.xaml                    ← BlazorWebView → RootComponent {x:Type tarazin:App}
├── wwwroot/index.html               ← blazor.webview.js + _content/Tarazin.Shared/css/app.css
├── appsettings.json                 ← Embedded
├── Resources/                       ← AppIcon, Splash, Styles
└── Platforms/                       ← Android / iOS / MacCatalyst / Windows
docker-compose.yml                   ← SQL Server only
ci/ci.yml                            ← build وب (ubuntu) + build MAUI (windows + workload maui)
tools/cross-schema-scan.sh           ← schema-boundary gate (Tarazin.Shared/Data/Scripts)
```

## 🔑 Key Rules

1. **UI فقط در `Tarazin.Shared`.** No webapi, no WASM clients, no `share`
   library, no NuGet service package, no per-product projects. New code goes
   inside `Tarazin.Shared/` — always. Hosts (`Tarazin.Web`, `Tarazin.Maui`)
   are thin shells; they only register services and render `Tarazin.App`.
2. **No web-service involvement.** Data flows through `DbService` (Dapper +
   named TSQL scripts) in the same process. No HttpClient-for-data, no tokens,
   no handshake, no AES envelope, no CORS.
3. **MudBlazor only.** UI = MudTable, MudDatePicker, MudSelect, MudTextField,
   MudPaper, MudGrid, MudDialog, MudSnackbar, … No Bootstrap, no custom CSS
   framework, no hand-rolled DataGrid/PersianDatePicker.
4. **Every product = one module + one schema.** Module folder
   `Tarazin.Shared/Modules/{Name}/Pages/`; schema folder
   `Tarazin.Shared/Data/Scripts/{schema}/`.
5. **Named scripts only (embedded).** Pages never contain inline SQL;
   `ScriptCatalog` self-loads scripts from embedded resources in `Tarazin.Shared`.
6. **Reports-first.** Research the domain's reports before models/scripts/pages.
7. **Login in the app.** `AuthService` + `UserSession`; bootstrap admin
   `admin`/`admin` on first run (shared `TarazinDbInitializer`).

## 🧩 Every Module Has 4 Main Sections

### 1. ورود عملیات (Data Entry) — `/entry`
Input operations for the module (e.g. حسابداری: ثبت سند).

### 2. عملیات ویژه (Special Operations) — `/special`
Required operations (e.g. بستن دوره، انبارگردانی، نهایی‌کردن حقوق).

### 3. گزارشات (Reports) — `/reports`
ALL reports live here. **Before building a module: research what reports that
software should have, then design models based on the findings.**

### 4. امکانات (Features/Settings) — `/settings`
**جداول پایه (Base Tables):** حساب‌ها، کالاها، انبارها، کارمندان، …
**امکانات عمومی (General Features):** shared across all modules.

## 🏠 Main Page of Each Module
- **Document Search Box** with various filters (must have از تاریخ تا تاریخ —
  defaulted to today, user can change)
- **Grid of daily documents** (MudTable) — clicking a row opens that document.

## 📊 Dashboard
- A page showing ALL sections of the module in summary form (MudPaper stat cards).

## 🔐 Login & Session
- Login exists in the same UI (`/login`). After login, `UserSession` holds the
  identity — web: per SignalR circuit; MAUI: per app (scoped ≈ singleton).
- No token passed via URL between apps.
- Platform common features: news, blog, gallery, user management — inside
  `Modules/Central/`.

## 🗄️ Data Access (replaces the old webapi)

```csharp
@inject DbService Db

var rows = (await Db.QueryAsync<DailyDocumentRow>("accounting", "DailyDocuments",
    new { FromDate, ToDate, SearchText, DocumentType = (string?)null, SkipRows = 0, TakeSize = 100 })).ToList();

await Db.ExecuteAsync("accounting", "DocumentInsert", new { LinesJson, ... });
```

- `ScriptCatalog` loads all scripts at startup; `DbService` executes them with
  Dapper; the schema string is the scope guard.
- Server-side scripts may cross schemas only with a `-- Cross-schema:` header
  (checked by `tools/cross-schema-scan.sh`).

## 📈 Reports-First Design (طراحی گزارش‌محور)
- **Before writing any code** for a new module: research what reports that
  software category MUST have.
- Only after identifying reports → design the data models to support them.
- All reports live under the "گزارشات" section.

## ❌ Explicit Bans
- ❌ NO new projects / libraries / NuGet packages outside `Tarazin`
- ❌ NO webapi / controllers / HttpClient-for-data / tokens / AES transport
- ❌ NO raw SQL in `.razor` files
- ❌ NO Bootstrap / custom CSS design — MudBlazor only
- ❌ NO asking the user to re-explain the structure

## ✅ Workflow Before Any Module
1. Research: what reports does this domain require?
2. Design models (`Tarazin.Shared/Models/{Module}Models.cs`) accordingly.
3. Write scripts (`Tarazin.Shared/Data/Scripts/{schema}/` + `_Ensure.sql`/`_Seed.sql`).
4. Build pages with MudBlazor in `Tarazin.Shared/Modules/{Name}/Pages/`.
5. Add to `Layout/NavMenu.razor` + `Modules/Home/Home.razor` launcher.
6. Run `tools/cross-schema-scan.sh`.
7. Result automatically appears in BOTH hosts (web + MAUI) — nothing else to do.

## 📚 Related Skills
- `blazor-create-project` — adding a new module/script/page
- `blazor-data-access` — DbService / named scripts / Dapper patterns
- `blazor-maui-hybrid` — the MAUI Blazor Hybrid host (Windows/Android/iOS/macOS)
- `blazor-clean-architecture` — shared-core layering
