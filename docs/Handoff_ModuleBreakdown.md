# Module-by-Module Breakdown – Tarazin ERP

## 1. Tarazin.Share
- **Purpose**: Domain‑models and shared contracts.
- **Key files**:
  - `Models/AccountingModels.cs` – POCOs for accounting entities.
  - `Models/InventoryModels.cs` – POCOs for inventory management.
  - `Models/SalaryModels.cs` – payroll and employee remuneration models.
  - `Models/Permissions.cs` – constant definitions for module‑action permissions.
  - `Models/CurrencyModels.cs` – currency‑exchange and monetary‑handling types.
  - (Other POCOs such as `CustomerModels.cs`, `SupplierModels.cs`, etc.)

- **No external dependencies** – pure C# POCOs, used by all other projects.

## 2. Tarazin.Data
- **Purpose**: Data‑access layer built on Dapper; hosts embedded T‑SQL scripts.
- **Directory layout**:
  - `Scripts/{schema}/` – each business domain (accounting, inventory, etc.) gets its own schema folder containing `.sql` files.
- **Key files**:
  - `DbService.cs` – generic Dapper wrapper handling connection, transaction, and query execution.
  - `ScriptCatalog.cs` – statically registers every script under a logical name for runtime discovery.
  - `AuditLog.cs` – entity representing an audit‑log record; inserted automatically by `DbService`.
  - `CurrentUser.cs` – abstraction for the logged‑in user, used by audit & permission checks.
- **Important scripts (examples)**:
  - `accounting/Invoice.sql` – CRUD for invoices.
  - `inventory/StockAdjustment.sql` – adjustments and reconciliations.
  - `salary/Payroll.sql` – batch payroll calculation.
  - `core/Setup.sql` – database schema creation and seed data.
- **Schema‑scan enforcement**: `tools/cross-schema-scan.sh` validates that no module accesses a script outside its declared schema; CI fails on violation.

## 3. Tarazin.Ui
- **Purpose**: Blazor‑based UI library (RCL) shared by Web and MAUI hosts.
- **Important subfolders**:
  - `App.razor` – root component; sets up `MudThemeProvider`, global route table, and service collection.
  - `Layout/`  
    - `MainLayout.razor` – master page with sidebar navigation placeholder.  
    - `NavMenu.razor` – collapsible menu that auto‑generates links from registered modules.
  - `Modules/` – one folder per functional module; each contains:
    - `Pages/` – Razor pages for that module (e.g., `Accounting/Pages/Invoices.razor`).
    - `Components/` – shared Blazor components (tables, dialogs, charts).
    - `Services/` – module‑specific services (e.g., `IInvoiceService`).
- **Service layer**:
  - `UserSession.cs` – holds the current user context, permission checks (`CanView`, `CanEdit`).
  - `AuthService.cs` – PBKDF2 password verification, token issuance.
  - `ServiceCollectionExtensions.cs` – extension methods to register all UI services (DI container).
- **UI primitives**:
  - Reuse of MudBlazor components (cards, tables, dialogs).
  - Custom components for dashboards and data‑grids.
- **Styling**:
  - `wwwroot/css/app.css` – global stylesheet, theme variables, responsive utilities.

## 4. Tarazin.Web
- **Purpose**: Blazor Server host that runs the UI library.
- **Core files**:
  - `Program.cs` – boots Blazor Server, adds MVC, configures authentication, injects UI services from `Tarazin.Ui`.
  - `_Host.cshtml` – Razor page that renders the Blazor root component.
  - `appsettings.json` – holds non‑secret configuration (e.g., feature flags). Sensitive values (SQL connection string) are injected via environment variables or secret store at runtime.
- **Dependency injection**: Calls `AddTarazinUiServices()` (defined in UI project) to register all UI services, ensuring a single source of truth for service registration.

