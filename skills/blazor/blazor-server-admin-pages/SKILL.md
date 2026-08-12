---
name: blazor-server-admin-pages
description: Use when building webapi Blazor Server admin pages.
category: blazor
author: Hermes Agent
license: MIT
version: 1.0.0
tags: [blazor, server, webapi, razor, dapper, admin-ui]
metadata:
  hermes:
    tags: [blazor, server, webapi, razor, dapper, admin-ui]
    related_skills: [hermes-project-architecture, blazor-deploy-service-usage]
---

# 🖥️ Blazor Server Admin Pages (Hermes webapi)

## When to Use

- Creating or editing Razor pages inside the Hermes `webapi` Blazor Server app (admin UI: project management, connection info, create-project form).
- User says "پروژه چون درون webapi هست احتیاج به کنترلر نداره" (pages inside webapi talk to SQL directly).
- Adding pages to the navbar (MainLayout.razor) with routes like `/connection`, `/create-project`, `/projects`.

See `references/webapi-pages-session.md` for the full session detail (working patterns, error transcripts, curl tests). See `references/datagrid-integration-and-responsive.md` for the DataGrid data-flow + responsive mobile CSS + seeded-DB pitfall.

## 🔑 Core Rule (user-mandated, do not re-ask)

Pages inside webapi run in the **same process as the database**. Do NOT call your own `/api/...` endpoints from these pages — **no HttpClient, no controller round-trip, no X-Api-Key dance** for internal admin pages. Talk to SQL directly.

```csharp
@inject IConfiguration Config
@using Dapper
@using Microsoft.Data.SqlClient

// in @code handler:
await using var conn = new SqlConnection(Config.GetConnectionString("DefaultConnection"));
await conn.OpenAsync();
await conn.ExecuteAsync("INSERT INTO [dbo].[Projects] (...) VALUES (...)", model);
```

- Headless service alternative: `ISystemQueryExecutor` (registered singleton in Program.cs)
  `QueryAsync(scriptName, parameters, schema)` / `ExecuteAsync(...)` / `ScalarAsync(...)`.

## 📄 Standard admin pages (Hermes webapi)

| Route | Page | Purpose |
|-------|------|---------|
| `/projects` | Projects.razor | **Single list page** (connection info + management merged): name, Guid, ApiKey (masked), Timeout, Auto‑Backup status, IsActive. Uses `<DataGrid>`. |
| `/create-project` | CreateProject.razor | Create project (DB ensure + INSERT) |

**Merged (user-mandated):** the old `/connection` page was DELETED — user said "نمیخوام جدا باشند باید یکی باشند" (connection info and project list must be ONE page). Do NOT re-create a separate connection page.

Navbar (MainLayout.razor): `🏠 خانه` → `/`, `📋 لیست پروژه‌ها` → `/projects`, `➕ پروژه جدید` → `/create-project`.

## 📋 Form fields for `/create-project`
- ProjectGuid (auto‑generated UUID)
- Name, Schema (default `dbo`), LoginTokenHash, EncryptionKey, ApiKey
- SessionTimeoutMinutes (default 10)
- ConnectionString (per‑project DB), DatabaseName, DatabaseProvider
- AutoBackupEnabled, AutoBackupIntervalMinutes, AutoBackupTimeUtc, MaxBackupRetention
- Description (optional)

## 🧪 Session verification
- `dotnet build`: **Build succeeded**
- `GET /projects`: 200, project list via DataGrid (masked ApiKey, Guid, Timeout, Auto‑Backup status, IsActive)
- `POST /create-project` form: row inserted in `[dbo].[Projects]`, DB auto‑created if missing

See `references/webapi-admin-pages-session.md` for the full transcript.

## 🧨 Razor Page Pitfalls (hard-won)

1. **Inline `@onclick` lambdas with quoted strings break the Razor compiler** (CS7036 "no argument given", CS1026 "unexpected character"). Never `@onclick="() => Copy("text")"`. Use named handlers:
   ```razor
   <button @onclick="() => CopyApiKey(p)">📋</button>
   ```
   ```csharp
   private async Task CopyApiKey(ProjectDefinitionDto p) { try { await JS.InvokeVoidAsync("navigator.clipboard.writeText", p.ApiKey); } catch { } }
   ```
