# hermes-tsql — Client

## Program.cs

```csharp
builder.Services.AddScoped(_ => new HttpClient());
builder.Services.AddBlazorDeployServices(builder.Configuration);
```

`wwwroot/appsettings.json`: `Protocol=Hermes`, `ProjectGuid`, `Encryption` matching `webapi` → `Hermes:Projects`.

## Data

```csharp
@inject IRequestService Request
await Request.Request<Row>("DailyDocuments", param);
await Request.Request<object>("DocumentInsert", param, isExec: true);
```

## User token

```csharp
Request.SetUserToken(jwt);                 // from ?token= or localStorage
var user = await Request.LoginAsync(u, p); // central-client /login
```

Open accounting: `https://localhost:65218/?token={userToken}`

## Do not

- `ISystemApi`
- `Request.Request("SELECT …")`
- pass schema from the client
