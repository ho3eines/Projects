# BlazorDeployService

> **NuGet Package** | Version 1.0.99 | License: MIT  
> **Author:** Hossein Esfandyari Nia  
> **Target Frameworks:** .NET 8.0 / 9.0 / 10.0 (Server + Browser)

---

## 1. Project Overview & Value Proposition

**BlazorDeployService** is a comprehensive Razor component library and service framework designed for Blazor applications. It provides a complete suite of reusable UI components, backend services, and infrastructure abstractions that accelerate Blazor application development.

### Why Use This Package?

- **Plug-and-play services**: Register all services with a single extension method call
- **Pre-built UI components**: Modals, date pickers, searchable lists, rich text editors, numeric inputs, theme/language selectors
- **Built-in localization**: Multi-language support with RTL detection (Persian, Arabic, English, Russian, German, Spanish, Chinese, Japanese)
- **Client-side storage**: Unified API for localStorage, sessionStorage, cookies with encryption support
- **Theme management**: Dark/light mode toggle with 5 Bootstrap color themes
- **API communication layer**: Encrypted request/response handling with token-based authentication
- **ORM-like SQL service**: Attribute-based table modeling with auto-migration and CRUD operations
- **Storage monitoring**: Detects and recovers from browser storage clearing events

### Core Capabilities

| Feature | Description |
|---------|-------------|
| Service Registration | One-line DI setup via `AddBlazorDeployServices()` |
| Modal System | Dynamic component rendering with async return values |
| Persian Date Picker | Full Jalali calendar with timezone-aware timestamps |
| Localization Cache | Database-backed translation system with localStorage caching |
| Encryption | AES encryption via JS interop and .NET crypto utilities |
| Alert System | Toast-style notifications (success, warning, error, info) |
| CKEditor Integration | Rich text editor with image upload support |
| Theme Engine | CSS variable-based theming with Bootstrap 5 dark mode |

---

## 2. Architecture & Tech Stack

### Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| `Microsoft.AspNetCore.Components.Web` | 8.0.0 | Blazor component infrastructure |
| `Microsoft.Extensions.DependencyInjection.Abstractions` | 10.0.0 | DI abstractions |
| `Microsoft.Extensions.Options.ConfigurationExtensions` | 8.0.0 | Configuration binding |
| `Newtonsoft.Json` | 13.0.4 | JSON serialization |
| `Microsoft.Extensions.Localization` | 10.0.0 | Localization support |
| `Microsoft.JSInterop` | 8.0.16 | JavaScript interop |

### Target Frameworks

- `net8.0` / `net9.0` / `net10.0` — Server-side
- `net8.0-browser` / `net9.0-browser` / `net10.0-browser` — Client-side (WASM)

### Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────────┐
│                        Consumer Application                         │
│                      (Blazor WASM / Server)                         │
└───────────────────────────┬─────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  ServiceCollectionExtensions                        │
│                 AddBlazorDeployServices(config)                     │
└───────┬─────────────────────────────────────────────────────────────┘
        │ Registers all services via DI
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                         SERVICE LAYER                               │
│                                                                     │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐              │
│  │ IAlertService │  │ IModalService│  │ IThemeService│              │
│  │ (JS Interop)  │  │ (JS Interop) │  │ (JS Interop) │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                  │                       │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐              │
│  │IClientStorage│  │ ICultureServ.│  │IEncryptionServ│              │
│  │   Service    │  │              │  │               │              │
│  └──────┬───────┘  └──────┬───────┘  └──────┬───────┘              │
│         │                 │                  │                       │
│  ┌──────┴───────┐  ┌──────┴───────┐  ┌──────┴───────┐              │
│  │IClientIdServ.│  │ILocalization │  │ IRequestServ.│              │
│  │              │  │  CacheServ.  │  │              │              │
│  └──────────────┘  └──────────────┘  └──────┬───────┘              │
│                                              │                      │
│                                      ┌───────┴───────┐              │
│                                      │   ISqlService  │              │
│                                      │ (ORM + Migr.)  │              │
│                                      └───────────────┘              │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                       COMPONENT LAYER                               │
│                                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────────┐   │
│  │   Modal.    │ │  Language   │ │   Theme     │ │  Searchable │   │
│  │   razor     │ │  Selector   │ │  Selector   │ │    List     │   │
│  └─────────────┘ └─────────────┘ └─────────────┘ └─────────────┘   │
│                                                                     │
│  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐                   │
│  │  Persian    │ │  Bootstrap  │ │  CKEditor   │                   │
│  │ Date Picker │ │  Numeric    │ │   Blazor    │                   │
│  │             │ │   Input     │ │             │                   │
│  └─────────────┘ └─────────────┘ └─────────────┘                   │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                        JS INTEROP LAYER                             │
│                                                                     │
│  alertManager.js   interop.js   storageMonitor.js   CKEditor.js    │
│  clickOutside.js   crypto-js-wrapper.js   keyboardShortcuts.js     │
└─────────────────────────────────────────────────────────────────────┘
        │
        ▼
