# Hermes Agent — Skill Routing

**Data + architecture: `.agents/tarazin-tsql/SKILL.md`**
**MudBlazor CRUD dialogs + delete prompts: `skills/blazor/mudblazor-crud-dialogs/SKILL.md`**
**MAUI Blazor Hybrid: `skills/blazor/blazor-maui-hybrid/SKILL.md`**

```
Page (Tarazin.Ui/Modules/*/Pages)
  → @inject DbService Db
  → Db.QueryAsync<T>(schema, "ScriptName", @params)
  → Tarazin.Data/Scripts/{schema}/{Name}.sql   (embedded; Dapper, in-process — no HTTP)
```

Hosts: `Tarazin.Web` (Blazor Server) and `Tarazin.Maui` (MAUI Blazor Hybrid)
both call `AddTarazinUiServices()` and render the same `Tarazin.App`.

Forbidden: WebApi/webapi, WASM clients, HttpClient-for-data, per-project
controllers, tokens/AES transport, Outbox events, Bootstrap/CSS design (use
MudBlazor), pages outside `Tarazin.Ui/Modules`.

Security: `docs/SECURITY.md`
