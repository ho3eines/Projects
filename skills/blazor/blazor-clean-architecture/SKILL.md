---
name: blazor-clean-architecture
description: Clean Architecture for Blazor WASM with Client/Server/Shared layers.
version: 1.0.0
author: Hossein Esfandyari, Hermes Agent
license: MIT
platforms: [linux, macos, windows]
metadata:
  hermes:
    tags: [blazor, architecture, clean-architecture, wasm, dapper, jwt]
    related_skills: [blazor-wasm-bootstrap, blazor-translate-theme-service, blazor-deploy-service]
---

# Blazor Clean Architecture Skill

Implements a production-ready Clean Architecture solution for Blazor WebAssembly with separate Client, Server, Data, Business, and Shared projects.

## When to Use

- Starting a new Blazor WASM project that needs maintainable, testable architecture
- Migrating from monolithic Blazor Server to WASM + API
- Need Dapper-based data layer with JWT authentication
- Building enterprise apps with strict separation of concerns

## Prerequisites

- .NET 8/9/10 SDK installed
- SQL Server instance accessible
- Basic knowledge of Dapper, JWT, Blazor WASM

## Solution Structure

```
MySolution.sln
├── src/
│   ├── Client/           # Blazor WASM (net9.0/10.0)
│   │   ├── Program.cs
│   │   ├── Services/     # ApiClient, AuthStateProvider, TranslateService, ThemeService
│   │   ├── Pages/        # Feature pages (Admin/, Public/)
│   │   ├── Shared/       # Layout, NavMenu, Components/
│   │   │   └── Components/  # Reusable: PddTable, Modals, Pickers
│   │   └── wwwroot/      # css/, js/, lang/, resources/
│   │
│   ├── Server/           # ASP.NET Core Web API
│   │   ├── Program.cs
│   │   ├── Controllers/  # Thin REST endpoints
│   │   ├── Services/     # JwtService, AuthService, RequestService
│   │   └── Middleware/   # Encryption, RateLimiting, ErrorHandling
│   │
│   ├── Data/             # Data Access Layer (Class Library)
│   │   ├── IDbService.cs     # QueryAsync, ExecuteAsync, QueryFirstOrDefaultAsync
│   │   ├── DbService.cs      # Dapper implementation
│   │   ├── Queries/          # Per entity: UserQueries, ProductQueries
│   │   └── Migrations/       # TSQL scripts + runner
│   │
│   ├── Business/         # Business Logic (Class Library)
│   │   ├── Services/     # Domain services
│   │   ├── Models/       # Domain entities
│   │   └── Validation/   # FluentValidation rules
│   │
│   └── Shared/           # Contracts (Class Library)
│       ├── DTOs/         # Request/Response models
│       ├── RequestModel.cs  # SqlName, Parameters, RequestType
│       ├── RequestResult.cs # Success, Data, Error, RowsAffected
│       └── Enums/        # RequestType, OrderStatus
│
├── tests/
│   ├── UnitTests/
│   └── IntegrationTests/
│
├── docker-compose.yml
├── Directory.Build.props
└── README.md
```

## Dependency Rules

- **Client** → Shared only
- **Server** → Data, Business, Shared
- **Data/Business** → No external deps
- **Shared** → No external deps

## Key Patterns

### RequestService (Single API Endpoint)
```csharp
// Client/Services/RequestService.cs
public async Task<RequestResult<T>> Request<T>(string sqlName, object? parameters = null, int isExec = 0)
{
    var req = new RequestModel { SqlName = sqlName, Parameters = parameters, Type = (RequestType)isExec };
    var endpoint = isExec == 0 ? "api/request/query" : "api/request/execute";
    var resp = await _http.PostAsJsonAsync(endpoint, req);
    return await resp.Content.ReadFromJsonAsync<RequestResult<T>>() ?? new();
}
```

### Dapper Data Access
```csharp
// Data/DbService.cs
public async Task<IEnumerable<T>> QueryAsync<T>(string sql, object? param = null)
{
    using var conn = new SqlConnection(_connectionString);
    return await conn.QueryAsync<T>(sql, param);
}
```

### JWT + Refresh Token
- Access Token: in memory (short-lived)
- Refresh Token: HttpOnly, Secure, SameSite=Strict cookie

## wwwroot Structure (Client)
```
wwwroot/
├── css/
│   ├── bootstrap.rtl.min.css
│   ├── bootstrap.min.css
│   └── app.css              # CSS Variables for theming
├── js/
│   ├── bootstrap.bundle.min.js
│   ├── theme.js             # FOUC prevention + setBootstrapTheme
│   └── encryption.js        # AES/JS encryption helpers
├── lang/
│   ├── en.json
│   └── fa.json
└── resources/
    ├── 001_Create_Tables.tsql
    ├── 002_Create_Indexes.tsql
    └── 003_Seed_Data.tsql
```

## Procedure

1. Create solution with `dotnet new sln -n MySolution`
2. Create projects: `dotnet new wasm -o src/Client`, `dotnet new webapi -o src/Server`, `dotnet new classlib -o src/Data`, `dotnet new classlib -o src/Business`, `dotnet new classlib -o src/Shared`
3. Add project references per dependency rules
4. Install NuGet: Dapper, Microsoft.Data.SqlClient, FluentValidation, etc.
5. Implement IDbService/DbService in Data layer
6. Implement RequestService pattern in Client/Server
7. Configure JWT in Server, AuthStateProvider in Client
8. Add wwwroot assets (local Bootstrap, theme.js, lang files)
9. Create TSQL migration scripts in wwwroot/resources
10. Add docker-compose for deployment

## Verification

- [ ] Solution builds with `dotnet build`
- [ ] Client → Server API calls work
- [ ] JWT authentication flow works (login → access token → refresh)
- [ ] Dapper queries execute against SQL Server
- [ ] TSQL migration runner creates schema
- [ ] Dark mode + RTL work via theme.js
- [ ] Docker compose starts all services

## Pitfalls

- Don't put business logic in Controllers — use Services
- Don't reference Server from Client — use Shared DTOs
- Don't use CDN for Bootstrap — local assets only
- Don't store refresh token in localStorage — HttpOnly cookie only
- TSQL scripts must be idempotent (IF NOT EXISTS)