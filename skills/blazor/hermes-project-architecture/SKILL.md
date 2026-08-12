---
name: hermes-project-architecture
description: Master structure for all Hermes projects.
category: blazor
tags: [architecture, hermes, projects, shared, webapi, widget, tsql, schema]
version: 1.0.0
author: Ho3ein (Hermes Agent)
license: MIT
platforms: [windows]
metadata:
  hermes:
    tags: [architecture, projects, shared, widgets, tsql, webapi, client]
    related_skills: [blazor-gridview, blazor-deploy-service, blazor-clean-architecture]
---

# 🏛 Hermes Master Project Architecture

The canonical, permanent structure for ALL user projects. Read this first before starting any new project, page, component, or service. Do not ask the user to re-explain these rules.

## When to Use

- Starting ANY new project, page, component, or service for the user
- User mentions: project structure, share, webapi, blazordeployservice, widgets, TSQL schema, reports-first
- Before writing ANY code, check this skill to confirm the architecture rules

## ⚠️ Path Clarification

- `D:\hermes\` = user's projects root on D drive (NOT `C:\Users\Ho3ein\AppData\Local\hermes\` which is the agent's own folder)
- `D:\hermes\projects\` = all project folders live here
- Each project folder = `D:\hermes\projects\[Project-Name]\`

## 📁 Directory Structure (FIXED)

```
d:\hermes\projects\
├── [Project-Name]/              ← Each product = ONE Blazor WASM Client only
│   ├── Client/                  ← Blazor WASM (UI only — no own API)
│   │   ├── Pages/
│   │   ├── Shared/
│   │   │   ├── Components/
│   │   │   └── Layouts/
│   │   └── wwwroot/
├── share/                       ← Shared library: models, components, services (used by ALL projects)
│   ├── Models/
│   ├── Components/
│   ├── Services/
│   └── Helpers/
├── webapi/                      ← ONE public API for ALL projects
│   ├── Controllers/
│   ├── Services/
│   ├── Data/
│   └── appsettings.json
├── blazordeployservice/         ← NuGet package source: general components (DataGridView etc.)
└── docs/
    └── PROJECT.md
