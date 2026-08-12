# hermes-tsql — Client

## Register (every WASM `Program.cs`)

```csharp
builder.Services.AddScoped(_ => new HttpClient());
builder.Services.AddBlazorDeployServices(builder.Configuration);
```

`wwwroot/appsettings.json` must set `Protocol=Hermes`, `ProjectGuid`, `Encryption` (SharedKey) matching `webapi` → `Hermes:Projects`.

## IRequestService

```csharp
await Request.Request<Row>("DailyDocuments", param);
await Request.Request<object>("DocumentInsert", param, isExec: true);
```

Handshake is automatic and cached. Schema is not a client argument.

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
