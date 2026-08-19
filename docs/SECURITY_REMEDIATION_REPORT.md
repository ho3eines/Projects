# SQL Credential Leakage Remediation Report

**Review date:** 2026-08-18

**Scope:** `Tarazin.slnx` (Share, Data, Ui, Web, and MAUI)
**Release status:** **Not release-approved.** Static checks pass, but no .NET SDK,
SQL Server tooling, device runtime, or real MAUI publish output was available in
the review environment. The broker and SQL security migration therefore remain
uncompiled and dynamically unverified.

## 1. Where the credential entered, stayed, and was consumed

This section describes the pre-remediation path before describing the change.

### 1.1 Ingress and residence before remediation

The MAUI project embedded `Tarazin.Maui/appsettings.json` into the application
assembly. That file held a complete permanent SQL administrator credential,
insecure SQL transport flags, and default bootstrap credentials. A commented
alternative SQL credential was present in the same file. Because the file was
an `EmbeddedResource`, all of those values could survive in an APK/EXE/assembly
and be recovered with ordinary string extraction or .NET decompilation.

`Tarazin.Maui/MauiProgram.cs` opened that manifest resource and added it to the
MAUI configuration. It also accepted a process environment override. An
environment variable can avoid a source literal, but it does not solve the
client-secret problem: any permanent value supplied to an untrusted client can
still be recovered from its process or deployment environment.

The same source-controlled administrator and bootstrap defaults also existed in
`Tarazin.Web/appsettings.json`. Web-side configuration is not packaged into the
MAUI app, but committed production-capable credentials are still a repository
and deployment leak.

The former repository additionally packaged product-license/patch material and
copied patched binaries after MAUI publish. Obfuscation or a client-held key
would not make that material secret. Those tracked trees and copy/load paths
were removed; Web can now load a license only from an external, server-only
absolute path.

### 1.2 Consumption before remediation

The historical runtime path was:

1. MAUI loaded its embedded settings in `MauiProgram.cs`.
2. Shared `DbService` called `TarazinConnection.Resolve` during construction.
3. `TarazinConnection` selected the environment/configuration value and returned
   a reusable SQL connection string.
4. `DbService`, `AuditService`, and database initialization opened direct
   `Microsoft.Data.SqlClient` connections for named scripts and SQL operations.
5. Login used that same SQL administrator credential to read
   `[central].[Users]`; `AuthService` then verified the user's PBKDF2 hash.
6. The startup/diagnostic path retained a masked connection value, logged SQL
   destination details, and converted raw exceptions into messages. Masking a
   password in selected output did not remove the recoverable value from the
   MAUI assembly or memory, and raw exception text could disclose sensitive
   provider details.

Accordingly, the principal defect was not merely a logging issue. A permanent,
high-privilege secret entered a distributable client before login and remained
available to every direct operation.

## 2. Existing Web, authentication, customer, and SQL architecture

Before this remediation, `Tarazin.Web` was a Blazor Server host rather than a
business-data Web API. Both hosts reused `Tarazin.Ui` and `Tarazin.Data`; Web
opened SQL in the server process, while MAUI opened SQL in its local .NET
process. Named SQL scripts, models, `DbService`, authentication behavior, and
post-login company/fiscal-year preparation were shared.

Authentication is based on `[central].[Users]`, active/deleted state, PBKDF2
password verification, roles, permissions, `[central].[UserCompanies]`, and the
active company/fiscal-year context. There was no existing customer entity with
the requested public GUID. The remediation therefore adds a narrow
`[central].[CredentialCustomers]` registry that binds a public `CustomerGuid`
to an existing company and has separate active and credential-access switches.
A GUID is lookup material only; it is never accepted as identity by itself.

The business-data architecture remains direct SQL. No CRUD transport layer was
introduced. Web now exposes only a small security control plane for preparing,
refreshing, and revoking MAUI credentials.

## 3. Endpoint placement and credential transport

The broker is mapped by `Tarazin.Web/Program.cs` at:

- `POST /api/mobile/connection/login`
- `POST /api/mobile/connection/refresh`
- `POST /api/mobile/connection/revoke`

