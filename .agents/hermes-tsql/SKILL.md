---
name: hermes-tsql
description: "THE Hermes architecture + data skill. Use for any entity, TSQL, handshake, ProjectGuid, RequestService, webapi, schema, auth, session, login, CORS, or how projects talk to each other. NEVER use server-client-comm, ICommunicationService, WebSocket, per-project controllers, ISystemApi, or raw SQL."
---

# hermes-tsql — Architecture & communication

This file is the **source of truth** for how Hermes is built and how every project talks to the server. Load it for any data, auth, or new-module work. Do **not** load `server-client-comm`.

---

## 1. What Hermes is

A modular ERP:

- One **webapi** (the only backend)
- One **central-client** (company site + login + project launcher + users)
- Many **product clients** (`accounting`, later `inventory`, `store`, …) — **WASM only, no API**
- **share** — shared DTOs
- **blazordeployservice** — UI services + `IRequestService` transport

Every product owns a **SQL schema** with the same name (`[accounting]`, `[central]`, …).

```
                    ┌─────────────────┐
                    │  SQL Server     │
                    │  HermesMaster   │
                    │  [central]      │
                    │  [accounting]   │
                    │  [inventory]…   │
                    └────────▲────────┘
                             │ named .sql files
                    ┌────────┴────────┐
   handshake + AES  │     webapi      │  :65222
                    │ Auth + Data     │
                    └────────▲────────┘
           ┌─────────────────┼─────────────────┐
           │                 │                 │
    central-client     accounting         future apps
    :65219             :65218             :…
    Guid=central       Guid=accounting
```

---

## 2. Communication protocol (all projects, same)

Two steps. `IRequestService` (`Protocol=Hermes`) does both. Clients never call `/api/system`.

### Step A — Handshake (once per session, cached ~14 min)

```
POST /api/auth/handshake
Header: X-Project-Guid: {guid of THIS wasm app}
Body:   { "data": AES(SharedKey, { projectGuid, timestamp, nonce, clientId? }) }

← { "code": 200, "data": AES(SharedKey, {
      RequestId,          // session token (send as X-API-Key)
      EncryptionKey,      // random AES key for Step B
      ExpiresAt, Schema, Project
    }) }
```

Server checks: known active Guid, SharedKey decrypt, Guid header == body, timestamp ±90s, nonce unused, rate limit 5/min/IP.

Session is stored in **memory + `[central].[Sessions]`**. Schema is taken from the **project registry**, not the client.

### Step B — Named TSQL (every data call)

```
POST /api/Data/
Header: X-API-Key: {session token}
Header: X-Project-Guid: {same guid}          // must match the session
Header: X-User-Token: {user JWT}             // required for query + execute
Body:   JSON-string of AES(EncryptionKey, {
          SqlStr,          // SCRIPT NAME only — not SQL
          Parameters,      // object → Dapper @Params
          IsExec, IsScalar,
          requestDate
        })

← { "code": 200, "data": AES(EncryptionKey, json-result) }
```

| `IsExec` | `IsScalar` | Server does |
|----------|------------|-------------|
| false | false | `QueryAsync` → JSON array |
| true | false | `ExecuteAsync` → `{ AffectedRows }` |
| false | true | `ScalarAsync` → value |

**Rejected:** `SqlStr` with spaces, `;`, `SELECT`, `INSERT`, …  
**Forced:** schema = session.Schema (cannot hop to another project).

### Client code

```razor
@inject IRequestService Request

var rows = await Request.Request<DailyDocumentRow>("DailyDocuments", param);
await Request.Request<object>("DocumentInsert", param, isExec: true);
```

Handshake is automatic. Do not send schema. Do not send SQL.

### Login (user identity — layer 2)

Handshake proves **which app**. Login proves **which human**.

```
POST /api/auth/login
Header: X-API-Key + X-Project-Guid   (must already have a project session)
Body:   { "data": AES(sessionKey, { username, password }) }

← AES(sessionKey, { userToken, displayName, role, userId })
```

`userToken` is an HMAC-JWT signed with server `Auth:Key`.  
Product apps receive it as `?token=` from central-client and call `Request.SetUserToken(token)`.

Writes **and** reads on `/api/Data` require a valid user token.

---

## 3. Project registry (how apps stay connected)

`webapi/appsettings.json` → `Hermes:Projects`:

