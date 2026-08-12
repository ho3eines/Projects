---
name: blazor-deploy-service-usage
description: Use when integrating BlazorDeployService NuGet package.
category: blazor
tags: [blazor, nuget, deploy, usage, wasm]
version: 1.0.0
---

# 🚀 Using BlazorDeployService (NuGet) – Quick Integration Guide

## 📥 Install
```powershell
Install-Package BlazorDeployService
```
or via CLI:
```bash
dotnet add package BlazorDeployService
```

## 📁 Setup

### 1. `Program.cs` (Client WASM)
```csharp
using BlazorDeployService.Extensions;
using BlazorDeployService.Services;

var builder = WebAssemblyHostBuilder.CreateDefault(args);

// ثبت تمام سرویسها با یک خط
builder.Services.AddBlazorDeployServices(builder.Configuration);

await builder.Build().RunAsync();
```

### 2. `appsettings.json`
```json
{
  "BlazorDeploy": {
    "ApiSettings": {
      "BaseUrl": "https://api.blazordeploy.ir/api/",
      "AppToken": "XXXXXXX",
      "ApiKey": null,
      "publickey": "XXXXXX",
      "privatekey": "XXXXXX",
      "Timeout": 30000
    },
    "Encryption": {
      "Enabled": true,
      "Key": "XXXX"
    },
    "Localization": {
      "SupportedLanguageCodes": [ "fa-IR", "en-US", "ar-SA" ],
      "DefaultLanguage": "fa-IR",
      "EnableAutoDetection": true
    },
    "Deployment": {
      "MaxRetries": 3,
      "RetryDelay": 1000
    }
  }
}
```

### 3. `MainLayout.razor`
```razor
@inject CultureService cultureService
@inject LocalizationCacheService _cache
@inject ThemeService Theme
@inject IModalService ModalService

<ThemeSelector />
<LanguageSelector />
<Modal />

@code {
    protected override async Task OnInitializedAsync()
    {
        _cache.OnChange += StateHasChanged; // All pages
        Theme.OnThemeChanged += OnThemeChanged;
        Theme.OnDarkModeChanged += OnDarkModeChanged;
        cultureService.OnCultureChanged += StateHasChanged;

        await cultureService.InitializeAsync();
        await cultureService.ApplyDirectionAsync();
        await Theme.InitializeAsync();
        await _cache.InitializeAsync();
        await ModalService.InitializeAsync();
    }
}
```

---

## 🔥 Daily Usage Patterns

### SQL Request (query)
```csharp
@inject IRequestService _req
@inject IAlertService AlertService

var users = await _req.Request<User>("SELECT * FROM Users WHERE Active=@active", new { active = 1 });
```

### SQL Request (execute/INSERT/UPDATE)
```csharp
await _req.Request<bool>(
    "INSERT INTO Users(Name) VALUES(@Name)",
    new { Name = "Ali" },
    isExec: true
);
```

### SQL with connection-string token
```csharp
var x = await _req.Request<MyModel>(
    "SELECT * FROM MyTable",
    null,
    false,
    "ConnectionToken123"
);
```

### Modal
```csharp
@inject IModalService ModalService

<button class="btn btn-primary" @onclick="OpenUserModal">Open</button>

@code {
    private async Task OpenUserModal()
    {
        var parameters = new Dictionary<string, object>
        {
            { "UserName", "Test User" },
            { "UserEmail", "test@example.com" }
        };
        var result = await ModalService.Show<UserForm>("User Form", parameters);
        if (result != null)
        {
            _userData = result;
            StateHasChanged();
        }
    }
}
```

### Alerts
```csharp
@inject IAlertService AlertService

await AlertService.ShowSuccessAsync("Saved", "Changes saved");
await AlertService.ShowErrorAsync("Error", "Something went wrong");
await AlertService.ShowWarningAsync("Warning", "Please check");
await AlertService.ShowInfoAsync("Info", "New update available");
```

### Localization
```csharp
@inject LocalizationCacheService _cache

<PageTitle>@_cache.GetValue("Home")</PageTitle>
<p>@_cache.GetValue("Hello")</p>
```

### Secure Storage
```csharp
@inject IClientStorageService storage

// Plain
await storage.SetLocalAsync("token", "abc");
var token = await storage.GetLocalAsync<string>("token");

// Encrypted
await storage.SetLocalEncryptedAsync("secret", "password123", "myKey");
var decrypted = await storage.GetLocalEncryptedAsync<string>("secret", "myKey");

// Session
await storage.SetSessionAsync("session", "abc123");
var data = await storage.GetSessionAsync<string>("session");
```

### Theme
```csharp
@inject IThemeService Theme

<button class="btn" @onclick="ToggleTheme">🌙</button>
<div class="btn-group">
    @foreach (var t in Theme.GetAvailableThemes())
    {
        <button class="btn" @onclick="() => Theme.SetThemeAsync(t)">@t</button>
    }
</div>

@code {
    private async Task ToggleTheme() => await Theme.ToggleDarkAsync();
}
```

### Culture / RTL
```csharp
@inject ICultureService _cult

<select @onchange="OnLangChanged">
    <option value="fa-IR">فارسی</option>
    <option value="en-US">English</option>
    <option value="ar-SA">العربية</option>
</select>

@code {
    private async Task OnLangChanged(ChangeEventArgs e)
    {
        await _cult.SetCulture(e.Value?.ToString() ?? "fa-IR");
    }
}
```

---

## 🧩 Using Attribute-Driven CRUD (SqlService)

