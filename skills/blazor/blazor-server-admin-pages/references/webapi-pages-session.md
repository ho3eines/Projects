# Session Detail — webapi Admin Pages (Aug 2026)

## What happened
User asked for a page inside webapi to show per-project API connection info. Two user corrections fired:

1. **"project چون درون webapi هست احتیاج به کنترلر نداره واسه ارتباط با sql"** — pages inside webapi must talk to SQL directly; NO controllers, NO HttpClient self-calls for admin pages.
2. **"یک صفحه درست کن که اطلاعات پروژه ها رو واسه اتصال به api انجام بدم"** — they wanted a simple connection-info page (Guid/ApiKey/ConnectionString per project + copy buttons + sample cURL), not an over-engineered create-form. The existing `/create-project` page stayed separate; the NEW page is `/connection`.

## Working pattern established

### direct-SQL from a page
```csharp
@inject IConfiguration Config
@using Dapper
@using Microsoft.Data.SqlClient

private async Task<List<ProjectDefinitionDto>> LoadProjects()
{
    await using var conn = new SqlConnection(Config.GetConnectionString("DefaultConnection")!);
    await conn.OpenAsync();
    var rows = await conn.QueryAsync<ProjectDefinition>("SELECT * FROM [dbo].[Projects] ORDER BY [Name]");
    // map to DTO...
}
```

### copy-to-clipboard buttons that compile
```razor
<button class="btn btn-sm" @onclick="() => CopyApiKey(p)">📋</button>
```
```csharp
@inject IJSRuntime JS  // + @using Microsoft.JSInterop

private async Task CopyApiKey(ProjectDefinitionDto p)
{
    try { await JS.InvokeVoidAsync("navigator.clipboard.writeText", p.ApiKey); }
    catch { /* clipboard blocked (non-secure context) */ }
}
```
Do NOT inline `Copy("literal")` in `@onclick` — Razor compiler chokes (CS7036 / CS1026).

### sample cURL builder
```csharp
private string BuildCurl(ProjectDefinitionDto p) =>
    $"curl {Nav.BaseUri}api/request/query -H \"X-Api-Key: {p.ApiKey}\" -H \"X-Project-Id: {p.ProjectGuid}\" -d '{{\"query\":\"SELECT 1\"}}'";
```

## Errors hit & fixes (chronological)
1. `/projects` → 500: "endpoint contains anti-forgery metadata, but a middleware was not found" → add `app.UseAntiforgery()` AFTER `app.UseRouting()`.
2. `Cannot provide a value for property 'Http' on type ...Projects` → HttpClient not registered in DI; fixed by registering, but direct-SQL is the better fix.
3. Backup: `BACKUP DATABASE [{db}]...` with Dapper `{db}` param → SQL error 911 (Dapper can't bind object names) → string interpolation `$"[{project.DatabaseName}]"`.
4. Backup: `STATS = 0` → "The value '0' is not within range for the STATS parameter" → remove STATS.
5. `HermesMaster` DB missing on local SQL Server instance → create via sqlcmd:
   `"/c/Program Files/Microsoft SQL Server/Client SDK/ODBC/170/Tools/Binn/SQLCMD.EXE" -S localhost -E -C -Q "IF DB_ID('HermesMaster') IS NULL CREATE DATABASE HermesMaster"`
6. Local SQL Server instance names discovered: `MSSQLSERVER` (2022) and `MOEIN` (2019); use `-S localhost` for default instance.

## Verified working (curl tests)
- POST /api/projects → `{"message":"Project created","projectGuid":"..."}`
- GET /api/projects (no key) → 401; with X-Api-Key → 200
- POST /api/projects/{guid}/backup → success, .bak named `{manual|auto}_{DatabaseName}_{yyyyMMdd_HHmmss}.bak`
- GET /api/projects/{guid}/backups → list with download URLs
- GET /api/projects/{guid}/backups/{file} → 200, full byte count (dowload via `-o` path — MSYS `/tmp` path quirk: file written to cwd instead)
- POST /api/projects/{guid}/restore → `Database TestProject restored`
- /projects and /create-project and /connection → all 200