┌─────────────────────────────────────────────────────────────────────┐
│                    MODELS & DATA LAYER                              │
│                                                                     │
│  AppSettings   Request/Response DTOs   TreeNodeData   VerifyResult  │
│  ApiSettings   EncryptionSettings     LocalizationSettings         │
│  ModalModel    DataDto   ReportDto     RequestDataTable            │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 3. Complete Folder & File Tree Structure

```
BlazorDeployService/
│
├── BlazorDeployService.csproj          # Project file; multi-targeting .NET 8/9/10, NuGet packaging
├── README.md                           # Package README (packed into NuGet)
├── icon.png                            # NuGet package icon
│
├── Components/                         # Reusable Blazor Razor UI components
│   ├── BootstrapNumericInput.razor     # Numeric input with thousand-separator formatting
│   ├── CKEditorBlazor.razor            # CKEditor 4 rich text editor integration
│   ├── LanguageSelector.razor          # Language dropdown with flag icons
│   ├── Modal.razor                     # Dynamic modal dialog system
│   ├── PersianDatePicker.razor         # Jalali/Persian calendar date picker
│   ├── SearchableList.razor            # Generic searchable dropdown with keyboard navigation
│   └── ThemeSelector.razor             # Theme picker with dark/light mode toggle
│
├── Extensions/                         # DI extension methods
│   └── ServiceCollectionExtensions.cs  # AddBlazorDeployServices() registration
│
├── Helper/                             # Static utilities
│   └── AppHelper.cs                    # Global constants (ConnectionStringToken)
│
├── Models/                             # Data transfer objects and settings
│   ├── ApiSettings.cs                  # ApiSettings, EncryptionSettings, LocalizationSettings, AppSettings
│   ├── DataDto.cs                      # Generic data wrapper DTO
│   ├── ModalModel.cs                   # Modal configuration model
│   ├── ReportDto.cs                    # Report generation DTO
│   ├── Request.cs                      # Request/response models (Request, requestData, responeData, etc.)
│   ├── RequestDataTable.cs             # DataTable-based request model
│   ├── TreeNodeData.cs                 # Hierarchical tree node model
│   └── VerifyResult.cs                 # Authentication verification models
│
├── Services/                           # Core service implementations and interfaces
│   ├── AlertService.cs                 # Toast notification service via JS interop
│   ├── ClientIdService.cs              # Persistent client ID with storage recovery
│   ├── ClientStorageService.cs         # Unified localStorage/sessionStorage/cookie API
│   ├── CultureService.cs               # Culture/locale management with RTL support
│   ├── EncryptionService.cs            # AES encryption via JS interop
│   ├── IClientIdService.cs             # Client ID interface + StorageClearedEventArgs
│   ├── IClientStorageService.cs        # Storage service interface
│   ├── IEncryptionService.cs           # Encryption service interface
│   ├── LocalizationCacheService.cs     # Translation cache with DB backing
│   ├── ModalService.cs                 # Modal lifecycle management
│   ├── RequestService.cs               # HTTP API communication with encryption
│   ├── SqlService.cs                   # Attribute-based ORM with auto-migration
│   ├── StorageMonitorService.cs        # Browser storage clearing detection
│   └── ThemeService.cs                 # Theme/dark mode persistence and CSS variables
│
└── wwwroot/                            # Static web assets (packed into NuGet)
    ├── css/
    │   ├── app.css                     # Application styles
    │   ├── site.css                    # Site-level styles
    │   └── bootstrap/                  # Bootstrap CSS
    │
    └── js/
        ├── alertManager.js             # Alert/notification JS module
        ├── ckeditor.js                 # CKEditor 4 library
        ├── ckeditor.js.map             # CKEditor source map
        ├── CKEditorInterop.js          # Blazor-CKEditor interop bridge
        ├── clickOutside.js             # Click-outside detection utility
        ├── crypto-js-wrapper.js        # CryptoJS wrapper functions
        ├── crypto-js.min.js            # CryptoJS minified library
        ├── interop.js                  # General JS interop (themes, language, encryption)
        ├── keyboardShortcuts.js        # Keyboard shortcut handler
        └── storageMonitor.js           # localStorage monitoring & recovery
```

