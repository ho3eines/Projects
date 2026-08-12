# Tarazin security (v2.1 — Blazor Hybrid)

Last reviewed: 2026-08-12

Architecture and data rules live in `docs/PROJECT.md` and `.agents/tarazin-tsql/SKILL.md`.
This file is the threat model for the **shared-core + two hosts** architecture
(`Tarazin.Ui` RCL, `Tarazin.Web` Blazor Server, `Tarazin.Maui` Blazor Hybrid).

## Layers

1. **Login** — username/password → `AuthService` verifies PBKDF2 hash from `[central].[Users]`
2. **Session** — web: per SignalR circuit (`UserSession`, scoped); MAUI: per-app (scoped ≈ singleton)
3. **Data access** — named TSQL scripts only (embedded resources); `DbService` scopes by schema; Dapper parameterization
4. **Audit** — every mutating script recorded to `[central].[AuditLog]` with SHA-256 hash chain
5. **Bootstrap admin** — created only when `Users` is empty; change on first production login

## What disappeared with the old architecture (why v2 is simpler)

| Old risk (WASM + webapi) | v2 status |
|---|---|
| SharedKey / AES keys / API keys extractable from WASM | ✅ Gone — nothing secret is shipped to the browser |
| Handshake flood / rate limit per IP | ✅ Gone — no public API endpoint at all |
| Token in URL parameter leaked via logs/referrer | ✅ Gone — no cross-app token hand-off |
| Client-chosen schema / DDL injection via auto-provisioning | ✅ Gone — schema is a compile-time module constant; DDL only via `_Ensure.sql` |
| CORS allow-list management | ✅ Gone — same origin (Blazor Server) |
| Session table + wrapped AES keys | ✅ Gone — per-circuit in-memory session |

## MAUI Blazor Hybrid notes

- The MAUI app embeds `appsettings.json` (connection string + bootstrap admin)
  into the package — **do not ship production credentials inside the app**;
  use per-machine configuration (e.g. `%AppData%`, environment, or a settings
  screen) before distributing builds.
- `Microsoft.Data.SqlClient` runs on Windows/macOS only; Android/iOS need a
  different data provider (backlog) — never ship SQL Server credentials to
  mobile platforms.
- The WebView enforces no CORS (in-process) — same security rules as the web
  host still apply (named scripts, schema scope, audit).

## Remaining considerations (production checklist)

- [ ] Change bootstrap password immediately (`Tarazin:BootstrapAdminPassword` in appsettings or env)
- [ ] Use a strong SQL Server password and store it in a secret store, not `appsettings.json`
- [ ] Enforce HTTPS in production (reverse proxy / TLS on the ASP.NET port)
- [ ] Keep `tools/cross-schema-scan.sh` in CI — it enforces schema isolation
- [ ] Review audit rows regularly (tamper-evident hash chain makes silent edits detectable)
- [ ] SQL Server backups — add scheduled backup outside the app (see roadmap backlog)
- [ ] MAUI: per-machine config for the connection string; don't bake production secrets in the package

## Test login (bootstrap, created at first startup only)

- user: `admin`
- pass: `admin` (`Tarazin:BootstrapAdminPassword`)
