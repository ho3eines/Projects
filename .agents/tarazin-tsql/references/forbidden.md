# tarazin-tsql — Forbidden (v2)

These patterns are **wrong in this repo** — even if they exist in other
projects or in older versions of this one.

## Do not load / do not copy

| Source | Why |
|--------|-----|
| `server-client-comm`, Pdd.ir `ICommunicationService`, WebSocket auto-CRUD | That architecture does not exist here |
| `BlazorDeployService` / `RequestService` / `IRequestService` | The NuGet WASM transport was removed |
| `webapi` controllers, `SystemQueryExecutor`, `ISystemApi` | The webapi project was deleted |
| 7 WASM clients (`accounting/`, `store/`, … as projects) | They are modules inside `Tarazin.Shared/Modules/` |
| Old `share/` library | Models live in `Tarazin.Shared/Models/` |

## Do not write

```csharp
// ❌ HTTP for data
var http = new HttpClient();
await http.PostAsJsonAsync("https://localhost:65222/api/...", payload);

// ❌ raw SQL inside a page
await Db.ExecuteAsync("SELECT * FROM Documents WHERE ...", null);

// ❌ new API surface / controller / webapi project

// ❌ token/AES/handshake plumbing (v1.5)
Request.SetUserToken(fromUrl);

// ❌ Bootstrap / hand-rolled CSS classes (h-table, h-card, ...)
// ❌ custom DataGrid / PersianDatePicker — use MudTable / MudDatePicker
```

```sql
-- ❌ unqualified / wrong schema
SELECT * FROM Documents;
SELECT * FROM dbo.Documents;   -- unless you truly mean dbo

-- ❌ concatenated input
WHERE Name = N'" + search + "'

-- ❌ reading another schema without a header declaration
SELECT * FROM [store].[Orders];  -- must declare: -- Cross-schema: store
```

## Do write

```csharp
var rows = await Db.QueryAsync<DailyDocumentRow>("accounting", "DailyDocuments", param);
await Db.ExecuteAsync("accounting", "DocumentInsert", param);
```

```sql
SELECT ... FROM [accounting].[Documents] d WHERE d.DocumentId = @Id AND d.IsDeleted = 0;
```

## If a tutorial says otherwise

`docs/PROJECT.md` + this skill win.
