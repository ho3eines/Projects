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

Forbidden: public CRUD Web APIs, WASM clients, HttpClient-for-business-data,
per-project controllers, permanent SQL credentials/tokens/client decryption
keys, URL tokens, certificate-validation bypasses, Outbox events,
Bootstrap/CSS design (use MudBlazor), and pages outside `Tarazin.Ui/Modules`.
The narrow HTTPS MAUI login/refresh/revoke credential broker is required and
must preserve customer/session binding, replay controls, revocation, and
memory-only client handling.

Security: `docs/SECURITY.md`