---

## 4. Deep-Dive API & Component Reference

### 4.1 Services

#### 4.1.1 IAlertService / AlertService

Displays toast-style notifications via JavaScript interop.

| Method | Parameters | Return | Description |
|--------|-----------|--------|-------------|
| `ShowSuccessAsync` | `title: string, message: string, duration: int = 5000` | `Task` | Show green success toast |
| `ShowWarningAsync` | `title: string, message: string, duration: int = 5000` | `Task` | Show yellow warning toast |
| `ShowErrorAsync` | `title: string, message: string, duration: int = 5000` | `Task` | Show red error toast |
| `ShowInfoAsync` | `title: string, message: string, duration: int = 5000` | `Task` | Show blue info toast |
| `ShowCustomAsync` | `type: string, title: string, message: string, duration: int = 5000` | `Task` | Show custom-typed toast |
| `HideAllAsync` | — | `Task` | Dismiss all visible alerts |

**Design Pattern:** Lazy initialization — JS module loaded on first call via `EnsureInitializedAsync()`.

**Interface:** `IAlertService` (defined in `Services/AlertService.cs:6`)

---

#### 4.1.2 IClientIdService / ClientIdService

Manages persistent browser client identification with automatic recovery from storage clearing events.

| Member | Type | Description |
|--------|------|-------------|
| `GetClientIdAsync()` | `Task<string>` | Get or create a unique client ID |
| `WasStorageCleared` | `bool` (property) | Whether storage was cleared this session |
| `StorageClearReason` | `string` (property) | Reason storage was cleared |
| `StorageCleared` | `event EventHandler<StorageClearedEventArgs>` | Fired when storage clearing is detected |
| `InitializeAsync()` | `Task` | Initialize JS module and monitoring |
| `DisposeAsync()` | `ValueTask` | Stop monitoring and release resources |

**Recovery Strategy:** Uses sessionStorage backup and cookie backup to recover client ID after localStorage clearing.

**Interface:** `IClientIdService` (defined in `Services/IClientIdService.cs:7`)

---

#### 4.1.3 IClientStorageService / ClientStorageService

Unified API for browser storage mechanisms with optional AES encryption.

**LocalStorage Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetLocalAsync<T>` | `(key: string, value: T)` | Store typed value in localStorage |
| `GetLocalAsync<T>` | `(key: string)` | Retrieve typed value from localStorage |
| `RemoveLocalAsync` | `(key: string)` | Remove key from localStorage |
| `ClearLocalAsync` | `()` | Clear all localStorage |

**Encrypted LocalStorage Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetLocalEncryptedAsync<T>` | `(key: string, value: T, secretKey: string)` | Store AES-encrypted value |
| `GetLocalEncryptedAsync<T>` | `(key: string, secretKey: string)` | Retrieve and decrypt value |

