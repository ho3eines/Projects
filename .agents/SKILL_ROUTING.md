# Hermes Agent — Skill Routing

**Data + architecture: `.agents/hermes-tsql/SKILL.md`**  
`server-client-comm` is disabled.

```
IRequestService (Protocol=Hermes)
  → POST /api/auth/handshake   ProjectGuid
  → POST /api/auth/login       user JWT (central-client)
  → POST /api/Data/            AES + named script + X-User-Token
  → Data/Scripts/{schema-from-guid}/{Name}.sql
```

Forbidden: WebSocket, per-project controllers, raw SQL, `ISystemApi`, `/api/system`.

Security: `docs/SECURITY.md`