Production requests require HTTPS. MAUI uses the platform's normal certificate
validation; it has no custom certificate-acceptance handler. Plain HTTP is
accepted only for a loopback development endpoint. Forwarded protocol/client
headers are disabled by default and can be enabled only with an explicit exact
trusted-proxy IP list. The endpoints are IP rate-limited, request-size bounded,
and return non-cacheable JSON with generic error bodies.

Login sends the current customer GUID, username/password, a cryptographic nonce,
and a UTC timestamp over HTTPS. The server consumes the nonce once, bounds the
timestamp window, verifies PBKDF2 credentials, and validates all of the
following before issuance:

- user existence and active state;
- customer existence, active state, and credential-access switch;
- bound company existence and active/not-deleted state;
- admin status or membership of the user in the customer's company;
- the effective RBAC permissions used to build least-privilege grants.

A successful response contains an opaque session token and a short-lived,
random SQL login. The default SQL credential lifetime is five minutes (bounded
to 2–15 minutes); the default broker session lifetime is thirty minutes
(bounded to 5–120 minutes). Refresh carries the token in the authorization
header and revalidates token hash, customer binding, user, customer, company,
authorization, revocation, expiry, nonce, and timestamp before rotating the SQL
principal. Every rotation retains an immutable session-family ID. A
session-scoped family lock serializes competing refreshes; the successor stays
pending and unusable until predecessor revocation and successor activation
commit atomically. Revoke marks the whole family (including pending or already
rotated descendants) before best-effort principal removal and does not depend
on successful lock acquisition. A hosted cleanup service is the expiry/offline
backstop.

Only token and nonce hashes are persisted. The SQL password and bearer token
are not persisted in plaintext. The credential is encrypted in transit by TLS,
then held in MAUI process memory only. This deliberately does not add custom
client-side encryption: a key capable of decrypting a usable client secret
would itself be extractable. A valid live credential can still be extracted
from a compromised client process; short lifetime, least privilege, customer
binding, RLS, and revocation reduce that residual exposure.

## 4. Preserved user and business flow

The effective flow is now:

```text
MAUI login
  -> HTTPS broker customer/user validation
  -> temporary credential + broker session
  -> existing permission/context preparation
  -> existing DbService named-script operations directly against SQL Server
```

`AuthService` remains the shared authentication entry point. Web continues to
authenticate directly in its server process. On MAUI, the login form requests
the customer GUID and `RemoteCredentialSession` prepares SQL before the
existing permission and workspace calls. Existing models, named scripts,
modules, and business operations were retained.

Failures after credential preparation sign out and revoke/erase the temporary
session. Login/refresh/revoke share a lifecycle gate so a late refresh cannot
recreate credentials after logout. Password fields and duplicate response
references are cleared as soon as practical. Immutable .NET strings cannot be
reliably zeroized, so this is lifetime reduction rather than a claim of perfect
memory erasure.

## 5. Changed components

### Configuration and host startup

- `Tarazin.Maui/appsettings.json` now contains only a non-secret HTTPS
  `ServerEndpoint` and a public `CustomerGuid`. The GUID is not collected from
  the login form or parsed from the endpoint URL.
- `Tarazin.Maui/MauiProgram.cs` registers the MAUI memory-only provider; no SQL
  credential or product license is loaded.
- `Tarazin.Maui/Tarazin.Maui.csproj` retains endpoint-only settings as an
  embedded resource and no longer copies patched vendor binaries.
- `Tarazin.Web/appsettings.json` has no SQL/bootstrap secret. Deployment must
  inject Web SQL issuer configuration and any initial bootstrap password from a
  server-side secret manager/environment.
- `docker-compose.yml` and `tools/test-connection.sh` have no fallback SQL
  password; callers must supply credentials externally.

### Shared data and authentication

- `ISqlConnectionProvider` separates host-specific connection acquisition.
- `ConfigurationSqlConnectionProvider` keeps Web's server-only configured SQL
  behavior.
- `DbService`, `AuditService`, and initialization use the provider and emit
  redacted/generic errors rather than connection, password, server file, or raw
  exception details.
- `TarazinConnection` forces encrypted SQL transport, normal certificate
  validation, no persisted security information, and bounded timeout.
- `AuthService` selects direct Web authentication or MAUI broker preparation
  without changing the business-data call path.

### Broker and MAUI credential lifecycle

- `Tarazin.Share/CredentialBrokerContracts.cs` defines bounded request/response
  DTOs and safe errors.
