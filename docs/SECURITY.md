# Hermes security

Last reviewed: 2026-08-12

Architecture and wire format live in `.agents/hermes-tsql/SKILL.md`. This file is the threat model.

## Layers

1. **Project handshake** — registered `ProjectGuid` + SharedKey + nonce + timestamp  
2. **Session AES** — random key per handshake; payloads on `/api/Data` encrypted  
3. **User JWT** — HMAC-SHA256 (`Auth:Key`), header `X-User-Token`, required when `Hermes:RequireUser=true`  
4. **Named scripts only** — raw SQL rejected  
5. **Schema lock** — from registry, not the client  
6. **CORS allow-list** — `Hermes:CorsOrigins`  
7. **Sessions** — memory + `[central].[Sessions]` (AES key stored wrapped with `Auth:Key`)

## Closed gaps

| # | Gap | Fix |
|---|-----|-----|
| 1 | Plaintext `/api/system` | Controller is `[NonController]` — not routed |
| 2 | Raw SQL from client | `NamedScriptRules` on `/api/Data` |
| 3 | Handshake every call | Session cached ~14 min |
| 4 | Cleartext Data response | AES(sessionKey) |
| 5 | Client-chosen schema | Forced from ProjectGuid |
| 6 | Replay handshake | 90s window + nonce |
| 7 | Handshake flood | 5/min/IP (+ login 5/min/IP) |
| 8 | Fake JWT authority `:7001` | Removed. User tokens issued locally |
| 9 | CORS `AllowAnyOrigin` | Explicit WASM origins |
| 11 | In-memory sessions only | Persisted to `[central].[Sessions]` (memory fallback if DB down) |
| 12 | No user identity | `POST /api/auth/login` + `X-User-Token` required |
| 13 | Raw TSQL on `/api/request/{query\|execute\|scalar}` | All methods now resolve **named scripts only** (`ResolveNamedScriptSqlAsync` + `NamedScriptRules`) — no client SQL is executed (2026-08-12) |
| 14 | `CHANGE_ME` key | Replaced; still rotate in production |
| 15 | Cross-schema script path (dot/slash name) in `SystemQueryExecutor` | Schema-scoped resolution + path containment (ADR-001 schema lock) (2026-08-12) |
| 16 | Client-driven DDL (`Model.SqlType`/`DefaultExpression` injection) | Auto-provisioning disabled — schemas defined by `_Ensure.sql` only (2026-08-12) |
| 17 | `/api/projects` leaked `EncryptionKey`/`LoginTokenHash`/`ApiKey`/`ConnectionString` | Responses redact all credentials (2026-08-12) |
| 18 | Backup `.bak` downloadable without auth (static `/backup` + unauthenticated `DownloadBackup`) | Static mapping removed; downloads require the API key via `/api/projects/{guid}/backups/{file}` (2026-08-12) |
| 19 | Hard-coded fallback `Auth:Key` (`HERMES-DEV-…`) | Refuse to start when `Auth:Key` is unset (2026-08-12) |

## Residual (WASM reality)

| # | Risk | What we do |
|---|------|------------|
| 10 | Guid + SharedKey extractable from WASM | SharedKey only wraps handshake. Rotate if leaked. User password is the secret. |
| — | Default admin password | Seeded only when Users is empty. Change `Hermes:BootstrapAdminPassword` and the admin password after first run. |
| — | SQL down | Sessions stay in memory of that process only |
| — | API key / HMAC secret / SharedKey / login token are all extractable from WASM | They now only gate **named-script** execution per project. `/api/projects` (admin: create/restore/backup) is still API-key-gated — for production, move this admin surface behind a real server-side session with the user password (backlog). |
| — | `GET /api/projects/directory` is public | Returns only Name/Schema/Icon/Description/ClientUrl (no keys, no connection strings). Needed so the launcher can open each product. |
| — | Login token is a fixed `hermes-admin` for every project | The session is not bound to a per-user password in the v1 client transport. For production, bind sessions to `central.Users` + real login (backlog). |

## Test login (always, upserted on webapi start)

- user: `admin`  
- pass: `admin` (`Hermes:BootstrapAdminPassword`)

## Production checklist

- [ ] New `Auth:Key` (64+ random chars)  
- [ ] New SharedKeys per project  
- [ ] Change admin password  
- [ ] Set `Hermes:CorsOrigins` to real HTTPS hosts  
- [ ] Real TLS certificate  
- [ ] SQL backups; never commit `data/` dumps  
