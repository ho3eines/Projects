# Handoff Document – Tarazin Master Blueprint (2026-08-23)

## Overview
- **Product**: Tarazin – integrated ERP covering sales, inventory, accounting, and related modules.
- **Architecture**: 5 projects with strict one‑way dependency:
  - `Tarazin.Share` – POCO models.
  - `Tarazin.Data` – Dapper access + embedded TSQL scripts (`/Scripts/{schema}/*.sql`).
  - `Tarazin.Ui` – RCL UI, navigation, auth, theming.
  - `Tarazin.Web` – Blazor Server host.
  - `Tarazin.Maui` – MAUI Blazor Hybrid host.
- **Key Contracts**: `ICurrentUser`, `AuthService`, `UserSession`, `DbService`, `ScriptCatalog`.
- **Security**: PBKDF2 password hashing, audit log, permission tables, parameterised queries.
- **Development Workflow**: Report‑first → model → SQL script → permission → UI → schema scan → CI.
- **Configuration**: `settings.json` supports `allowNpm`, `env:DEBUG`, permission moves, rate limits, etc.
- **Deployment Commands**:
  - Web: `dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish`
  - Maui Windows: `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64`
  - Maui Android: `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-android -p:AndroidKeyStore=...`
  - Maui iOS: `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-ios`
- **Testing & CI**: `cross-schema-scan.sh` must pass; unit tests encouraged; smoke tests via manual run.
- **FAQ & References**: See `docs/` for full layout, ADRs, and additional documentation.

*The handoff file serves as a concise reference to avoid repeated deep‑dive reviews of the codebase.*