# Hermes Agent — Skill Routing

Project law: `docs/PROJECT.md` + `docs/SECURITY.md`.
**Data skill: `.agents/hermes-tsql/` only.**
`server-client-comm` is **disabled**. Do not load it.

---

## Data path (non-negotiable)

```
IRequestService.Request("DailyDocuments", param)   // Protocol=Hermes
  → POST /api/auth/handshake   (ProjectGuid, cached session)
  → POST /api/Data/            (AES + named script only)
  → Data/Scripts/{schema-from-guid}/{Name}.sql
```

Forbidden: WebSocket, `{Entity}Controller`, raw SQL in `SqlStr`, `ISqlService` CRUD, plaintext `ISystemApi`.

---

## Always-on

| Skill | When |
|-------|------|
| **`hermes-tsql`** | Any entity, CRUD, report, TSQL, handshake, ProjectGuid |
| `convert-prompts-to-blazor` | UI conversion — data calls become `IRequestService.Request(scriptName)` |
| `blazor-motion` | Animations |
| `ui-ux-pro-max` | Visual design, Bootstrap not Tailwind |