```

## 🔑 Key Rules

1. **Each project = Client-only** (no per-project API). All data goes through the single shared `webapi`.
2. **webapi ↔ projects communicate via TSQL files** — each project has its OWN schema (tables) in the DB; webapi executes named TSQL files by request.
3. **share/** holds everything reusable: models, components, services, helpers.
4. **blazordeployservice/** = NuGet package with general components (DataGridView, etc.) copied/upgraded from the main project. All public features live here.
5. **Central Blazor WASM app** (مدیریت پروژه‌ها): a fully dynamic company site + widgets for the public website.

## 🧩 Every Project Has 4 Main Sections

### 1. ورود عملیات (Data Entry)
- Input operations for the project (e.g. in accounting: ثبت سند، مدیریت اسناد، ...)

### 2. عملیات ویژه (Special Operations)
- Required operations for the project (e.g. تغییر سال مالی)

### 3. گزارشات (Reports)
- ALL reports must be here. **Before building a project: research what reports that software should have, then design models based on the findings.**

### 4. امکانات (Features/Settings)
- **جداول پایه (Base Tables):** financial companies, کل (general) accounts, معین (subsidiary) accounts, تفصیلی (detail) accounts, etc.
- **امکانات عمومی (General Features):** shared across all software.

## 🏠 Main Page of Each Software
- **Document Search Box** with various filters (must have از تاریخ تا تاریخ — defaulted to today, user can change)
- **Grid of daily documents** — clicking a row navigates to that document.

## 📊 Dashboard
- A page showing ALL sections of the software in summary form.

## 🔐 Login & Token Flow
- Login exists in the MAIN app. After login, a **token is passed via parameter** to other project parts for navigation.
- Main app also has: **news, blog, gallery, user management** (user creation, permissions, etc.)

## 🧾 Shared Components in blazordeployservice
- DataGridView (main table), Modal, Toast, FileUpload, PersianDatePicker, Skeleton, PageHeader, etc.

## 🧩 Widgets (ویجت‌ها)
- Each project MUST expose a set of **widgets** for the company's main website.
- Widgets = small data-display blocks that show specific info from that project (e.g. accounting summary, latest sales, inventory count).
- The central client app renders these widgets on the company site.
- Widgets live in a `Widgets/` folder inside each project's Client.

## 🏢 Central Client App (کلاینت مرکزی)
- A central Blazor WASM app manages ALL projects.
- It is the company's fully dynamic website.
- Contains widgets that are displayable on the main company website.
- Has: **news, blog, gallery, user management** (user creation, permissions).
- Login exists here; token passed via parameter when navigating into project apps.

## 📈 Reports-First Design (طراحی گزارش‌محور)
- **Before writing any code** for a new project: research what reports that software category MUST have.
- Only after identifying reports → design the data models to support them.
- All reports live under the "گزارشات" section.

## ❌ Explicit Bans
- NO MudBlazor, NO Radzen — only HTML + Bootstrap 5.3 + CSS/JS.
- NO per-project APIs.
- NO asking the user to re-explain structure.

## ✅ Workflow Before Any Project
1. Research: what reports does this domain require?
2. Design models accordingly.
3. Build per this architecture (no per-project API).

## 🔐 Auth & Session Protocol (RequestService v2)
1. **Login flow**: client sends `projectGuid` + `loginToken` (AES-encrypted with project's EncryptionKey) → `POST /api/auth/login` → receives `SessionToken`.
2. **Session**: token valid while client keeps sending requests. **Timeout is in MINUTES (SessionTimeoutMinutes), default 10** — stored per-project in the `Projects` table, adjustable at runtime from webapi UI. If client sends no request longer than the timeout → token expires → login page shows again.
3. Every request must carry `X-Auth-Token`; API validates via SessionStore (in-memory, touched on each request).
4. Security headers client→server: `X-API-Key`, `X-Timestamp` (anti-replay, 30s window), `X-Signature` (HMAC-SHA256 over `timestamp|body`), `X-Project-Guid`, `X-Auth-Token`.
5. RequestService payload (client→server): **tsql + model (schema info) + projectguid + userid**. `userId` optional — only used for models/methods we define; if null it must still run, otherwise reject. Server auto-detects missing table/column from model schema info and creates the table/column with detected SQL types, then executes the TSQL.

## 🗄️ Per-Project Database Management (in webapi)
- Each project has its **OWN separate database** and its **OWN connection string**, stored in the `Projects` table (editable at runtime from webapi).
- `Projects` table fields: ProjectGuid, Name, Schema, LoginTokenHash, EncryptionKey, ApiKey, SessionTimeoutMinutes, IsActive, ConnectionString, DatabaseName, DatabaseProvider, AutoBackupEnabled, AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention, CreatedAtUtc, LastBackupAtUtc, Description, Icon.
- **Backup**: manual + automatic. Backups stored at `wwwroot/backup/{ProjectGuid}/`. Downloadable via URL, restorable (RESTORE DATABASE with SINGLE_USER).
- **Auto-backup**: configurable per project (interval minutes / daily time / retention count) — AutoBackupScheduler (IHostedService) checks every 1 minute.
- API endpoints: `GET/POST/PUT/DELETE /api/projects`, `POST /api/projects/{guid}/backup`, `GET /api/projects/{guid}/backups`, `GET /api/projects/{guid}/backups/{file}`, `POST /api/projects/{guid}/restore`, `PUT /api/projects/{guid}/backup-settings`.
- The whole webapi is **Blazor Server** so the admin UI (project settings management) lives there.

## 📊 Observability (RequestEvents)
- Every request is logged into `[audit].[RequestEvents]` table (auto-created): CorrelationId, ApiKey, ProjectGuid, UserId, Endpoint, StatusCode, DurationMs, CpuTimeMs, RamUsedMb, TimestampUtc, ErrorMessage.
- webapi admin UI can view/filter requests by project, status, error — for troubleshooting and optimization.

## 🔄 Auto-Rename & Auto-Commit (SqlService client-side)
- **Auto-rename**: `SqlService.InitializeAsync<T>()` stores the table name in localStorage key `PrevTable_{table}`. If the `[Table]` attribute name changes in code, it runs `EXEC sp_rename '{oldTable}', '{newTable}'` (only if old exists and new doesn't).
- **Auto-commit**: `AppSettings.AutoCommit.Days` (default 7, 0=disabled). After each successful Insert/Update, `MaybeAutoCommitAsync` checks localStorage `LastAutoCommit_{table}`; if older than Days → sends SQL to add `IsCommitted BIT` column (if missing) and mark rows committed.
- **ProjectController API tested working**: create project ✓, backup .bak ✓ (ничемing `{manual|auto}_{DatabaseName}_{yyyyMMdd_HHmmss}.bak`), list downloads ✓, restore (RESTORE DATABASE ... WITH REPLACE) ✓, download via `/api/projects/{guid}/backups/{file}` ✓.
- **SQL Server BACKUP pitfall**: use `$"BACKUP DATABASE [{db}] ..."` interpolation (Dapper can't bind object names as `{db}` → error 911). No `STATS = 0` (invalid range error).

## 🖥️ webapi Blazor Server UI (Components/Pages)
- `Projects.razor` at `/projects` — full management UI: list, create/edit modal, manual backup, backup list + download/restore, delete (double-click confirm).
- Uses `HttpClient` (registered in Program.cs) with `X-Api-Key` header from `AdminApiKey` config.
- Program.cs middleware order: `UseStaticFiles(backup)` → `UseAuthentication` → `UseAuthorization` → `UseRouting` → `UseAntiforgery` → `MapControllers` → `MapRazorComponents`.