**SessionStorage Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetSessionAsync<T>` | `(key: string, value: T)` | Store in sessionStorage |
| `GetSessionAsync<T>` | `(key: string)` | Retrieve from sessionStorage |
| `RemoveSessionAsync` | `(key: string)` | Remove from sessionStorage |
| `ClearSessionAsync` | `()` | Clear all sessionStorage |

**Cookie Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `SetCookieAsync` | `(key: string, value: string, days: int = 30)` | Set cookie with expiry |
| `GetCookieAsync` | `(key: string)` | Read cookie value |
| `RemoveCookieAsync` | `(key: string)` | Delete cookie |
| `SetSecureCookieAsync` | `(key: string, value: string, days: int = 30)` | Set Base64-encoded secure cookie |

**Encryption Utilities:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `EncryptString` | `(plainText: string, key: string)` | AES encrypt using SHA256-hashed key |
| `DecryptString` | `(cipherText: string, key: string)` | AES decrypt with IV extraction |

**Interface:** `IClientStorageService` (defined in `Services/IClientStorageService.cs:5`)

---

#### 4.1.4 ICultureService / CultureService

Manages UI culture, language direction (RTL/LTR), and locale persistence.

| Member | Type | Description |
|--------|------|-------------|
| `CurrentCulture` | `CultureInfo` (property) | Current thread culture |
| `OnCultureChanged` | `event Action?` | Fired when culture changes |
| `InitializeAsync()` | `Task` | Load saved culture from localStorage |
| `SetCulture(cultureCode)` | `Task` | Change culture (e.g., `"fa-IR"`, `"en-US"`) |
| `GetLang()` | `Task<string>` | Get current language code |
| `ApplyDirectionAsync()` | `Task` | Apply RTL/LTR direction |
| `isRtl()` | `bool` | Check if current culture is RTL |

**Supported Cultures:** `fa-IR`, `en-US`, `ar-SA`, `ru-RU`, `de-DE`, `es-ES`, `zh-CN`, `ja-JP`

**Interface:** `ICultureService` (defined in `Services/CultureService.cs:7`)

---

#### 4.1.5 IEncryptionService / EncryptionService

AES encryption/decryption via JavaScript interop (CryptoJS).

| Method | Parameters | Return | Description |
|--------|-----------|--------|-------------|
| `EncryptDataAsync` | `data: string, key: string = ""` | `Task<string>` | Encrypt string with AES key |
| `DecryptDataAsync` | `encryptedData: string, key: string = ""` | `Task<string>` | Decrypt AES-encrypted string |
| `GenerateRandomKey` | — | `Task<string>` | Generate random encryption key |
| `InitializeAsync` | — | `Task` | Load JS interop module |

**Note:** If `key` is empty, uses `AppSettings.Encryption.Key` from configuration.

**Interface:** `IEncryptionService` (defined in `Services/IEncryptionService.cs:5`)

---

#### 4.1.6 ILocalizationCacheService / LocalizationCacheService

Database-backed translation cache with localStorage persistence.

| Member | Type | Description |
|--------|------|-------------|
| `LangID` | `int` (property) | Current language database ID |
| `OnChange` | `event Action` | Fired when translations update |
| `InitializeAsync()` | `Task` | Load cache from localStorage or database |
| `GetLang()` | `Task` | Resolve and set current language ID |
| `GetValue(key)` | `string` | Get translated value by key |
| `GetValueByCode(Code, columnName)` | `string?` | Get value by language code |
| `GetLanguageTranslationValueByName(Name)` | `string` | Get translation, auto-insert if missing |
| `SupportedLanguages()` | `Task<DataTable?>` | Get filtered supported languages |
| `RefreshCache()` | `Task` | Force reload from database |
| `SetCurrentLanguage(code)` | `Task` | Switch active language |
| `IsLanguageSupported(code)` | `bool` | Check if language code is in supported list |
| `GetLanguageIdByCode(code)` | `int` | Resolve language code to database ID |
| `AddSupportedLanguage(code)` | `bool` | Dynamically add a language |
| `RemoveSupportedLanguage(code)` | `bool` | Remove a language from supported list |
| `UpdateSupportedLanguages(codes)` | `void` | Replace entire supported language list |
| `GetLocalizationSettings()` | `LocalizationSettings` | Get current settings |
| `InsertLanguageTranslation(Name)` | `void` | Queue translation for insertion |

**Caching Strategy:** Uses `ConcurrentDictionary` for in-memory deduplication and `localStorage` for persistence (24-hour TTL).

**Interface:** `ILocalizationCacheService` (defined in `Services/LocalizationCacheService.cs:14`)

---

#### 4.1.7 IModalService / ModalService

Dynamic modal dialog system supporting async result retrieval.

| Member | Type | Description |
|--------|------|-------------|
| `OnShow` | `event Action<ModalModel>` | Fired when modal opens |
| `OnClose` | `event Action<string>` | Fired when modal closes (returns modal ID or `"all"`) |
| `Show<TComponent>(title, parameters, closebutton, modalSize)` | `Task<object?>` | Open modal, return result on close |
| `Close(result, modalId)` | `void` | Close specific modal with optional result |
| `CloseAll()` | `void` | Close all open modals |
| `InitializeAsync()` | `Task` | Inject CSS/JS and setup DotNet reference |

**Return Value:** The `Show<T>()` method returns a `Task<object?>` that resolves when the modal is closed, enabling async result patterns.

**Modal Sizes:** `"modal-sm"` (400px), `"modal-lg"` (800px, default), `"modal-xl"` (1140px)

**Interface:** `IModalService` (defined in `Services/ModalService.cs:10`)

---

#### 4.1.8 IRequestService / RequestService

HTTP API communication layer with encrypted request/response handling.

| Member | Type | Description |
|--------|------|-------------|
| `BaseUrl` | `string` (property) | API base URL |
| `APIKey` | `string` (property) | API authentication key |
| `Request<T>(sqlstr, param, isExec, connectionstring, userCode)` | `Task<List<T>?>` | Execute SQL query via API, return typed list |
| `GetData<T>(sql, parameters)` | `Task<List<T>>` | Read data mapped to model T |
| `PrintToPdf(reportPath, dt)` | `Task` | Generate and open PDF report |

**Request Flow:**
1. Call `verifyAsync()` → GET request to obtain `RequestId` + `EncryptionKey`
2. Build encrypted payload with SQL, parameters, connection token
3. POST encrypted data to API endpoint
4. Deserialize and return typed response

**Interface:** `IRequestService` (defined in `Services/RequestService.cs:11`)

---

#### 4.1.9 ISqlService / SqlService

Attribute-based ORM with auto-migration, CRUD operations, and Unix timestamp utilities.

**Attributes:**

| Attribute | Target | Description |
|-----------|--------|-------------|
| `[Table("name", version)]` | Class | Maps class to SQL table name with versioning |
| `[PrimaryKey]` | Property | Marks property as primary key |
| `[Identity]` | Property | Marks property as auto-increment identity |
| `[Required]` | Property | Marks property as NOT NULL |
| `[MaxLength(n)]` | Property | Sets NVARCHAR(n) instead of NVARCHAR(MAX) |
| `[SqlType("type")]` | Property | Override auto-detected SQL type |
| `[Default("expr")]` | Property | Set column default value |

**Methods:**

| Method | Signature | Description |
|--------|-----------|-------------|
| `InitializeAsync<T>()` | `Task` | Auto-create table or add missing columns |
| `Insert<T>(values)` | `Task` | Insert row from anonymous/object values |
| `Update<T>(values, where)` | `Task` | Update rows matching WHERE clause |
| `Select<T>()` | `Task<List<T>>` | Select all rows |
| `Select<T>(where)` | `Task<List<T>>` | Select rows matching WHERE clause |
| `Delete<T>(where)` | `Task` | Delete rows matching WHERE clause |
| `UnixTimeToDateTime(unixTime)` | `DateTime` | Convert Unix timestamp to DateTime |
| `DateTimeToUnixTime(dateTime)` | `long` | Convert DateTime to Unix timestamp |
| `UnixTimeToPersian(unixTime)` | `string` | Convert Unix timestamp to Jalali date string |

**Type Mapping:**

| C# Type | SQL Type |
|---------|----------|
| `string` | `NVARCHAR(MAX)` or `NVARCHAR(n)` with `[MaxLength]` |
| `int` | `INT` |
| `long` | `BIGINT` |
| `bool` | `BIT` |
| `DateTime` | `DATETIME2` |
| `decimal` | `DECIMAL(18,2)` |

**Interface:** `ISqlService` (defined in `Services/SqlService.cs:78`)

---

#### 4.1.10 IThemeService / ThemeService

Manages theme persistence, dark/light mode, and CSS variable application.

| Member | Type | Description |
|--------|------|-------------|
| `CurrentTheme` | `string` (property) | Active theme key (e.g., `"indigo"`) |
| `IsDarkMode` | `bool` (property) | Whether dark mode is active |
| `OnThemeChanged` | `event Action<string>` | Fired when theme changes |
| `OnDarkModeChanged` | `event Action<bool>` | Fired when dark/light toggles |
| `InitializeAsync()` | `Task` | Load preferences from localStorage |
| `SetThemeAsync(themeKey)` | `Task` | Apply and persist theme |
| `ToggleDarkAsync()` | `Task` | Toggle dark/light mode |
| `ApplyTheme()` | `Task` | Apply current theme to DOM |
| `GetAvailableThemes()` | `IEnumerable<string>` | List theme keys |
| `GetThemeName(themeKey)` | `string` | Get display name for theme key |

**Available Themes:** `indigo`, `emerald`, `blue`, `teal`, `rose`

**Interface:** `IThemeService` (defined in `Services/ThemeService.cs:6`)

---

#### 4.1.11 IStorageMonitorService / StorageMonitorService

Lightweight service for monitoring browser storage clearing events.

| Member | Type | Description |
|--------|------|-------------|
| `OnStorageCleared` | `event Action<string>` | Fired when storage is cleared |
| `InitializeAsync()` | `Task` | Start JS monitoring |
| `GetClientIdAsync()` | `Task<string>` | Get or create client ID |
| `NotifyStorageCleared(reason)` | `void` | JSInvokable callback |

**Interface:** `IStorageMonitorService` (defined in `Services/StorageMonitorService.cs:8`)

---

### 4.2 UI Components

#### 4.2.1 Modal.razor

Dynamic modal dialog that renders any Blazor component.

**Usage:**
```csharp
@inject IModalService Modal

