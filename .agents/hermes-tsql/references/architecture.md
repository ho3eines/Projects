# Hermes architecture — communication

## Ports (dev)

| App | HTTPS | HTTP |
|-----|-------|------|
| accounting | 65218 | 65220 |
| central-client | 65219 | 65221 |
| webapi | 65222 | 65223 |

## Registered projects (default)

| App | ProjectGuid | Schema |
|-----|-------------|--------|
| accounting | `8f3c2a11-6b4e-4d9f-a1c7-2e0b9d4f8a31` | accounting |
| central | `1b7e9c44-0d2a-4f18-9e55-6c8a1d3b0f22` | central |

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
