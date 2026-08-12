# Hermes architecture — communication

## Ports (dev)

| App | HTTPS | HTTP |
|-----|-------|------|
| accounting | 65218 | 65220 |
| central-client | 65219 | 65221 |
| webapi | 65222 | 65223 |
| inventory (انبار آمل) | 65224 | 65225 |
| treasury (خزانه‌داری) | 65226 | 65227 |
| payroll (حقوق و دستمزد) | 65228 | 65229 |
| goldshop (طلافروشی) | 65230 | 65231 |
| store (فروشگاه اینترنتی) | 65232 | 65233 |

## Registered projects (default)

| App | ProjectGuid | Schema |
|-----|-------------|--------|
| accounting | `8f3c2a11-6b4e-4d9f-a1c7-2e0b9d4f8a31` | accounting |
| central | `1b7e9c44-0d2a-4f18-9e55-6c8a1d3b0f22` | central |
| inventory | `462cbfaa-c4aa-4248-acd7-44cab2bb982c` | inventory |
| treasury | `25ba213c-d564-436a-aba4-7960dc65ca58` | treasury |
| payroll | `f02962a5-a4c4-4f42-adae-06b2f91e4b6e` | payroll |
| goldshop | `8dd13c7b-1fb6-42f4-943a-7cc9c0204afb` | goldshop |
| store | `0a9bc93f-8eb3-416c-abaa-666f8181331f` | store |

## Event backbone (ADR-002)

Every product schema has an `Outbox` table; `webapi`'s `OutboxProcessor` polls
them and dispatches events (routes in `Outbox:Routes`) to consumer scripts in
target schemas. Consumers are idempotent (`WHERE NOT EXISTS` on EventKey).
`[central].[AuditLog]` records every IsExec call with a SHA-256 hash chain
(`AuditService`).

## Sequence — page load with data

```
User                 accounting WASM              webapi                 SQL
 │                         │                         │                    │
 │  open /?token=JWT       │                         │                    │
 │────────────────────────►│ SetUserToken(JWT)       │                    │
 │                         │                         │                    │
 │  click / OnInit         │ POST auth/handshake     │                    │
 │                         │────────────────────────►│ validate Guid      │
 │                         │                         │ persist session    │
 │                         │◄──── token+AES ─────────│                    │
 │                         │                         │                    │
 │                         │ POST Data (AES DailyDocuments)               │
 │                         │  X-API-Key + X-User-Token                    │
 │                         │────────────────────────►│ check session      │
 │                         │                         │ check user JWT     │
 │                         │                         │ run .sql ─────────►│
 │                         │◄──── AES rows ──────────│◄─── rows ──────────│
```

## Sequence — login then open accounting

```
User              central-client                 webapi
 │                      │                          │
 │  /login              │ handshake (central Guid) │
 │                      │─────────────────────────►│
 │  user/pass           │ POST auth/login          │
 │                      │─────────────────────────►│
 │                      │◄──── userToken ──────────│
 │  click حسابداری      │                          │
 │  navigate to         │                          │
 │  https://localhost:65218/?token={userToken}
```

## Config — client `wwwroot/appsettings.json`

```json
{
  "BlazorDeploy": {
    "ApiSettings": {
      "BaseUrl": "https://localhost:65222/api/",
      "Protocol": "Hermes",
      "ProjectGuid": "<registry guid>",
      "Encryption": "<registry SharedKey>",
      "Timeout": 30000
    }
  }
}
```

## Config — server `Hermes` section

```json
{
  "Hermes": {
    "HandshakeWindowSeconds": 90,
    "SessionMinutes": 15,
    "RequireUser": true,
    "CorsOrigins": [
      "https://localhost:65218",
      "https://localhost:65219",
      "http://localhost:65220",
      "http://localhost:65221"
    ],
    "BootstrapAdminPassword": "admin",
    "Projects": [ ]
  },
  "Auth": {
    "Issuer": "hermes-webapi",
    "Audience": "hermes-clients",
    "Key": "<64+ random chars>",
    "AccessTokenMinutes": 480
  }
}
```

## Tables (central)

- `[central].[Users]` — login
- `[central].[Sessions]` — project sessions (token hash + protected AES key + optional UserId)

## Server classes

| Class | Role |
|-------|------|
| `ProjectCatalog` | Guid → schema + SharedKey |
| `SessionStore` | Issue / validate / persist sessions |
| `HandshakeGuard` | nonce + rate limit |
| `CryptoJsService` | AES-256-CBC matching `interop.js` |
| `UserTokenService` | HMAC-JWT for humans |
| `PasswordHasher` | PBKDF2 |
| `SchemaBootstrap` | `_Ensure` + upsert `admin`/`admin` + `_Seed` per schema |
| `SystemQueryExecutor` | run named `.sql` |
| `NamedScriptRules` | reject raw SQL |

## Client classes

| Class | Role |
|-------|------|
| `RequestService` (Protocol=Hermes) | handshake cache + encrypted Data + `SetUserToken` / `LoginAsync` |
| `EncryptionService` | CryptoJS interop |
| `IAlertService` / `IModalService` | UI only |
