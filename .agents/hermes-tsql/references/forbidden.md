# hermes-tsql — Forbidden

These patterns are **wrong in this repo** even if they exist in other Hossein projects or in `blazordeployservice`.

## Do not load / do not copy

| Source | Why |
|--------|-----|
| `server-client-comm` | Pdd.ir: WebSocket auto-CRUD, `{Entity}Controller`, `BusinessService`, `ICommunicationService` |
| `convert-prompts-to-blazor` “MUST use ICommunicationService” | That interface does not exist here. Use `ISystemApi` |
| BlazorDeploy.ir `POST api/Data/` | Hermes WebAPI has no `Data` controller |
| Per-project `Controllers/` | Clients are WASM-only |

## Do not write

```csharp
// ❌ raw SQL over RequestService
await Request.Request<Row>("SELECT * FROM Documents", null);

// ❌ SqlService ORM against Hermes tables
await Sql.InitializeAsync<Document>();
await Sql.Insert<Document>(new { Title = "x" });

// ❌ new API surface
// accounting has no server. webapi gets NO new {Entity}Controller.

// ❌ WebSocket
builder.Services.AddSingleton<WebSocketHandler>();

// ❌ DateTime in a new Pdd-style DTO just because that skill said "always long"
// Follow BaseEntity (DateTime audit) + DATE for document dates.
// Convert Unix only at PersianDatePicker.

// ❌ MudBlazor / Radzen / Tailwind / shadcn
```

```sql
-- ❌ unqualified / wrong schema
SELECT * FROM Documents;
SELECT * FROM dbo.Documents;   -- unless you truly mean dbo

-- ❌ concatenated input
WHERE Name = '" + search + "'

-- ❌ dynamic SQL from the client
```

## Do write

```csharp
await Api.QueryAsync<DailyDocumentRow>("DailyDocuments", param, "accounting");
await Api.ExecuteAsync("DocumentInsert", param, "accounting");
await Api.ScalarAsync<int>("DocumentNextNumber", param, "accounting");
```

```sql
SELECT ... FROM [accounting].[Documents] d WHERE d.DocumentId = @Id AND d.IsDeleted = 0;
```

## If a tutorial says otherwise

`docs/PROJECT.md` + this skill win. Ignore `server-client-comm`, Pdd.ir READMEs, and BDS `RequestService` samples when the task is Hermes data.