var result = await Modal.Show<MyComponent>(
    "Title",
    new Dictionary<string, object> { { "Param", value } },
    closebutton: true,
    modalSize: "modal-lg"
);
```

**Features:**
- Animated open/close transitions (scale + fade)
- Backdrop click to close
- Dynamic component rendering via `<DynamicComponent>`
- Multiple simultaneous modals supported

---

#### 4.2.2 PersianDatePicker.razor

Jalali (Persian/Solar Hijri) calendar date picker with Unix timestamp values.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Value` | `long?` | `null` | Unix timestamp of selected date |
| `ValueChanged` | `EventCallback<long?>` | — | Callback when date changes |
| `Placeholder` | `string` | `"انتخاب تاریخ"` | Input placeholder text |
| `CssClass` | `string` | `"form-control"` | CSS classes |

**Features:**
- Full Jalali month navigation
- Today highlight
- Click-outside to close
- Timezone-aware timestamp conversion

---

#### 4.2.3 SearchableList.razor

Generic searchable dropdown with keyboard navigation and debounced filtering.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Items` | `List<TItem>` | `new()` | Data source |
| `TextSelector` | `Func<TItem, string>` | `ToString()` | Display text selector |
| `ValueSelector` | `Func<TItem, TValue>` | — | Value selector |
| `Value` | `TValue?` | `null` | Bound value |
| `ValueChanged` | `EventCallback<TValue>` | — | Value change callback |
| `SelectedItem` | `TItem?` | `null` | Bound selected item |
| `SelectedItemChanged` | `EventCallback<TItem>` | — | Item change callback |
| `Placeholder` | `string` | `"جستجو..."` | Input placeholder |
| `DebounceMilliseconds` | `int` | `300` | Search debounce delay |

**Features:**
- Keyboard navigation (Arrow Up/Down, Enter, Escape, Tab)
- Debounced search input
- Glassmorphic CSS design
- Custom scrollbar styling

---

#### 4.2.4 BootstrapNumericInput.razor

Numeric input with automatic thousand-separator formatting.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Value` | `decimal` | `0` | Numeric value |
| `ValueChanged` | `EventCallback<decimal>` | — | Value change callback |
| `CssClass` | `string` | `"form-control"` | CSS classes |
| `Placeholder` | `string` | — | Input placeholder |

