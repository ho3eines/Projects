# pdd.ir Reference Architecture - Production Patterns

This document captures the production-ready patterns from `/d/pdd.ir` (Clean Architecture Blazor WASM + API).

## Project Structure

```
pdd.ir/
├── Pdd.ir.Client/          # Blazor WASM (net10.0)
│   ├── Services/           # Core client services
│   ├── Pages/              # Admin + Public pages
│   ├── Shared/Components/  # Reusable components
│   └── Program.cs          # DI registration, TranslateService init
│
├── Pdd.ir.Server/          # ASP.NET Core API
│   ├── Controllers/        # REST endpoints
│   ├── Services/           # JwtService, AuthService, Encryption middlewares
│   └── Program.cs
│
├── Pdd.ir.Data/            # Data Access Layer
│   ├── IDbService.cs       # Interface (QueryAsync, ExecuteAsync, QueryFirstOrDefaultAsync)
│   ├── DbService.cs        # Dapper implementation
│   └── Queries/            # Organized query classes per entity
│
└── Pdd.ir.Business/        # Business Logic
```

## Client Services (Pdd.ir.Client/Services/)

| Service | Purpose |
|---------|---------|
| `TranslateService.cs` | localStorage + JSON fetch via JS interop, event-driven |
| `AuthStateProvider.cs` | Custom AuthenticationStateProvider with JWT |
| `ApiClient.cs` | Unified API communication |
| `EncryptionService.cs` | Request/response encryption |
| `SecurityService.cs` | Client-side security helpers |
| `CommunicationService.cs` | SignalR/HTTP abstraction |
| `ConnectionService.cs` | Connection management |
| `AnimationService.cs` | UI animations |
| `ITranslateService.cs` | Interface |
| `IClientStorageService.cs` | localStorage abstraction |
| `ClientStorageService.cs` | Implementation |

## Key Patterns

### TranslateService Implementation
```csharp
// Uses JS fetch for static files (no API round-trip)
var json = await _js.InvokeAsync<string>("eval", 
    $"fetch('/lang/{culture}.json').then(r => r.text())");

// FOUC prevention: theme.js loads before Blazor
// InitializeAsync() called in Program.cs before app.RunAsync()
// Event-driven: OnLanguageChanged notifies all components
```

### ThemeService (Dark/Light Mode)
- localStorage persistence with key `app_theme`
- JS interop `setBootstrapTheme(theme)` sets `data-bs-theme` on `<html>`
- `theme.js` runs BEFORE Blazor loads - prevents FOUC
- RTL support via `setDocDirection` JS interop

### Program.cs Registration
```csharp
builder.Services.AddSingleton<ILocalStorageService, ClientStorageService>();
builder.Services.AddSingleton<ITranslateService, TranslateService>();
builder.Services.AddScoped<ICommunicationService, CommunicationService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<ApiClient>();

// Initialize translation before app runs
var translateService = app.Services.GetRequiredService<ITranslateService>();
await translateService.InitializeAsync();
```

## Data Layer (Pdd.ir.Data/)

### IDbService Interface
```csharp
public interface IDbService
{
    IDbConnection GetConnection();
    Task<T?> QueryFirstOrDefaultAsync<T>(string sql, object? parameters = null);
    Task<IEnumerable<T>> QueryAsync<T>(string sql, object? parameters = null);
    Task<int> ExecuteAsync(string sql, object? parameters = null);
    Task<T> ExecuteScalarAsync<T>(string sql, object? parameters = null);
}
```

### Query Organization
```
Queries/
├── BlogQueries.cs
├── ClientQueries.cs
├── ContactQueries.cs
├── EventQueries.cs
├── HomeProductQueries.cs
├── HomeSlideQueries.cs
├── PageQueries.cs
├── PortfolioQueries.cs
├── ProductQueries.cs
├── RolePermissionQueries.cs
└── UserQueries.cs
```

## Server Services (Pdd.ir.Server/Services/)

- `JwtService.cs` - JWT token generation/validation
- `AuthService.cs` - Authentication logic
- `CryptoJsService.cs` - Encryption/decryption
- `RequestDecryptionMiddleware.cs` / `ResponseEncryptionMiddleware.cs` - Pipeline encryption
- `TokenBucket.cs` - Rate limiting
- `SessionAuthAttribute.cs` - Authorization attribute

## Security Architecture
- JWT Access Token in memory (never localStorage)
- Refresh Token in HttpOnly Cookie (Secure, SameSite=Strict)
- Request/response encryption middleware
- API Key filter for machine-to-machine

## Component Organization (Client)
```
Shared/Components/
├── PddTable.razor          # Reusable data table
├── Modal.razor             # Base modal
├── FileUpload.razor        # File upload component
├── PersianDatePicker.razor # Persian calendar picker
├── ColorPicker.razor       # Color picker
├── IconPicker.razor        # Icon selector
├── SearchableList.razor    # Searchable dropdown
└── BootstrapNumericInput.razor
```

## Why This Architecture Works
1. **Clean separation** - Client/Server/Data/Business projects
2. **Interface-based** - DI throughout, testable
3. **RequestService pattern** - Single endpoint executing named TSQL files
4. **Proper auth** - JWT + HttpOnly refresh cookie
5. **Organized queries** - Per-entity query classes
6. **Reusable components** - Shared/Components with consistent patterns
7. **Security-first** - Encryption middleware, rate limiting, API keys