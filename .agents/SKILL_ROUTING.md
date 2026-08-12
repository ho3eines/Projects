# Hermes Agent — Skill Routing

**Data + architecture: `.agents/hermes-tsql/SKILL.md`**

```
Blazor Server page (Modules/*/Pages)
  → @inject DbService Db
  → Db.QueryAsync<T>(schema, "ScriptName", @params)
  → Data/Scripts/{schema}/{Name}.sql   (Dapper, in-process — no HTTP)
```

Forbidden: WebApi/webapi, WASM, HttpClient-for-data, per-project controllers,
tokens/AES transport, Outbox events, Bootstrap/CSS design (use MudBlazor).

Security: `docs/SECURITY.md`