**Features:**
- Automatic comma formatting on blur
- Non-numeric character stripping
- Cursor position preservation during typing

---

#### 4.2.5 CKEditorBlazor.razor

CKEditor 4 rich text editor integration with image upload.

**Parameters:**

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `Id` | `string` | Auto-generated | Editor element ID |
| `UrlToPostImage` | `string?` | Auto-detected | Image upload endpoint |

**Features:**
- Lazy script loading
- JS interop bridge for content synchronization
- Automatic cleanup on dispose

---

#### 4.2.6 LanguageSelector.razor

Language dropdown with flag icons and culture switching.

**Features:**
- Loads supported languages from `ILocalizationCacheService`
- Calls `ICultureService.SetCulture()` on selection
- Refreshes translation cache after language change

---

#### 4.2.7 ThemeSelector.razor

Theme picker with dark/light mode toggle button.

**Features:**
- Visual color indicator for each theme
- Active theme highlight
- Dark mode toggle with sun/moon icon
- Event-driven UI updates

---

### 4.3 Models

#### AppSettings (Models/ApiSettings.cs:30)

```csharp
public class AppSettings
{
    public ApiSettings ApiSettings { get; set; }        // API connection settings
    public EncryptionSettings Encryption { get; set; }  // Encryption configuration
    public LocalizationSettings Localization { get; set; } // Language settings
}
```

#### ApiSettings (Models/ApiSettings.cs:9)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `BaseUrl` | `string` | `""` | API server base URL |
| `Timeout` | `int` | `30000` | HTTP timeout in ms |
| `APIKey` | `string` | `""` | API authentication key |
| `Encryption` | `string` | `""` | Default encryption key |
| `ConnectionStringToken` | `string` | `""` | Database connection token |

