# BlazorDeployService

![Blazor](https://img.shields.io/badge/Blazor-8.0-blue)
![Blazor](https://img.shields.io/badge/Blazor-9.0-blue)
![Blazor](https://img.shields.io/badge/Blazor-10.0-blue)
![NuGet](https://img.shields.io/nuget/v/BlazorDeployService)
![License](https://img.shields.io/badge/license-MIT-green)

---

# BlazorDeployService – Full Documentation

A complete **service & component package** for **Blazor WebAssembly**, designed for production-grade applications.

---

## ✨ Key Features

### 🟦 Zero-Backend SQL Service  
Connect Blazor WebAssembly directly to **SQL Server** or **Oracle** using the built-in API handler — **no backend needed**.

### 🟦 Multi-Language System (Localization Cache)  
High-performance caching, instant switching, auto UI refresh.

### 🟦 Dynamic Theme Management  
Light/Dark/Custom themes with persistent storage.

### 🟦 Bootstrap-Based UI Components  
Forms, inputs, grids, dialogs, utilities — optimized for WASM.

### 🟦 Global Modal System  
Type-safe, parameterized modal windows with return values.

### 🟦 Alert & Notification Service  
Success / Error / Warning / Info — fully async.

### 🟦 Secure Local & Session Storage  
AES-encrypted browser storage.

### 🟦 Culture Handling (RTL/LTR)  
Automatic directional switching when changing language.

### 🟦 API SQL Request Handler  
Send SQL queries → receive **DataTable / JSON** results.

---

# 🚀 Installation

```powershell
Install-Package BlazorDeployService
```

---

# 🟦 Program.cs Setup

```csharp
using BlazorDeployService.Extensions;
.
.
.
builder.Services.AddBlazorDeployServices(builder.Configuration);
```

---

# 🟦 Razor Imports

```razor
@using BlazorDeployService.Services
@using BlazorDeployService.Components
```

---

# 🟦 MainLayout.razor Setup

### Inject services

```razor
@inject CultureService cultureService
@inject LocalizationCacheService _cache
@inject ThemeService Theme
@inject IModalService ModalService
```

### Place shared UI components

```razor
<ThemeSelector />
<LanguageSelector />
<Modal />
```

### Initialization code

```razor
@code {
    protected override async Task OnInitializedAsync()
    {
        _cache.OnChange += StateHasChanged; // All Page 
        Theme.OnThemeChanged += OnThemeChanged;
        Theme.OnDarkModeChanged += OnDarkModeChanged;
        cultureService.OnCultureChanged += StateHasChanged;

        await cultureService.InitializeAsync();
        await cultureService.ApplyDirectionAsync();
        await Theme.InitializeAsync();
        await _cache.InitializeAsync();
        await ModalService.InitializeAsync();
    }

    private void OnThemeChanged(string theme) => InvokeAsync(StateHasChanged);
    private void OnDarkModeChanged(bool isDark) => InvokeAsync(StateHasChanged);
}
```

---

# 🟦 appsettings.json Configuration

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

---

# 🟦 Components

## 🎨 ThemeSelector
```razor
<ThemeSelector />
```

## 🌐 LanguageSelector
```razor
<LanguageSelector />
```

## 🪟 Modal Host (Required)
```razor
<Modal />
```

---

## 🪟 CKEditorBlazor
if UrlToPostImage is null automatic connect Api BlazorDeployService in Config AppSetting With BaseUrl And AppToken
```razor
    <CKEditorBlazor Id="MyEditor1" 
                    @bind-Value="text"
                    UrlToPostImage="http://localhost:44301/api/Upload/uploadImage">
    </CKEditorBlazor>

@code {
	string text ;
    }
```

---
# 🟦 Modal Service Usage

```razor
@inject IModalService ModalService

<button class="btn btn-primary" @onclick="OpenUserModal">Open User Modal</button>

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

---

# 🟦 Injecting Core Services

```razor
@inject RequestService _req
@inject LocalizationCacheService _cache
@inject CultureService _cult
@inject IClientStorageService clientStorage
@inject IAlertService AlertService
```

---

# 🟦 Localization Example

```razor
<PageTitle>@_cache.GetValue("Home")</PageTitle>
<p>@_cache.GetValue("گروه کل")</p>
```

---

# 🟦 SQL Request Example

```razor
<button class="btn btn-sm btn-success" @onclick="onClick">SQL Version</button>
<p>@version</p>

@code {
    string version = string.Empty;

    protected override Task OnInitializedAsync()
    {
        _cache.OnChange += StateHasChanged;
        _cult.OnCultureChanged += StateHasChanged;
        return base.OnInitializedAsync();
    }

    async Task onClick()
    {
        await AlertService.ShowInfoAsync("Loading", "Reading data...");

        var dataTable = await _req.Request(
            "XXXX",
            "select @@VERSION, @id as id",
            new { id = 1 }
        );

        if (dataTable != null)
        {
            version = dataTable.Rows[0][0]?.ToString() ?? "";
            await AlertService.ShowSuccessAsync("Success", "Data loaded successfully");
        }
        else
        {
            await AlertService.ShowErrorAsync("Error", "Failed to load data");
        }

        StateHasChanged();
    }
}
```

---

# 🟦 Available Services

| Service                      | Description                                      |
| ---------------------------- | ------------------------------------------------ |
| **RequestService**           | Execute SQL via API → DataTable output          |
| **LocalizationCacheService** | Multi-language text caching                     |
| **CultureService**           | Culture management + RTL/LTR switching          |
| **ThemeService**             | Light/Dark/Custom theme manager                 |
| **IModalService**            | Global modal interface                          |
| **IAlertService**            | Toast alerts + notifications                     |
| **IClientStorageService**    | Encrypted local/session storage                 |
| **AppHelper**                | Helper constants                                |

---

# ✔ Summary

BlazorDeployService provides everything needed for building professional Blazor WebAssembly applications:

- Modern theme system  
- Full localization engine  
- RTL/LTR support  
- Secure storage  
- Global modals  
- Alerts & notifications  
- SQL-over-API execution  
- Production-ready UI components  

Ideal for dashboards, admin panels, enterprise apps, and multilingual systems.

---

# 📞 Support / Test Token

For free **APPToken** testing:

📧 Email: **mtnprog@gmail.com**  
🌐 Website: **blazordeploy.ir**  
🐛 Issues: GitHub Issues  

---

# 🏗 Built With  
Blazor WebAssembly — .NET 8
