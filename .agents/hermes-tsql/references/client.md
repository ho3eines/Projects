# hermes-tsql — Page / service usage

## Program.cs

```csharp
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
builder.Services.AddMudServices();
builder.Services.AddSingleton<ScriptCatalog>();
builder.Services.AddScoped<DbService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<AuditService>();
builder.Services.AddScoped<UserSession>();
```

## Data from a page

```csharp
@inject DbService Db
@inject ISnackbar Snackbar

var rows = (await Db.QueryAsync<DailyDocumentRow>("accounting", "DailyDocuments",
    new { FromDate = DateTime.Today, ToDate = DateTime.Today, SearchText = "",
          DocumentType = (string?)null, SkipRows = 0, TakeSize = 100 })).ToList();

await Db.ExecuteAsync("accounting", "DocumentInsert", new { ... });
```

Pattern: load in `OnInitializedAsync`; `MudTable Items="..." Loading="..."`;
errors → `Snackbar.Add(ex.Message, Severity.Error)`.

## Login

```csharp
var user = await Auth.AuthenticateAsync(username, password);
if (user is not null) { Session.SignIn(user.UserId, user.Username, user.DisplayName, user.Role); }
```

## Audit

Automatic: `DbService.ExecuteAsync(...)` writes an audit row (success/error)
to `[central].[AuditLog]` with a SHA-256 hash chain. No manual call needed.

```csharp
await Db.ExecuteAsync("accounting", "DocumentInsert", new { ... }); // ← audited automatically
```