#### ModalModel (Models/ModalModel.cs:4)

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `Id` | `string` | `Guid.NewGuid()` | Unique modal identifier |
| `ComponentType` | `Type` | — | Component to render in modal body |
| `Title` | `string` | `""` | Modal header title |
| `Parameters` | `Dictionary<string, object>` | `new()` | Parameters for component |
| `CloseButton` | `bool` | `true` | Show close button |
| `Show` | `bool` | `false` | Whether modal is visible |
| `ModalSize` | `string` | `"modal-lg"` | Bootstrap modal size class |

#### TreeNodeData (Models/TreeNodeData.cs:9)

Hierarchical tree node for tree-view components.

| Property | Type | Description |
|----------|------|-------------|
| `Id` | `int` | Node identifier |
| `ParentId` | `int` | Parent node ID |
| `Name` | `string` | Display name |
| `Icon` | `string` | Icon identifier |
| `Level` | `int` | Depth level |
| `Children` | `List<TreeNodeData>` | Child nodes |
| `IsExpanded` | `bool` | Expand state |
| `IsSelected` | `bool` | Selection state |
| `IsVisible` | `bool` | Visibility flag |
| `IsEditing` | `bool` | Edit mode flag |
| `HasChildren` | `bool` | Whether children exist |
| `IsLoading` | `bool` | Loading spinner flag |

---

## 5. Step-by-Step Installation & Usage Guide

### 5.1 Installation

**Via NuGet Package Manager:**
```bash
dotnet add package BlazorDeployService --version 1.0.99
```

**Via Package Manager Console:**
```powershell
Install-Package BlazorDeployService -Version 1.0.99
```

### 5.2 Configuration (appsettings.json)

```json
{
  "BlazorDeploy": {
    "ApiSettings": {
      "BaseUrl": "https://your-api-server.com/api/",
      "Timeout": 30000,
      "APIKey": "your-api-key-here",
      "Encryption": "your-encryption-key-here",
      "ConnectionStringToken": "your-db-connection-token"
    },
    "Encryption": {
      "Enabled": true,
      "Key": "your-default-encryption-key"
    },
    "Localization": {
      "SupportedLanguageCodes": ["fa-IR", "en-US", "ar-SA"],
      "DefaultLanguage": "fa-IR",
      "EnableAutoDetection": true
    }
  }
}
```

### 5.3 Registration (Program.cs)

```csharp
using BlazorDeployService.Extensions;

var builder = WebAssemblyHost.CreateDefault(args);

// Register all BlazorDeployService services
builder.Services.AddBlazorDeployServices(builder.Configuration);

// Register HttpClient for RequestService
builder.Services.AddScoped(sp => new HttpClient
{
    BaseAddress = new Uri(builder.Configuration["BlazorDeploy:ApiSettings:BaseUrl"])
});

await builder.Build().RunAsync();
```

### 5.4 Quick Start Examples

**Example 1: Show a Modal**
```razor
@inject IModalService Modal

<button @onclick="OpenDialog">Open</button>

@code {
    private async Task OpenDialog()
    {
        var result = await Modal.Show<ConfirmDialog>(
            "Confirm Action",
            new Dictionary<string, object>
            {
                { "Message", "Are you sure?" }
            }
        );
        // result contains the dialog's return value
    }
}
```

**Example 2: Use the SQL Service**
```csharp
@inject ISqlService Sql

// Define model with attributes
[Table("Users", 1)]
public class User
{
    [PrimaryKey, Identity]
    public int Id { get; set; }

    [Required, MaxLength(100)]
    public string Name { get; set; }

    [MaxLength(255)]
    public string Email { get; set; }
}

// Initialize table (auto-migration)
await Sql.InitializeAsync<User>();

// Insert
await Sql.Insert<User>(new { Name = "John", Email = "john@example.com" });

// Select
var users = await Sql.Select<User>();
var activeUsers = await Sql.Select<User>(new { IsActive = true });

// Update
await Sql.Update<User>(
    new { Name = "Jane" },
    new { Id = 1 }
);

// Delete
await Sql.Delete<User>(new { Id = 1 });
```

**Example 3: Localized Text**
```razor
@inject ILocalizationCacheService Localization

<h1>@Localization.GetValue("WelcomeMessage")</h1>
<p>@Localization.GetValue("Description")</p>
```

