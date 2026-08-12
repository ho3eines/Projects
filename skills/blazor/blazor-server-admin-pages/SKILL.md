---
name: blazor-server-admin-pages
description: Build admin/management pages inside the single Hermes Blazor Server app.
category: blazor
author: Hermes Agent
license: MIT
version: 2.0.0
tags: [blazor, server, admin-ui, mudblazor, razor, dapper]
metadata:
  hermes:
    tags: [blazor, server, admin-ui, mudblazor, razor, dapper]
    related_skills: [hermes-project-architecture, blazor-data-access]
---

# 🖥️ Blazor Server Admin Pages (Hermes v2)

## When to Use

- Creating or editing Razor pages in the single Hermes Blazor Server app
  (platform admin: users, news/blog/gallery, audit, base tables per module).
- User says "صفحات داخل خود پروژه‌ی Blazor Server هستند و احتیاج به کنترلر/وب‌سرویس ندارند".
- Adding pages to the nav (`Layout/NavMenu.razor`) with routes like `/central/users`.

## 🔑 Core Rule (user-mandated, do not re-ask)

Admin pages run **in the same process as the database**. Do NOT call any
`/api/...` endpoint, do NOT use `HttpClient`, do NOT implement controllers.
Talk to SQL via `DbService` + named scripts directly:

```csharp
@inject DbService Db
@inject UserSession Session

// in a handler:
await Db.ExecuteAsync("central", "UserUpsert", new
{
    UserId = 0,
    Username = username,
    PasswordHash = PasswordHasher.Hash(password),
    DisplayName = displayName,
    Role = role,
    IsActive = true,
    CreatedBy = Session.UserName
});
```

## 📄 Standard admin pages (Hermes v2)

| Route | Page | Purpose |
|-------|------|---------|
| `/central/users` | CentralUsers.razor | مدیریت کاربران (create + role) |
| `/central/news` | CentralNews.razor | اخبار |
| `/central/blog` | CentralBlog.razor | وبلاگ |
| `/central/gallery` | CentralGallery.razor | گالری |
| `/central/audit` | CentralAudit.razor | ممیزی (hash-chain) |
| `/{module}/settings` | {Module}Settings.razor | جداول پایهٔ هر ماژول |

## 🎨 Admin page conventions (MudBlazor)

- Form area: `MudPaper Elevation="1" Class="pa-4 mb-4"` with a `MudGrid` of
  `MudTextField` / `MudSelect` / `MudDatePicker`.
- List area: `MudTable Items="..." Loading="..." Hover Dense Striped` with
  `MudTh`/`MudTd` + `DataLabel` (responsive), `EmptyContent` message.
- Feedback: `ISnackbar` (`Severity.Success` / `Severity.Error` / `Severity.Warning`).
- Busy state: `bool _busy` guard + `Disabled="_busy"` on buttons.

## 🧨 Razor Pitfalls (hard-won)

1. **Two-way binding inside MudTable RowTemplate**: use
   `Value="context.X"` + `ValueChanged="v => context.X = v"` on
   `MudTextField`/`MudNumericField` (or bind an index when the row needs it).
2. **`MudSelect` values**: `Value="0"` literal and `Value="a.AccountId"`
   expressions work; for nullable selections pass `(int?)null` in the model,
   not in the component.
3. **RTL/Persian dates**: pass `Culture="CultureInfo.GetCultureInfo("fa-IR")"`
   to `MudDatePicker`.
4. **Avoid `MudTable` FooterContent for totals** unless the MudBlazor version
   supports `MudTFoot`/`colspan` — show totals as `MudText` below the table
   instead (portable across versions).
5. **Never `HttpClient` injection** — `DbService` is the only data path;
   unregistered `HttpClient` throws at runtime.

## 🧪 Session verification
- `dotnet build Hermes.slnx` — one project, build succeeded
- Open `/central/users` → list + create works
- Open `/{module}/settings` → base table CRUD works