| Field | Meaning |
|-------|---------|
| `Guid` | Public identity of the WASM app |
| `Name` | `accounting` / `central` / … |
| `Schema` | SQL schema the session is locked to |
| `SharedKey` | Handshake wrapper key (same value in that client's appsettings) |
| `IsActive` | `false` = handshake refused |

New product checklist:

1. New Guid
2. Row in `Hermes:Projects`
3. Client `wwwroot/appsettings.json`: `Protocol=Hermes`, same Guid + SharedKey, `BaseUrl=https://localhost:65222/api/`
4. Folder `webapi/Data/Scripts/{schema}/`
5. WASM project referencing `blazordeployservice` + `share`
6. CORS origin of that client added to `Hermes:CorsOrigins`

`Protocol=BlazorDeploy` is **only** for BlazorDeploy.ir. Never against this webapi.

---

## 4. Directory law

```
Projects/
  docs/PROJECT.md              ← product rules
  docs/SECURITY.md             ← threat model
  .agents/hermes-tsql/         ← THIS skill
  webapi/                      ← only backend
    Controllers/AuthController.cs    handshake + login
    Controllers/DataController.cs    encrypted named TSQL
    Services/SystemQueryExecutor.cs  runs .sql files
    Data/Scripts/{schema}/{Name}.sql
  share/common/Models/         ← DTOs (BaseEntity, …)
  blazordeployservice/         ← RequestService + UI
  central-client/              ← login + launcher
  accounting/                  ← product client
```

Each product client:

```
{project}/
  Pages/Index.razor            home: از/تا تاریخ (default today) + grid
  Pages/Dashboard.razor
  Pages/Entry/
  Pages/SpecialOperations/
  Pages/Reports/
  Pages/Settings/
  Pages/Login.razor            only central-client
  Models/
  wwwroot/appsettings.json     Protocol + ProjectGuid + SharedKey
```

No `Controllers/` under a product. No MudBlazor / Radzen / Tailwind / shadcn. HTML + Bootstrap 5.3.

---

## 5. Named TSQL files

`webapi/Data/Scripts/{schema}/{ScriptName}.sql`

| Kind | Name | IsExec |
|------|------|--------|
| Grid / list | `DailyDocuments`, `{Thing}Search` | false |
| One row | `{Thing}ById` | false |
| Insert / update / soft-delete | `{Thing}Insert` / `Update` / `Delete` | true |
| Scalar | `{Thing}NextNumber` | IsScalar |
| DDL | `_{Thing}Ensure` | true |

Qualify tables: `[accounting].[Documents]`. Parameterize everything. Soft-delete via `IsDeleted`.  
Pagination: `OFFSET @SkipRows ROWS FETCH NEXT @TakeSize ROWS ONLY` — no `TOP` with `OFFSET`.

Path resolve (`SystemQueryExecutor`): `schema/Name` → `Scripts/{schema}/{Name}.sql`.

---

## 6. Security model (layers)

| Layer | What it proves | Where |
|-------|----------------|-------|
| 1 Project handshake | This WASM is a registered product | `ProjectGuid` + SharedKey + nonce |
| 2 Session AES | This browser holds a fresh server key | `EncryptionKey` random per handshake |
| 3 User JWT | This human logged in | `X-User-Token` HMAC-JWT |
| 4 Named scripts | Client cannot run arbitrary SQL | `NamedScriptRules` |
| 5 Schema lock | Client cannot read another product's DB | session.Schema from registry |
| 6 CORS | Only listed WASM origins | `Hermes:CorsOrigins` |

WASM **cannot hide** Guid/SharedKey. SharedKey only wraps handshake. Rotate it if leaked. User password is the real secret.

`/api/system/*` is **not routed** (not a client API).

Details: `docs/SECURITY.md`.

---

## 7. Adding a feature

1. Reports first (if new module)
2. DTO in `share` or `{project}/Models` — names = SQL aliases; audit via `BaseEntity`
3. `.sql` files under the **product schema**
4. Page in Entry / Reports / Settings / SpecialOperations
5. Call `Request.Request<T>("ScriptName", param)`
6. UI: Modal-first CRUD; skeleton loaders; `PersianDatePicker` / `SearchableList` / `IAlertService`

---

## 8. Never

- `server-client-comm`, WebSocket, `{Entity}Controller`, `BusinessService`
- `ISystemApi` / plaintext `/api/system`
- `IRequestService.Request("SELECT …")`
- `ISqlService.Insert/Select/InitializeAsync` for Hermes tables
- Client-chosen schema or connection string
- MudBlazor / Radzen / Tailwind / shadcn
- Asking the user to re-explain this architecture

---

## References

- `references/architecture.md` — sequence diagrams, ports, config samples
- `references/scripts.md` — SQL conventions
- `references/client.md` — Razor + Program.cs
- `references/forbidden.md` — copy-paste anti-patterns
