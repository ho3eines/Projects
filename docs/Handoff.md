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
- **Reporting & Printing**: QuestPDF (`PdfReportService`) generates server-side PDFs via `IPdfSaver`; a shared `PrintBrandHeader` adds official company logo/name/address (from company settings) + QRCode to every print. Accounting documents get a two-mode print dialog (simple / advanced nested کل→معین→تفصیل) plus a PDF download. A generic **print engine** (`PrintTemplateService` + `PrintSheetRenderer` HTML + `BuildTemplatePdf` QuestPDF + `TemplatePrintDialog` + `PrintDesigner` at `/central/printing`) lets every report define its own template (company header / data header / detail table / report footer / page footer) with a live design mode; consumers so far: treasury cheque report, accounting documents list. Golden build rule: rebuild `Tarazin.Web` after any `Tarazin.Ui` change (see `docs/Handoff_ModuleBreakdown.md` §3).
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

### UI/UX component catalog (updated ۱۴۰۵/۰۶/۰۹)
- **Mobile-first interaction layer**: `MainLayout` supports horizontal swipe gestures on the responsive drawer (48px threshold), while `app.css` provides compact navigation, touch scrolling, bounded horizontal table scrolling, no page-level horizontal overflow, full-width mobile actions, readable description columns, and compact dialogs at 480px. Full browser/device smoke testing remains environment-dependent when no interactive browser tool is available.
- **Compact visual scale**: global body typography now uses `clamp(0.8rem, 0.77rem + 0.12vw, 0.9rem)` with compact MudBlazor button/input sizing, reduced heading scale, tighter table headers, and smaller stat/module cards. Responsive rules preserve readability and full-width actions on mobile. `.mud-nav-link` is explicitly standardized in `app.css` with Vazirmatn, weight 400, 2px padding, line-height 1.5, flex-start alignment, transparent background, and 250ms transitions.
- Shared reusable components in `Tarazin.Ui/Components/`: `PageHeader`, `PageToolbar`, `StatusChip`, `EntityActions`, `EmptyState`, `FormSection`, `StatCard`, `ModuleCard`, `ModuleSubNav`, `TableSkeleton`, `AccountPickerField`, `AccountPickerDialog`, `EntityEditorDialog`, `PrintBrandHeader`, `ReportPrintDialog`, and `TemplatePrintDialog`.
- Module-specific dialogs/components are kept under `Tarazin.Ui/Modules/{Module}/Components/`; check this catalog before creating a new component.
- `PageToolbar` is used in Inventory/Payroll/Currency/Store settings; `StatusChip` and `EntityActions` are used by selected CRUD tables. Interactive controls use MudBlazor; semantic HTML remains only at layout, print, and accessibility boundaries.
- MudBlazor conventions: use `MudTooltip` instead of unsupported tooltip attributes, `ValidateAsync()` for forms, `MudNavLink` for navigation, and do not use unsupported parameters such as `CloseOnItemClick` on `MudMenu` or `AlignItems` on `MudGrid`.
- **Motion and typography system**: `app.css` defines responsive `clamp()` tokens for font size, spacing, line-height, and animation timing. The latest UI pass also standardizes empty states, CRUD action cells, keyboard focus rings, and mobile touch targets across Central and BI pages. Page entry, surface, card, button, table, focus, and input transitions use GPU-friendly transforms and the shared easing curve. `prefers-reduced-motion: reduce` disables non-essential animations. Desktop spacing expands from 1400px upward; page headings, toolbars, and actions collapse responsively below 800px; mobile page padding and app-bar labels are reduced below 600px.

- **Windows visual QA skill**: `.claude/skills/windows-computer-control/SKILL.md` documents the connected `screen_windows` MCP workflow, UI Automation-first interaction, fresh-capture coordinate rules, viewport/drag testing, verification, and safety levels. Use it for real desktop/browser smoke testing when `mcp_screen_windows_*` tools are injected into the session; CLI connectivity alone is not evidence of visual inspection. `tools/windows_mcp_client.py` provides a dependency-free direct Streamable HTTP client for low-overhead screen/window inspection.

*The handoff file serves as a concise reference to avoid repeated deep‑dive reviews of the codebase.*