**Example 4: Theme Selector in Layout**
```razor
@using BlazorDeployService.Components

<ThemeSelector />
<LanguageSelector />
```

**Example 5: Persian Date Picker**
```razor
@using BlazorDeployService.Components

<PersianDatePicker @bind-Value="selectedDate" Placeholder="Select date..." />

@code {
    private long? selectedDate;
}
```

**Example 6: Searchable Dropdown**
```razor
@using BlazorDeployService.Components

<SearchableList Items="customers"
                TextSelector="c => c.Name"
                ValueSelector="c => c.Id"
                @bind-Value="selectedCustomerId"
                Placeholder="Search customers..." />
```

**Example 7: Toast Notifications**
```csharp
@inject IAlertService Alert

await Alert.ShowSuccessAsync("Saved!", "Record has been saved successfully.");
await Alert.ShowErrorAsync("Error", "Something went wrong.");
await Alert.ShowWarningAsync("Warning", "Please check your input.");
```

---

## 6. Advanced Configuration & Best Practices

### 6.1 Configuration Options

All settings live under the `"BlazorDeploy"` section in `appsettings.json` and are bound to `AppSettings` via `IOptions<AppSettings>`.

**ApiSettings:**
- `BaseUrl` — Must include trailing slash (e.g., `"https://api.example.com/"`)
- `Timeout` — HTTP client timeout in milliseconds
- `APIKey` — Sent as `X-API-Key` header
- `Encryption` — Default key for `IEncryptionService` when no key is provided
- `ConnectionStringToken` — Identifies which database to query on the server

**LocalizationSettings:**
- `SupportedLanguageCodes` — Array of culture codes (e.g., `["fa-IR", "en-US"]`). Empty array = support all languages
- `DefaultLanguage` — Fallback culture when auto-detection fails
- `EnableAutoDetection` — When `true`, reads `pref_culture` from localStorage

**EncryptionSettings:**
- `Enabled` — Toggle encryption globally
- `Key` — Default AES key for encryption operations

### 6.2 Service Lifetime

All services are registered as **Scoped**. In Blazor WebAssembly, scoped equals singleton. In Blazor Server, scoped means per-connection.

### 6.3 Error Handling

**RequestService:** All API errors are caught and displayed via `IAlertService.ShowErrorAsync()`. The service returns `null` on failure — always check for null returns.

**EncryptionService:** Throws `InvalidOperationException` on encryption/decryption failure. Wrap in try-catch.

**SqlService:** `InitializeAsync<T>()` silently handles missing tables/columns. `Insert`, `Update`, `Delete` throw `InvalidOperationException` when no valid values are provided.

### 6.4 Performance Tips

1. **Lazy JS Module Loading**: All services defer JavaScript module import until first use. Avoid calling `InitializeAsync()` eagerly unless needed.

2. **Localization Cache**: Translations are cached in localStorage with a 24-hour TTL. Call `RefreshCache()` only when translations change.

3. **Storage Monitoring**: `ClientIdService` runs a 5-minute cleanup timer. Dispose properly to stop it.

4. **Modal Stacking**: The modal system supports multiple simultaneous modals. Close modals when done to free resources.

5. **SearchableList Debouncing**: Default debounce is 300ms. Reduce for small lists, increase for large datasets.

### 6.5 CSS/JS Asset Bundling

All static assets under `wwwroot/` are automatically packed into the NuGet package under `_content/BlazorDeployService/`. No manual configuration is needed — Blazor's static asset handling resolves these automatically.

### 6.6 Multi-Targeting

The package targets both server (`net8.0`, `net9.0`, `net10.0`) and browser (`net8.0-browser`, `net9.0-browser`, `net10.0-browser`) frameworks. Ensure your consuming project targets a compatible framework.

### 6.7 Custom Themes

To add a custom theme, modify the `Themes` dictionary in `ThemeService.cs` and add corresponding CSS variables in `GetCssVariablesForTheme()`. Then use `<ThemeSelector />` in your layout.

### 6.8 Security Considerations

- API keys are sent via `X-API-Key` header — use HTTPS in production
- Encryption keys should be stored securely, not in client-side code
- `ClientStorageService` provides AES encryption but keys must be managed by the application
- Cookie-based storage uses `Secure` and `SameSite=Strict` flags in secure mode

---

*Generated from BlazorDeployService v1.0.99 source code.*