## 5. Tarazin.Maui
- **Purpose**: MAUI host that embeds the Blazor UI as a hybrid mobile/desktop application.
- **Core files**:
  - `MauiProgram.cs` – configures MAUI services, adds BlazorWebView, registers UI services, and sets up platform‑specific configuration.
  - `MainPage.xaml` – defines a single screen that hosts the `BlazorWebView` pointing to `App.razor`.
  - `Resources/`, `Platforms/` – platform‑specific assets (icons, native projects).
  - `appsettings.json` – contains only `ServerEndpoint` (HTTPS base URL) used for bootstrap; all other config is supplied via environment variables.
- **Build variations**:
  - **Windows**: `dotnet publish ... -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64`
  - **Android**: similar command with keystore parameters for signing.
  - **iOS**: analogous command for Apple platforms.

## 6. Cross‑Project Dependency Flow
```
Tarazin.Share → Tarazin.Data → Tarazin.Ui → (Tarazin.Web, Tarazin.Maui)
```
- **One‑way dependency rule**: no project may reference a higher‑level project directly.
- Enforced by compile‑time warnings; static analysis (`cross-schema-scan.sh`) also prevents accidental script cross‑access.
- Guarantees clear module boundaries and simplifies testing.

## 7. Configuration & Secrets
- `settings.json` (runtime‑generated) controls:
  - `allowNpm`: enables/disables npm command execution in CI.
  - `env:DEBUG`: toggles verbose logging for local debugging.
  - `permissions:move`: moves permission definitions from admin to user‑scoped storage.
  - `rates:maxCallsPerMinute`: enforces external API rate limiting.
- **SQL connection string**: never stored in source; fetched from environment variable `TARAZIN_SQL_CONNECTION` or a secret manager at runtime.
- **Password handling**: PBKDF2 hashing performed by `AuthService`; hashes stored in `Users` table; no plain‑text passwords anywhere.

## 8. Deployment & Build Summary
| Target | Command (run from repo root) |
|--------|------------------------------|
| **Web (Release)** | `dotnet publish Tarazin.Web/Tarazin.Web.csproj -c Release -o ./publish` |
| **MAUI Windows** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-windows10.0.19041.0 -p:RuntimeIdentifier=win10-x64` |
| **MAUI Android** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-android -p:AndroidKeyStore=... -p:AndroidSigningKeyAlias=... -p:AndroidSigningKeyPass=... -p:AndroidSigningStorePass=...` |
| **MAUI iOS** | `dotnet publish Tarazin.Maui/Tarazin.Maui.csproj -c Release -f net8.0-ios` |

- Deploy **Web** output to IIS or any HTTP‑capable server.  
- Deploy **MAUI** binaries directly to the target device; sign Android/iOS builds with the provided keystore.

## 9. Testing & Validation Process
1. **Schema validation** – Execute `tools/cross-schema-scan.sh`; CI fails if exit code ≠ 0.  
2. **Unit testing** – Place xUnit test projects under each main project’s `Tests/` folder; run `dotnet test`.  
3. **Smoke testing** – After building, run the Web app (`dotnet run --project Tarazin.Web`) and manually navigate each module page to verify data loading and permission checks.  
4. **MAUI verification** – Launch the published executable; confirm login flow, navigation, and that UI renders correctly on each target platform.  
5. **Audit‑log check** – Insert a test operation and verify an entry appears in the `AuditLog` table with correct user & script metadata.

## 10. Documentation References
- `docs/PROJECT.md` – overall project overview.  
- `docs/adr/` – Architecture Decision Records (e.g., ADR‑001 “One‑Way Dependency”).  
- `docs/CURRENCY_MODULE.md` – details on price‑feed integration and rate handling.  
- `skills/twg‑engineering‑work/SKILL.md` – CLI tooling for deeper code‑base exploration.

---  

*This modular breakdown is saved as **Handoff_ModuleBreakdown.md** for quick reference and to avoid repeated deep‑dive reviews of the codebase.*