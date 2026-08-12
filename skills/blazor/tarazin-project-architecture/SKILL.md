---
name: tarazin-project-architecture
description: Master structure for ALL Tarazin work — single Blazor Server + MudBlazor.
category: blazor
tags: [architecture, tarazin, blazor-server, mudblazor, modules, dapper, tsql, schema]
version: 2.0.0
author: Ho3ein (Hermes Agent)
license: MIT
platforms: [windows]
metadata:
  tarazin:
    tags: [architecture, tarazin, blazor-server, mudblazor, modules, schemas, named-scripts, dapper]
    related_skills: [blazor-create-project, blazor-data-access, blazor-clean-architecture]
---

# 🏛 Tarazin Master Project Architecture (v2)

The canonical, permanent structure for ALL user projects. Read this first before
starting any new page, module, component, or service. Do not ask the user to
re-explain these rules.

## When to Use

- Starting ANY new page, component, or module for the user
- User mentions: project structure, module, schema, MudBlazor, report-first
- Before writing ANY code, check this skill to confirm the architecture rules

## ⚠️ Path Clarification

- `D:\tarazin\` = user's projects root on D drive
- The Tarazin platform lives in this repo at `TarazinApp/`
- **There is exactly ONE project** — `TarazinApp/TarazinApp.csproj`

## 📁 Directory Structure (FIXED)

```
Tarazin.slnx                          ← references ONLY TarazinApp
TarazinApp/                           ← THE project (Blazor Server, net10.0)
├── Program.cs                       ← AddServerSideBlazor + AddMudServices + startup ensure/seed
├── App.razor                        ← Router + MudThemeProvider / MudDialogProvider / MudSnackbarProvider
├── Pages/_Host.cshtml               ← RTL html shell
├── Layout/
│   ├── MainLayout.razor             ← MudLayout + MudDrawer + MudAppBar
│   └── NavMenu.razor                ← MudNavMenu with the 7 modules
├── Models/                          ← ALL models (Shared + one file per module)
├── Services/                        ← DbService, ScriptCatalog, AuthService, UserSession, AuditService
├── Modules/
│   ├── Home/Pages/                  ← / and /login
│   ├── Central/Pages/               ← پلتفرم مشترک
│   ├── Accounting/Pages/            ← حسابداری
│   ├── Inventory/Pages/             ← انبار آمل
│   ├── Treasury/Pages/              ← خزانه‌داری
│   ├── Payroll/Pages/               ← حقوق و دستمزد
│   ├── GoldShop/Pages/              ← طلافروشی
│   └── Store/Pages/                 ← فروشگاه
├── Data/Scripts/{schema}/           ← named TSQL per product schema (+ _Ensure/_Seed)
└── wwwroot/css/app.css              ← tiny MudBlazor overrides only
docker-compose.yml                   ← SQL Server only
tools/cross-schema-scan.sh           ← schema-boundary gate
```

## 🔑 Key Rules

1. **ONE Blazor Server project.** No webapi, no WASM clients, no `share` library,
   no NuGet service package, no per-product projects. New code goes inside
   `TarazinApp/` — always.
2. **No web-service involvement.** Data flows through `DbService` (Dapper +
   named TSQL scripts) in the same process. No HttpClient-for-data, no tokens,
   no handshake, no AES envelope, no CORS.
3. **MudBlazor only.** UI = MudTable, MudDatePicker, MudSelect, MudTextField,
   MudPaper, MudGrid, MudDialog, MudSnackbar, … No Bootstrap, no custom CSS
   framework, no hand-rolled DataGrid/PersianDatePicker.
4. **Every product = one module + one schema.** Module folder
   `Modules/{Name}/Pages/`; schema folder `Data/Scripts/{schema}/`.
5. **Named scripts only.** Pages never contain inline SQL.
6. **Reports-first.** Research the domain's reports before models/scripts/pages.
7. **Login in the same app.** `AuthService` + `UserSession`; bootstrap admin
   `admin`/`admin` on first run.

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
- Login exists in the SAME app (`/login`). After login, `UserSession` holds the
  identity for the whole circuit — no token passed via URL between apps.
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
- ❌ NO new projects / libraries / NuGet packages outside `TarazinApp`
- ❌ NO webapi / controllers / HttpClient-for-data / tokens / AES transport
- ❌ NO raw SQL in `.razor` files
- ❌ NO Bootstrap / custom CSS design — MudBlazor only
- ❌ NO asking the user to re-explain the structure

## ✅ Workflow Before Any Module
1. Research: what reports does this domain require?
2. Design models (`Models/{Module}Models.cs`) accordingly.
3. Write scripts (`Data/Scripts/{schema}/` + `_Ensure.sql`/`_Seed.sql`).
4. Build pages with MudBlazor in `Modules/{Name}/Pages/`.
5. Add to `Layout/NavMenu.razor` + `Modules/Home/Home.razor` launcher.
6. Run `tools/cross-schema-scan.sh`.

## 📚 Related Skills
- `blazor-create-project` — adding a new module/script/page
- `blazor-data-access` — DbService / named scripts / Dapper patterns
- `blazor-clean-architecture` — single-project layering
