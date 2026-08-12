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
| 14 | `CHANGE_ME` key | Replaced; still rotate in production |

## Residual (WASM reality)

| # | Risk | What we do |
|---|------|------------|
| 10 | Guid + SharedKey extractable from WASM | SharedKey only wraps handshake. Rotate if leaked. User password is the secret. |
| — | Default admin password | Seeded only when Users is empty. Change `Hermes:BootstrapAdminPassword` and the admin password after first run. |
| — | SQL down | Sessions stay in memory of that process only |

## Default seed (first boot with empty Users)

- user: `admin`  
- password: value of `Hermes:BootstrapAdminPassword` (default `ChangeMe.Hermes.2026`)

## Production checklist

- [ ] New `Auth:Key` (64+ random chars)  
- [ ] New SharedKeys per project  
- [ ] Change admin password  
- [ ] Set `Hermes:CorsOrigins` to real HTTPS hosts  
- [ ] Real TLS certificate  
- [ ] SQL backups; never commit `data/` dumps  