2. **Blazor Server `HttpClient` injection throws** `Cannot provide a value for property 'Http'` if unregistered — but direct SQL injection (above) avoids needing it altogether.
3. **Program.cs middleware order matters**: `UseStaticFiles(backup)` → `UseAuthentication` → `UseAuthorization` → `UseRouting` → `UseAntiforgery` → `MapControllers` → `MapRazorComponents`. Wrong order ⇒ "endpoint contains anti-forgery metadata, but a middleware was not found".
4. **Ternary inside a class attribute** (`class="badge @(p.IsActive ? "bg-success" : "bg-secondary")"`) can break parsing — use a computed property `GetStatusClass(p)` instead.
5. **`IJSRuntime`** needs `@using Microsoft.JSInterop`; `navigator.clipboard.writeText` throws in non-secure contexts — always try/catch.
6. **Backup endpoints inside webapi**: use `$"BACKUP DATABASE [{db}] TO DISK = @path..."` string interpolation (Dapper can't bind object names — error 911); never `STATS = 0` (invalid range).
7. **Seeding Persian project names**: `sqlcmd` mangles UTF-8 Persian (names become `����` garbage), and PowerShell's encoding is unreliable too. Seed via the project's own `POST /api/projects` API with UTF-8 JSON (Python/urllib worked) — names round-trip correctly and you get proper `NEWID()` UUIDs.

## 🗂️ DataGrid instead of raw `<table>` (user-mandated)

**NEVER hand-write `<table>` markup for project lists in the admin UI. Use the `DataGrid` component** (from `blazor-gridview` skill; copied into the project at `Components/Grid/DataGrid.razor` + `Models/DataGridColumn.cs` + `Components/Grid/DataGridPagination.razor`). User: "میخوام همیشه استفاده کنی ، هیچوقت از table استفاده نکن".

### Setup when adding to a project
1. Copy `DataGrid.razor`, `DataGridPagination.razor` → `Components/Grid/`, `DataGridColumn.cs` → `Models/`.
2. `_Imports.razor` needs both:
   ```razor
   @using WebApi.Grid           // for DataGridColumn<T>, GridState, GridResult<T>, EditableEntity
   @using WebApi.Components.Grid // for <DataGrid> component itself
   ```
3. `DataGrid.razor` needs `@inject IJSRuntime JSRuntime` (NOT a `[Parameter]` — null otherwise and export/print buttons crash).
4. `data-label` attribute is set on each `<td>` via `data-label="@col.Caption"` for responsive mobile stacking.

### Column definitions (v1.1 syntax — columns in code, NOT as `<Column>` children)
```csharp
private List<DataGridColumn<ProjectRow>> _columns = new()
{
    new() { PropertyName = nameof(ProjectRow.Name), Caption = "نام", Sortable = true },
    new() { PropertyName = nameof(ProjectRow.ProjectGuid), Caption = "ProjectGuid", Sortable = false },
    new() { PropertyName = nameof(ProjectRow.ApiKey), Caption = "ApiKey",
            Formatter = p => MaskApiKey(p!.ApiKey) },
    new() { PropertyName = nameof(ProjectRow.SessionTimeoutMinutes), Caption = "Timeout (دقیقه)",
            Sortable = true, Width = 120 },
    new() { PropertyName = nameof(ProjectRow.AutoBackupEnabled), Caption = "بکاپ خودکار",
            Formatter = p => p!.AutoBackupEnabled ? "✅" : "❌" },
    new() { PropertyName = nameof(ProjectRow.IsActive), Caption = "وضعیت",
            Formatter = p => p!.IsActive ? "فعال" : "غیرفعال" },
};
```

### Usage in a page (with loading state + non-null Items)
```razor
@code {
    private List<ProjectRow>? _projects;
    private bool _isLoading = true;
    // ... _columns defined above

    protected override async Task OnInitializedAsync()
    {
        // ... load _projects
        _isLoading = false;
        StateHasChanged();
    }
}
```
```razor
@if (_isLoading)
{
    <DataGrid TModel="ProjectRow" Items="new List<ProjectRow>()"
              Columns="_columns" PageSize="10" AllowSelect="false"
              AllowFiltering="true" IsLoading="true">
        <HeaderTemplate><button @onclick="ShowCreate">➕</button></HeaderTemplate>
    </DataGrid>
}
else
{
    <DataGrid TModel="ProjectRow" Items="_projects"
              Columns="_columns" PageSize="10" AllowSelect="false"
              AllowFiltering="true" IsLoading="false">
        <HeaderTemplate><button @onclick="ShowCreate">➕</button></HeaderTemplate>
    </DataGrid>
}
```

### Critical pitfalls (all learned this session)
1. **Empty grid after prerender:** `Items` arrives after `OnInitializedAsync` → DataGrid shows nothing. Fix: load data in `OnParametersSetAsync` in DataGrid OR use `ItemsProvider` callback.
2. **`IJSRuntime` must be `@inject`-ed, NOT `[Parameter]`** — `[Parameter]` defaults to null when not passed by parent → CSV/Excel/Print buttons throw NRE.
3. **`<Column>` children cause `RZ9996` build errors** — DataGrid does NOT support child content for columns. Use `Columns` parameter (list of `DataGridColumn<TModel>` in @code).
4. **`ShowExportButtons` is not settable** — read-only computed property causes `BL0001`. Use `ExportButtons` param directly.
5. **`EmptyTemplate` renamed to `EmptyState`** (string?) — `EmptyTemplate` was never a valid parameter.
6. **`@RowActions(item)` fails** — use `@RowActions.First()(item)` with `RowActions.Any()` check.
7. **`RowActions` with inline lambdas break Razor parsing** (`CS0236` field initializer cannot reference instance method; `this` not available). **Use `OnEditItem` + `OnDeleteItem` EventCallbacks instead** — they receive `EventCallback<TModel>` and fire safely from the grid. In DataGrid.razor:
   ```razor
   @if (OnEditItem.HasDelegate)
   { <button @onclick="() => OnEditItem.InvokeAsync(item)">✏️</button> }
   ```
   In page: `<DataGrid OnEditItem="ShowEdit" OnDeleteItem="DeleteProject" />`
8. **`bind-Value` vs `bind-value` casing**: Blazor input bindings are **case-sensitive** — use `@bind-value` (lowercase) not `@bind-Value`. `@bind-Value` triggers `RZ9991` "attribute names could not be inferred". This applies to `<InputText>`, `<InputNumber>`, and plain `<input @bind="...">`.
9. **Modal from `blazordeployservice`**: The project contains a complete, reusable modal system:
   - `Components/Modal/ModalContainer.razor` — renders active modals via `DynamicComponent`
   - `Models/ModalModel.cs` — modal state (Id, ComponentType, Title, Parameters, ModalSize)
   - `Services/ModalService.cs` — `IModalService` with `Show<TComponent>(title, parameters)`, `Close()`, `CloseAll()`; injects custom CSS/JS via JSRuntime for backdrop blur, scale animation, RTL close button
   - Register: `builder.Services.AddScoped<IModalService, ModalService>();`
   - Place `<ModalContainer />` in `MainLayout.razor` (inside layout body, not inside page)
   - In page: `@inject IModalService ModalService` → `_ = ModalService.Show<EditProjectModal>("عنوان", new() { ["Project"] = project });`
   - **Key**: ModalService uses `TaskCompletionSource` so `Show` returns `Task<object?>` for awaiting result. JSRuntime events for backdrop click / close button are wired via `JSInvokable` methods.

## 📦 Local Bootstrap RTL (v5.3.3) — mandatory for this project
- Download `bootstrap.rtl.min.css` and `bootstrap.bundle.min.js` into `wwwroot/lib/bootstrap/`.
- In `App.razor` `<head>` add `<link rel="stylesheet" href="lib/bootstrap/css/bootstrap.rtl.min.css" />`.
- Before `</body>` add `<script src="lib/bootstrap/js/bootstrap.bundle.min.js"></script>`.
- Ensure `dir="rtl"` on `<html>` (or `<body>`) so Bootstrap RTL works.
- Add custom `site.css` under `wwwroot/css/` and reference it in `<head>`.

## 🖥️ App.razor HTML Shell (Blazor Web App .NET 8+)
**Blank pages / non-working buttons = missing `<Routes @rendermode="RenderMode.InteractiveServer" />`.** The `.NET 8+ Blazor Web App` template requires the HTML shell in `App.razor` with `<Routes @rendermode="RenderMode.InteractiveServer" />` (NOT a raw `<Router>` — that renders SSR-only and edit forms/buttons never work).

```razor
<!DOCTYPE html>
<html lang="fa" dir="rtl" data-bs-theme="light">
<head>
    <meta charset="utf-8" />
    <meta name="viewport" content="width=device-width, initial-scale=1.0" />
    <base href="/" />
    <title>🏢 Hermes WebAPI</title>
    <link rel="stylesheet" href="lib/bootstrap/css/bootstrap.rtl.min.css" />
    <link rel="stylesheet" href="css/site.css" />
    <HeadOutlet />
</head>
<body>
    <Routes @rendermode="RenderMode.InteractiveServer" />
    <script src="lib/bootstrap/js/bootstrap.bundle.min.js"></script>
    <script src="_framework/blazor.web.js"></script>
</body>
</html>
```

## ⚙️ Middleware & Static Files Fix (Program.cs) — critical order
```csharp
app.UseHttpsRedirection();
app.UseCors("AllowAll");

// Static files for wwwroot (css, js, lib) — MUST be before backup-specific middleware
app.UseStaticFiles();

// Backup static files under /backup
var backupRoot = Path.Combine(app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot"), "backup");
Directory.CreateDirectory(backupRoot);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(backupRoot),
    RequestPath = "/backup"
});

app.UseAuthentication();
app.UseAuthorization();
app.UseRouting();
app.UseAntiforgery();

app.MapControllers();
app.MapRazorComponents<App>().AddInteractiveServerRenderMode();
```

**Key point:** `UseStaticFiles()` must be called **before** the backup-specific `UseStaticFiles` so that `wwwroot/lib/bootstrap` and `wwwroot/css` are served. The backup middleware alone cannot serve general assets.

## 🧪 Verification

- `dotnet build` passes clean.
- `/projects` returns 200 (antiforgery middleware present) and DataGrid renders rows (count `<tr` in prerendered HTML).
- Creating a project inserts a row in `[dbo].[Projects]` (verify via SQL query).