- `Tarazin.Web/CredentialBrokerService.cs` performs validation, replay control,
  token hashing, permission-derived issuance, pending-session activation,
  family-locked atomic refresh rotation, and whole-family revocation.
- `Tarazin.Web/CredentialCleanupService.cs` removes expired sessions/nonces,
  stale pending issuance, and orphaned/expired SQL principals every minute.
- `Tarazin.Maui/RemoteCredentialSession.cs` validates the endpoint and response,
  stores credentials only in instance memory, refreshes near expiry, constructs
  a secure SQL connection in memory, and clears/revokes on logout or invalid
  responses.
- Login/logout/session paths use safe user-facing messages for invalid GUID,
  invalid user/customer/token, expired credential, and unavailable API/SQL.
- Android disables cleartext traffic and application backup.

### SQL authorization and tenant controls

- Central scripts add customer, nonce, and credential-session control tables.
- Generated SQL logins have random names/passwords, no `master` initialization
  capability, restricted server visibility, a shared denied control-plane
  baseline, and permission-derived schema/object grants.
- Mobile session/company RLS helpers require an activated, live, unrevoked,
  unexpired session bound to the same active customer and active company;
  pending issuance has no data access.
- Tenant-owned tables receive company filters/block predicates. Mobile audit
  predecessor lookup and insertion resolve company ownership from the active
  broker session in SQL rather than trusting a caller-supplied company value.
  Audit rows are append-only to generated principals.
- Shared global data remains readable where existing behavior requires it, but
  mobile global writes are blocked when more than one enabled customer exists.
  Owner-executed Users/Roles/RolePermissions triggers additionally prevent a
  non-Admin generated principal from assigning Admin, changing protected roles,
  or constructing role permission sets beyond its own effective permissions.

The security migration is transactional and versioned, but it has not run on a
real SQL Server in this review environment.

## 6. Logging, storage, TLS, and artifact controls

Focused review found no active path that intentionally writes SQL passwords,
session tokens, connection material, or login passwords to Preferences,
SecureStorage, SQLite, files, caches, static credential fields, logs, debug
output, exception messages, or API errors. `RemoteCredentialSession` retains a
live credential and token only in scoped process memory.

Production Web and MAUI transport requires HTTPS with ordinary platform trust
validation. SQL connections force encryption and reject untrusted server
certificates. No certificate-validation bypass was found. Android backup and
cleartext are disabled; no iOS/Mac Catalyst transport exception or Windows
privilege elevation was found.

`tools/security-regression-scan.py` checks tracked plus untracked non-ignored
source/configuration and build artifacts for credential/token/key patterns,
insecure SQL/TLS settings, unsafe MAUI configuration, license artifacts, and
suspicious printable binary strings. The candidate workflow in `ci/ci.yml` runs
it before build and scans Windows MAUI release output afterward; activation
under `.github/workflows/` still requires a GitHub identity with workflow-write
permission. This is defense in depth, not proof that no runtime memory
disclosure is possible.

## 7. Validation performed

| Validation | Result | Scope |
|---|---:|---|
| `python3 tools/security-regression-scan.py --self-test` | PASS | Scanner fixtures plus current tracked/untracked non-ignored source and configuration |
| `bash tools/cross-schema-scan.sh` | PASS | 271 SQL scripts; no undocumented cross-schema references |
| `python3 tools/sql-contract-scan.py` | PASS | 271 SQL scripts; zero warnings |
| `bash -n tools/test-connection.sh tools/cross-schema-scan.sh` | PASS | Shell syntax |
| JSON parsing for tracked settings/config files | PASS | Static syntax |
| `git diff --check` | PASS | Whitespace/error markers in the current worktree diff |
| Focused searches for SQL credential markers, permanent tokens/keys, storage sinks, sensitive logging, and TLS bypass | PASS with limitations | Current source/configuration; broad repository searches were reviewed in multiple application-focused passes |
| Source inspection of fake/cross-customer GUID checks, active status, bearer binding, replay, expiry, pending activation, atomic family rotation, revoke/cleanup races, RBAC triggers, and audit tenant resolution | PASS statically | Control flow only; no HTTP/SQL execution or trigger compilation |
| Candidate CI workflow definition | PASS statically | `ci/ci.yml` only; GitHub Actions activation and a runner result remain open |

