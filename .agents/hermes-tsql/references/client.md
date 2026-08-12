# hermes-tsql — Client

## Register (every WASM `Program.cs`)

```csharp
using Share.Extensions;

var builder = WebAssemblyHostBuilder.CreateDefault(args);
builder.RootComponents.Add<App>("#app");
builder.RootComponents.Add<HeadOutlet>("head::after");

builder.Services.AddBlazorDeployServices(builder.Configuration);
builder.Services.AddHermesSystemApi(builder.Configuration);

await builder.Build().RunAsync();
```

`wwwroot/appsettings.json`:

```json
{
  "Hermes": {
    "WebApiUrl": "https://localhost:65222/"
  }
}
```

`AddHermesSystemApi` registers `HttpClient` + `ISystemApi` pointed at `Hermes:WebApiUrl`.

## ISystemApi

`share/Services/SystemApi.cs`

```csharp
Task<SystemQueryResult<T>> QueryAsync<T>(string scriptName, object? parameters = null, string? schema = null);
Task<SystemExecuteResult> ExecuteAsync(string scriptName, object? parameters = null, string? schema = null);
Task<SystemScalarResult<T>> ScalarAsync<T>(string scriptName, object? parameters = null, string? schema = null);
void SetAccessToken(string? token);
```

- `T` property names = SQL aliases.
- Failed HTTP (non-2xx) throws `SystemApiException` with status + body.
- 401: caller should send the user back to `central-client` login.

## Token from central-client

`docs/PROJECT.md`: login in central-client; token travels as a **URL parameter**.

In `App.razor` or layout `OnInitialized`:

```csharp
@inject NavigationManager Nav
@inject ISystemApi Api
@inject IClientStorageService Storage

protected override async Task OnInitializedAsync()
{
    var uri = new Uri(Nav.Uri);
    var query = Microsoft.AspNetCore.WebUtilities.QueryHelpers.ParseQuery(uri.Query);
    if (query.TryGetValue("token", out var token) && !string.IsNullOrWhiteSpace(token))
    {
        Api.SetAccessToken(token);
        await Storage.SetLocalAsync("hermes_token", token.ToString());
    }
    else
    {
        var saved = await Storage.GetLocalAsync<string>("hermes_token");
        if (!string.IsNullOrWhiteSpace(saved))
            Api.SetAccessToken(saved);
    }
}
```

Do not invent a second auth stack inside accounting.

## Page patterns

### Home (`Pages/Index.razor`)

Required by PROJECT.md:

- Search box + filters
- **From date / To date** — default today, user-changeable (`PersianDatePicker`)
- Grid of today’s (filtered) documents
- Row click → open that document (Entry page or modal)

Call `DailyDocuments` (or the project’s equivalent) via `QueryAsync`.

### Entry — modal-first CRUD

```csharp
@inject IModalService Modal
@inject ISystemApi Api

async Task Create()
{
    await Modal.Show<DocumentDialog>("سند جدید");
    await LoadAsync();
}

async Task Edit(DailyDocumentRow row)
{
    await Modal.Show<DocumentDialog>("ویرایش سند",
        new Dictionary<string, object> { { "Id", row.DocumentId } });
    await LoadAsync();
}
```

Dialog loads with `DocumentById`, saves with `DocumentInsert` / `DocumentUpdate`, then `Modal.Close()`.

### Reports

Page + filter bar + `QueryAsync`. Heavy reports stay on a full page, not a dialog.

### Settings

Base tables (شرکت، حساب کل/معین/تفصیلی). Same named-script CRUD. Optional “ensure schema” button that runs `_{Thing}Ensure`.

## Loading & i18n

```razor
@if (Loading)
{
    <div class="placeholder-glow">
        <div class="placeholder col-12" style="height:3rem"></div>
    </div>
}
else { /* grid */ }

<button class="btn btn-primary" disabled="@Saving" @onclick="SaveAsync">
    @if (Saving) { <span class="spinner-border spinner-border-sm me-1"></span> }
    ذخیره
</button>
```

When `ILocalizationCacheService` is initialized, wrap strings with `_cache.GetValue("key")`. Until then, Persian literals are acceptable.

## Ports (launchSettings)

| App | HTTPS |
|-----|--------|
| accounting | https://localhost:65218 |
| central-client | https://localhost:65219 |
| webapi | https://localhost:65222 |

WASM clients must allow CORS — `webapi` already has `AllowAll`.