```csharp
@inject ISqlService _sql

// 1. Define model:
[Table("Categories", TableVersion = 1)]
public class Category
{
    [PrimaryKey, Identity]
    public int Id { get; set; }

    [Required, MaxLength(50)]
    public string Title { get; set; } = "";

    public string? Description { get; set; }
}

// 2. In component/page:
await _sql.InitializeAsync<Category>();  // auto-create table

await _sql.Insert<Category>(new { Title = "New cat", Description = "..." });
await _sql.Update<Category>(new { Title = "Updated" }, new { Id = 1 });
var list = await _sql.Select<Category>();
var single = await _sql.Select<Category>(new { Id = 1 });
await _sql.Delete<Category>(new { Id = 1 });
```

---

## 🔐 Login & Session (NEW — v2 protocol)

```csharp
@inject IAuthService _auth
@inject ISessionService _session

// Login page:
private async Task HandleLogin()
{
    try
    {
        var response = await _auth.LoginAsync(projectGuid, loginToken);
        // session automatically stored; timeout = response.Project.SessionTimeoutMinutes
        NavigationManager.NavigateTo("/");
    }
    catch (AuthException ex)
    {
        await AlertService.ShowErrorAsync("ورود ناموفق", ex.Message);
    }
}

// Watch for session expiry (MainLayout):
protected override void OnInitialized()
{
    _session.SessionExpired += async (_, e) =>
    {
        await AlertService.ShowWarningAsync("نشست منقضی شد", e.Reason);
        NavigationManager.NavigateTo("/login");
    };
}
```

- **Timeout is in MINUTES** — controlled from webapi `Projects` table per project (runtime-adjustable).
- On any HTTP 401/403 the client auto-ends the session and raises `SessionExpired` → redirect to login.

### New RequestService usage
```csharp
// Query (with optional userId)
var users = await _req.QueryAsync<User>("SELECT * FROM Users WHERE Active=@active", new { active = 1 });

// Execute (INSERT/UPDATE/DELETE)
await _req.ExecuteAsync("INSERT INTO Users(Name) VALUES(@Name)", new { Name = "Ali" });

// Scalar
var count = await _req.ScalarAsync<int>("SELECT COUNT(*) FROM Users");

// Model-driven (server auto-creates table/columns)
await _req.ExecuteModelAsync("INSERT INTO Categories(Title) VALUES(@Title)", new Category { Title = "X" });

// Named script from webapi Data/Scripts
var rows = await _req.RunScriptAsync<MyModel>("Accounting/DailyDocuments", new { date = "2026-01-01" });
```

---

1. **NavigationManager**: For full reload after culture/theme change:
   ```csharp
   NavigationManager.NavigateTo(NavigationManager.Uri, forceLoad: true);
   ```
2. **HttpClient**: `BaseAddress` must point to API server (configured via `ApiSettings.BaseUrl`).
3. **localStorage**: Encrypt sensitive data only; plain for display-safe.
4. **SqlService**: Always call `InitializeAsync<T>()` before first use.
5. **ModalService**: Call `InitializeAsync()` once (MainLayout).

---

## 🆘 Troubleshooting

| Symptom | Fix |
|----------|-----|
| `InvalidOperationException: Encryption failed` | Check `Encryption.Key` set |
| `null` from `Request<T>` | Verify `BaseUrl` + `AppToken` correct; check key validity |
| Modal not showing | Ensure `<Modal />` in MainLayout AND called `ModalService.InitializeAsync()` |
| RTL not applying | Call `CultureService.ApplyDirectionAsync()` after `SetCulture` |
| Table not created | Ensure model has `[Table]` attribute & call `InitializeAsync<T>()` first |

---

## 🗄️ Project Management API (webapi — admin UI + REST)

Projects are stored in webapi's `Projects` table. Each project has its **OWN database + connection string** (runtime-editable).

| Endpoint | Purpose |
|----------|---------|
| `GET /api/projects` | List all projects (name, schema, db, backup settings) |
| `POST /api/projects` | Create project (guid, name, schema, tokens, connection string, timeout minutes, backup settings) |
| `PUT /api/projects/{guid}` | Update project settings |
| `DELETE /api/projects/{guid}` | Delete project |
| `POST /api/projects/{guid}/backup` | Manual backup → `wwwroot/backup/{ProjectGuid}/` |
| `GET /api/projects/{guid}/backups` | List backups (download URLs) |
| `GET /api/projects/{guid}/backups/{file}` | Download .bak file |
| `POST /api/projects/{guid}/restore` | Restore DB from backup (body: `{ backupFileName }`) |
| `PUT /api/projects/{guid}/backup-settings` | Auto-backup: enable, interval minutes, daily time, retention |

All protected by `X-Api-Key` header (admin). Backups auto-purged per `MaxBackupRetention`.

## 📊 Observability (RequestEvents)
Every API request is logged to `[audit].[RequestEvents]` (auto-created): duration, CPU, RAM, status, project, user, error. Admin UI can filter by project/status/error.

---

## 🔄 Auto-Rename & Auto-Commit usage

```csharp
// appsettings.json الجديدة:
"BlazorDeploy": {
  ...
  "AutoCommit": { "Days": 7 }   // 0 = disabled
}

// Auto-rename: فقط نام [Table] را عوض کن:
[Table("Customers", TableVersion = 2)]  // قبلا "Users" بود
public class User { ... }

// بار اول InitializeAsync → PrevTable_Customers ذخیره می‌شود
// دفعه بعد اگر نام عوض شود → sp_rename خودکار
await _sql.InitializeAsync<User>();

// Auto-commit: بعد از هر Insert/Update، اگر 7 روز گذشته باشد
// ستون IsCommitted اضافه و ردیف‌ها mark می‌شوند
await _sql.Insert<User>(new { Name = "Ali" });
await _sql.Update<User>(new { Name = "Reza" }, new { Id = 1 });
```

---

## 🔗 Related
- `blazor-deploy-service` — internal architecture & service details