The scanner self-test includes source and binary/artifact fixtures so its
connection-marker and encoded-string detection paths execute without requiring
a MAUI build.

## 8. Required tests not performed

The following acceptance tests are **not complete** because `dotnet`, MSBuild,
SQL client tooling, Docker/Podman, a SQL Server, and MAUI device targets were not
available. Installing the official SDK was attempted, but the TLS connection to
the installer endpoint failed; certificate verification was not bypassed.

- compile all five projects and run .NET analyzers/tests;
- start Web and exercise broker HTTP status/body/cache/TLS behavior;
- apply `_MobileSecurity.sql` and all schema migrations to SQL Server;
- verify temporary login creation, permission-derived grants, rotation, revoke,
  expiry cleanup, connection pooling, and login drop behavior;
- fake GUID, customer-not-found/inactive, disabled access, inactive company,
  invalid/oversized token, replayed nonce, stale/future timestamp, expired
  session/credential, and unauthorized API tests;
- cross-customer read/write attempts and every RLS filter/block predicate;
- denied control-plane, global-write, `master`, server-state, and password-hash
  access from a generated principal;
- unavailable Web/SQL, bad SQL credential, concurrent refresh/logout, canceled
  issuance, malformed successful response, and cleanup failure tests;
- login through permission loading and company/fiscal-year preparation, then
  representative operations for every module;
- inspect Preferences, SecureStorage, SQLite, app files, backups, crash dumps,
  proxy/cache logs, server logs, and exception telemetry after adversarial runs;
- build/publish Android, Windows, iOS, and Mac Catalyst packages, then perform
  archive extraction, string search, IL decompilation, and runtime storage/log
  inspection on the real artifacts.

The Git checkout exposes only a grafted history view. Current tracked files are
scanned, but full historical secret removal cannot be proven here. Every
credential that ever appeared in source must be treated as compromised and
rotated. If secrets remain in reachable repository history, history cleanup is
a separate coordinated operation and does not replace rotation.

## 9. Known security limitations and release gates

1. **Dynamic validation is mandatory.** Do not release until CI builds are green
   and the SQL/broker/device test matrix above passes.
2. **Client memory is not a vault.** A compromised MAUI process can extract a
   currently valid short-lived SQL password or bearer token. The design limits
   duration, scope, tenant reach, and revocability; it does not claim
   impossibility of extraction.
3. **Direct SQL reachability remains.** Preserving existing direct-SQL behavior
   means target devices require network reachability to SQL. Firewall allowlists,
   SQL TLS certificates, monitoring, rate controls, and aggressive lifetime
   settings remain deployment requirements.
4. **Issuer privilege is sensitive.** The Web broker's server-only SQL identity
   can create/drop principals and apply grants. It must be isolated, injected
   from a secret manager, monitored, and unavailable to MAUI.
5. **Provisioning is explicit.** No default customer GUID or bootstrap password
   is created. Operators must provision customers/users through the documented
   server-side procedure and secret channel.
6. **Mobile user/company creation is not atomic.** Provisioning failure between
   those steps must be tested and operationally reconciled.
7. **Audit hash-chain integrity remains open.** Mobile tenant ownership is now
   resolved in SQL and mobile rights are append-only, but the current row hash
   omits `PrevHash`, its precomputed payload can differ from the database-resolved
   owner, and previous-hash lookup/insertion are not serialized on one
   transaction/connection. Do not describe the audit log as cryptographically
   tamper-proof until this is remediated and concurrency-tested.
8. **Official package behavior is unverified.** Removal of patched/license trees
   may expose vendor licensing or build assumptions. Only official dependencies
   may be restored; client-packaged permanent license secrets must not return.

## 10. Release decision

The source-level leakage path has been removed: MAUI configuration now contains
only a non-secret HTTPS endpoint, Web secrets are deployment-only, and MAUI
receives revocable short-lived least-privilege credentials only after
authenticated customer authorization. Static security and SQL contract checks
pass.

The change is suitable for pull-request review, **not for production release**.
Release requires credential rotation, successful .NET/MAUI builds, a real SQL
migration rehearsal, complete adversarial broker/RLS tests, and real artifact,
decompile, storage, log, and exception inspection.
