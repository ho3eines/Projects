# Hermes security review — ProjectGuid handshake

Last reviewed: 2026-08-12

## Intended model (all projects)

```
accounting / central / inventory / …
        │  1) POST /api/auth/handshake
        │     X-Project-Guid
        │     body: AES(SharedKey, { projectGuid, timestamp, nonce })
        │
        │  ← session token + session AES key  (15 min, encrypted with SharedKey)
        │
        │  2) POST /api/Data/
        │     X-API-Key: session token
        │     body: AES(sessionKey, { SqlStr: "DailyDocuments", Parameters, IsExec })
        │
        ▼
     webapi
        │  schema forced from ProjectGuid (cannot hop to another project)
        │  SqlStr must be a named script — raw SQL rejected
        ▼
     Data/Scripts/{schema}/{Name}.sql
```

`IRequestService.Request("DailyDocuments", param)` does step 1 automatically (cached), then step 2.

## Gaps that existed before this change

| # | Gap | Risk | Status |
|---|-----|------|--------|
| 1 | `ISystemApi` sent **plaintext** `ScriptName` + params to `/api/system/*` | MITM / token theft reads all queries | Closed for clients: they now use RequestService. `/api/system` still JWT-only (no working issuer yet) |
| 2 | `RequestService` could send **raw SQL** (`SqlStr`) | Full DB compromise if that API is exposed | Closed on Hermes `DataController`: named scripts only |
| 3 | Handshake on **every** `Request()` (old verifyAsync) | Extra load, no session binding | Closed: session cached ~14 min |
| 4 | Response body often **not decrypted** (decrypt commented out) | Data on the wire in clear after POST | Closed in Hermes path: response is AES(sessionKey) |
| 5 | Client could pass **any schema / connection token** | Cross-project data access | Closed: schema comes from session.ProjectGuid |
| 6 | No nonce / timestamp on handshake | Replay of a captured handshake | Closed: 90s window + nonce store |
| 7 | No handshake rate limit | Token-bucket brute force | Closed: 5/min per IP |
| 8 | JWT `Authority` `https://localhost:7001` does not exist | Auth either broken or bypassed | Still open for *user* login. Project handshake does not replace user login |
| 9 | CORS `AllowAnyOrigin` | Any website can call the API from a browser | Open — tighten to known WASM origins before production |
| 10 | `SharedKey` + `ProjectGuid` live in WASM `appsettings.json` | Extractable from browser | Residual (WASM cannot hide secrets). SharedKey only wraps handshake; session key is random. Rotate keys if leaked |
| 11 | Sessions are **in-memory** | Lost on recycle; not shared across multiple webapi instances | Open — move to SQL/`[central].[Sessions]` when you scale out |
| 12 | No **user** identity on the session | Any holder of ProjectGuid can run that project's scripts | Open — next layer: central-client login JWT attached as `userCode` / `X-User-Token` and checked on execute |
| 13 | HTTPS redirection on, but local `TrustServerCertificate` | Dev-only | OK for localhost; require real cert in prod |
| 14 | `Auth:Key` = `CHANGE_ME_…` | Default secret | Open until user login is built |

## Residual risks (accept for now)

1. **WASM secret extraction** — ProjectGuid is an *identifier*. SharedKey is a handshake wrapper, not the data key. Treat leaked SharedKey as “rotate + invalidate sessions”, not as DB access by itself.
2. **Project-level auth ≠ user auth** — handshake proves “this is the accounting app”, not “this is Hossein the accountant”. User login on central-client is the next layer.
3. **In-memory sessions** — single webapi process only.

## Rules going forward

- Every new Hermes client: new row in `webapi/appsettings.json` → `Hermes:Projects` + matching `BlazorDeploy:ApiSettings` (`Protocol=Hermes`, same Guid + SharedKey).
- Never execute client SQL.
- Never let the client choose schema.
- Do not use `ISystemApi` for production data (plaintext).
- BlazorDeploy.ir clients keep `Protocol=BlazorDeploy` (unchanged).
