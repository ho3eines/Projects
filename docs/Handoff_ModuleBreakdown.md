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

## یکپارچه‌سازی طلافروشی با ارز، انبار، حسابداری و خزانه‌داری

- مسیر `/goldshop/parties` مشتری و تأمین‌کننده را جداگانه نشان می‌دهد (Employee ها از لیست طلافروشی حذف‌اند) و ماندهٔ ریالی، طلا، ارز و لینک تفصیلی را نمایش می‌دهد؛ `GoldPartyDelete` ابتدا لینک `GoldPartyLinks` را پاک می‌کند تا ردیف یتیم نماند و سپس soft-delete می‌کند.
- مسیر `/goldshop/settings/integration` تنظیم انبار اختصاصی، گروه تفصیلی مشتری/تأمین‌کننده (از `AccountGroupList` نوع Detil)، حساب فروش/موجودی/مالیات/صندوق/بانک (از درخت حساب‌ها با `AccountPickerField` و `TransactionalOnly=true`)، صندوق/بانک پیش‌فرض خزانه و درصد مالیات را نگهداری می‌کند.
- **معماری حساب‌ها**: حساب‌های طلافروشی از **درخت `BaseCol/BaseMoein/BaseDetil`** انتخاب می‌شوند (`AccountId = NodeId`، `AccountCode = مسیر کامل`، مثلاً `2000000` تفصیلی مشتری) — نه جدول تخت `ChartOfAccounts` — تا با `DocumentInsert` و سندهای دستی حسابداری هم‌سو باشند. `GoldShopSettings` ستون‌های `AccountCode/Title` (و `InventoryWarehouseId`/`InventoryAccountGroupId`) را ذخیره می‌کند؛ `GoldShopSettingsUpsert/Get` و `GoldShopModels` به‌روز شده‌اند.
- **اتصال حسابداری خودکار (۱۴۰۵/۰۶/۰۲)**: دیگر انتخاب دستی تفصیلی وجود ندارد. `AccountGroups.DefaultMoeinId` تعیین می‌کند هر گروه تفصیلی به کدام معین می‌رود (seed: مشتریان ← دارایی جاری 10/001، تأمین‌کنندگان ← بدهی‌های جاری 20/001، موجودی کالا ← دارایی جاری). `GoldPartyUpsert` هنگام ساخت مشتری/تأمین‌کننده، تفصیلی را با **کد ۷رقمی داخل بازهٔ گروه** (FromCode + شمارهٔ طرف‌حساب؛ مثلاً CUS-001 → `2000000`، CUS-00010 → `2000009`) می‌سازد یا بازیابی می‌کند و لینک می‌کند. `GoldItemUpsert` همین کار را برای کالاها در گروه موجودی انجام می‌دهد. صندوق/بانک سند هم به تفصیلی‌های استاندارد seed (صندوق اصلی `0000002` / بانک‌ها `0000001`) وصل می‌شوند.
- **تنظیمات شرکت مالی (منبع واحد گروه‌ها)**: گروه‌های تفصیلی مشتری/تأمین‌کننده/موجودی دیگر در صفحهٔ طلافروشی تعریف نمی‌شوند؛ صفحهٔ جدید «تنظیمات شرکت» در ماژول حسابداری (`/accounting/settings`، جدول `accounting.CompanyAccountSettings` + اسکریپت‌های Get/Upsert) منبع واحد است و همهٔ ماژول‌ها (GoldPartyUpsert، GoldItemUpsert، seed طلافروشی) از آن می‌خوانند (با fallback به تنظیمات قدیمی). صفحهٔ اتصال طلافروشی فقط انبار، حساب‌های سند و تسویهٔ خزانه را نگه می‌دارد و به تنظیمات شرکت لینک می‌دهد؛ آیتم تکراری «مشتریان و تأمین‌کنندگان» از منوی طلافروشی حذف شد.
- **یکپارچه‌سازی (۱۴۰۵/۰۶/۰۲)**: برنامه دیگر «انتخاب شرکت» ندارد — یک محیط واحد است. `AccountingContextService.ResolveAsync` بدون دیالوگ، اولین شرکت فعال را خودکار فعال می‌کند (و اگر هیچ شرکتی نباشد، فرم ایجاد شرکت نمایش داده می‌شود)؛ دیالوگ «انتخاب شرکت مالی» و `SelectCompanyAsync` از MainLayout حذف شد و چیپ بالای صفحه فقط سال مالی را نشان می‌دهد. در دیتابیس زنده فقط شرکت «تست» (CompanyId=3) فعال است و همهٔ داده‌ها (حسابداری، انبار/انبار طلا، خزانه، طلافروشی) در همان محیط یکپارچه با یک انبار کار می‌کنند.
- `GoldInvoiceCreate`/`GoldPurchaseCreate` **چندردیفه** (JSON array) با مالیات ردیفی (تیک ۱۰٪)، نرخ ارز (٪ یا مبلغ)، تسویهٔ ترکیبی (نقدی/بانک/چک/ارز/طلا/نسیه)، دفتر طرف‌حساب، انبار، کیف پول ارز، خزانه و **سند حسابداری یاداشت متوازن**. چک در `treasury.Cheques` ثبت می‌شود (Direction=In/Out, Status=Pending) و در سند حسابداری بدهکار/بستانکار بانک منعکس می‌شود. جدول `goldshop.InvoiceLines` ردیف‌ها را ذخیره می‌کند.
- جدول‌های `GoldShopSettings`، `GoldPartyLinks` و `GoldPartyLedger` و ستون‌های PartyId/PaymentStatus/CompanyId و ستون‌های AccountCode/Title/InventoryWarehouseId در startup به‌صورت idempotent ساخته می‌شوند.
- **چندشرکتی‌سازی seedها**: `central._Seed` (طرف‌حساب‌ها و سال مالی ۱۴۰۵)، `accounting._Seed` (ترازنامه/گروه‌ها/TaxRules)، `inventory._Seed` (انبار/کالا) و `treasury._Seed` (بانک/صندوق/نرخ) همه با cursor روی **همهٔ شرکت‌های فعال** اجرا می‌شوند؛ یکتایی‌های سراسری `BaseDetil.DetilCode`، `AccountGroups (Type+Code)`، `Warehouses.WarehouseCode`، `Items.ItemCode`، `Banks/CashBoxes/CurrencyRates/DayCloses` به ایندکس‌های درون‌شرکتی (`UX_*` با CompanyId) تبدیل شده‌اند و `BaseDetilCreateAuto/NextCode` نیز CompanyId-aware هستند.
- **تأیید زنده (۱۴۰۵/۰۶/۰۲)**: مشتری جدید «مشتری اتولینک تست» از UI ساخته شد → کد `CUS-00010` + **تفصیلی خودکار `2000009`** در گروه مشتریان (گروه 3) با لینک به دارایی جاری. فاکتور ۲ گرمی برای همان مشتری → سند `DocumentId=72` متوازن با `AccountCode=2000009` + ردیف دفتر مشتری + حرکت انبار Issue — بدون هیچ انتخاب دستی حساب. فاکتورهای قبلی (GINV-00007 با ۱۰ گرم و GINV-00008 ترکیبی طلا+USD) همچنان با تفصیلی `2000000` کار می‌کنند.

## یکپارچه‌سازی فروشگاه با حسابداری، خزانه و انبار (۱۴۰۵/۰۶/۰۶)

- **قبل از این تغییر** فروشگاه فقط سفارش می‌ساخت و رویداد `OrderPlaced` را در `store.Outbox` می‌نوشت؛ هیچ دیسپچری آن را مصرف نمی‌کرد و پرداخت/سند/دفتر وجود نداشت — «سفارش → انبار» هم ناتمام بود.
- `OrderPlace.sql` بازنویسی شد و دقیقاً الگوی `GoldInvoiceCreate` را اجرا می‌کند (همه در یک تراکنش): کنترل موجودی → سفارش (`Status='Invoiced'` + `PaymentStatus` Paid/Partial/Unpaid + `BalanceRial` + ستون‌های تسویه) → خروج FIFO انبار (لایه‌ها + `Movements` Issue + کاهش `StockQty` + آزادسازی رزروها) → **دفتر مشتری** (`store.OrderLedger`: بدهکار کل، بستانکار تسویه) → **خزانه** (نقد/بانک در `CashMovements` + چک در `Cheques` با `SourceReference='StoreOrder:{id}'`) → **سند حسابداری یاداشت** (`Status='Note'`، `DocumentType='Sale'`، بدهکار: نسیه/صندوق/بانک/چک، بستانکار: فروش، `SourceReference='StoreOrder:{id}'`). خروجی: `OrderId/OrderNumber/TotalAmount/BalanceRial/DocumentId`.
- **تنظیمات فروشگاه** (`store.StoreSettings` + Get/Upsert): انبار، حساب فروش/صندوق/بانک (از درخت حساب‌ها با `AccountPickerField`)، صندوق/حساب بانکی پیش‌فرض خزانه — تب «اتصال حسابداری» در `/store/settings`.
- **مشتریان فروشگاه → طرف حساب یکپارچه**: `store.Customers.PartyId` به `central.Parties` لینک شد؛ `CustomerUpsert` هنگام ساخت/ویرایش مشتری، `central.Parties` (کد `CUS-xxxxx`) + لینک حسابداری خودکار (`treasury.PartyLinks` با تفصیلی از گروه `CompanyAccountSettings.CustomerAccountGroupId` — کد ۷رقمی داخل بازهٔ گروه) می‌سازد. `_Ensure` مشتریان قدیمی بدون لینک را backfill می‌کند. `CustomerList` ماندهٔ دفتر (بدهکار/بستانکار) را هم برمی‌گرداند.
- **UI**: `StoreEntry` بخش تسویه (نقدی/بانک/چک/نسیه با تراز صفر) گرفت؛ `StoreHome` ستون‌های نسیه/تسویه/سند + دیالوگ «جزئیات سفارش» (اقلام + دفتر مشتری + مانده)؛ اسکریپت‌های `OrderItemsByOrder`، `OrderLedgerList`، `OrderLedgerBalance` و مدل‌های `OrderResultRow`، `OrderLedgerRow`، `StoreSettingsRow`، `OrderItemRow` اضافه شدند.
- **تأیید زنده (۱۴۰۵/۰۶/۰۶)**: از UI سفارش ORD-00004 (سارا رضایی، سکه طلا ۶۲٬۰۰۰٬۰۰۰ با تسویهٔ نقد ۴۲٬۰۰۰٬۰۰۰ + چک CHQ-UI-0002 به مبلغ ۲۰٬۰۰۰٬۰۰۰) ثبت شد → سند ۸۹ **متوازن** (صندوق ۴۲M + بانک ۲۰M ← فروش ۶۲M)، ردیف دفتر مشتری ۶۲M/۶۲M، حرکت خزانه CSH-00027، چک Pending و حوالهٔ انبار SIKKEH ۸۵→۸۴. دیالوگ جزئیات و تب اتصال حسابداری از UI تأیید شد.
- نکته: دادهٔ فروشگاه seed قدیمی روی شرکت حذف‌شدهٔ ۱ بود و به شرکت فعال ۳ منتقل شد (مشتریان/محصولات/لینک‌ها).

## 3. Tarazin.Ui
- **Purpose**: Blazor‑based UI library (RCL) shared by Web and MAUI hosts.
- **Coding rules**: development, MudBlazor 9.8.0 conventions, permissions, and copy‑paste UI patterns are documented in `.claude/skills/tarazin-development/SKILL.md` — read it before touching UI code.
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

> **⚠️ Golden build rule:** after **any change in `Tarazin.Ui`** (any `.razor` page/component, service, or the shared `PdfReportService`), always run `dotnet build Tarazin.Web/Tarazin.Web.csproj`. `dotnet test` or a solo `Tarazin.Ui` build only refreshes `Tarazin.Ui/bin` — it does **not** refresh the `Tarazin.Web/bin` copy, and a dev server started with `--no-build` will keep serving the stale code (the recurring “columns RTL but header not” bug). Confirmed by `tools/check-stale-build.sh` before any dev-server restart. The one-shot gate `bash tools/run-checks.sh` runs this whole chain (cross-schema scan → PDF tests → Web build → stale guard) in sequence.

## 9. Testing & Validation Process
1. **Schema validation** – Execute `tools/cross-schema-scan.sh`; CI fails if exit code ≠ 0.  
2. **Unit testing** – Place xUnit test projects under each main project’s `Tests/` folder; run `dotnet test`. `Tarazin.Tests` (xUnit, references `Tarazin.Ui`) guards the shared PDF engine (`PdfReportService`) with regression checks on page size/orientation (`MediaBox`: invoice portrait, cheque report landscape for A4/A5), pagination of long invoices, and RTL right-alignment of cells — `dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo` must stay green on every build (fails if the portrait/landscape or right-alignment bug returns).  
3. **Smoke testing** – The mandatory post-change order is: (1) `dotnet test Tarazin.Tests` → (2) `dotnet build Tarazin.Web` → (3) `tools/check-stale-build.sh` (must be exit 0) → (4) restart the dev server. Run `tools/check-stale-build.sh` **before restarting the dev server** — it verifies the `Tarazin.Ui.dll` copy in `Tarazin.Web/bin` is not older than `Tarazin.Ui/bin` (and that `Tarazin.Ui` itself is not older than its sources), preventing the recurring “server serves old code” bug when the server is started with `--no-build`. Then run the Web app (`dotnet run --project Tarazin.Web`) and manually navigate each module page to verify data loading and permission checks.  
4. **MAUI verification** – Launch the published executable; confirm login flow, navigation, and that UI renders correctly on each target platform.  
5. **Audit‑log check** – Insert a test operation and verify an entry appears in the `AuditLog` table with correct user & script metadata.

## 10. Documentation References
- `docs/PROJECT.md` – overall project overview.  
- `docs/adr/` – Architecture Decision Records (e.g., ADR‑001 “One‑Way Dependency”, ADR‑004 “AuditLog NULL CompanyId = system‑level, never backfill”).
- `docs/CURRENCY_MODULE.md` – details on price‑feed integration and rate handling.  
- `docs/BI_MODULE.md` – BI/reporting module internals (Stimulsoft render engine, license, fonts).
- `.claude/skills/tarazin-development/SKILL.md` – **mandatory coding guide** (architecture, Data layer, MudBlazor 9.8.0 pitfalls, RBAC, copy‑paste patterns for tables/forms/menus/dialogs). Read before any change.
- `skills/twg‑engineering‑work/SKILL.md` – CLI tooling for deeper code‑base exploration.

---  

## 11. Live Verification — ۱۴۰۵/۰۶/۰۲

آخرین بررسی زنده روی Web با SQL Server واقعی و حساب `admin` در شرکت «تست» و سال مالی `1405` انجام شد. نتیجهٔ عملیات واقعی:

| حوزه | مسیر/عملیات | نتیجه |
|---|---|---|
| حسابداری | اسناد روز، ثبت سند، گزارش‌ها | سالم؛ قبلاً در Preview و دیتابیس تأیید شده |
| انبار | ثبت حرکت، کالا، ویرایش/حذف نرم | سالم؛ رکورد شرکت صحیح و حذف با `IsDeleted` تأیید شد |
| خزانه | ثبت گردش نقدی، تنظیمات بانک/صندوق | سالم؛ ثبت با `CompanyId` صحیح تأیید شد |
| حقوق | فهرست/CRUD کارمند، دوره و نهایی‌سازی | صفحات و CRUD سالم؛ نهایی‌سازی به‌صورت مخرب اجرا نشد |
| طلافروشی | فهرست اجناس، CRUD کامل مشتری (ایجاد/ویرایش/حذف)، فرم فاکتور، صفحهٔ اتصال | سالم؛ CRUD مشتری لایو تأیید شد (حذف = soft-delete + پاک‌سازی لینک)، فاکتور فروش → سند حسابداری متوازن + دفتر مشتری + حرکت انبار، تنظیمات اتصال از درخت حساب‌ها ذخیره شد |
| فروشگاه | تنظیمات، دسته‌ها و CRUD مشتری + **یکپارچه‌سازی کامل (۱۴۰۵/۰۶/۰۶)** | سالم؛ ساخت مشتری و تب‌های تنظیمات تأیید شد؛ سفارش → سند حسابداری (یاداشت) + دفتر مشتری + خزانه (نقد/بانک/چک) + حوالهٔ انبار به‌صورت لایو تأیید شد (ORD-00004: سند ۸۹ متوازن، چک CHQ-UI-0002، حوالهٔ SIKKEH) |
| ارز | کیف پول، تبدیل، ثبت حرکت دستی | صفحات سالم؛ خطای واقعی `THROW` با الحاق رشته و نقص tenant در مسیرهای نوشتن اصلاح شد |
| BI | `/bi`، همهٔ تب‌ها، `/bi/reports` و Viewer | سالم؛ Viewer رندر شد، هشدار trial Stimulsoft مورد انتظار است |
| Central | `/central/audit`، فیلتر سیستمی و صفحه‌بندی | سالم؛ ردیف‌های `CompanyId = NULL` جدا و صفحه‌بندی ۵۰تایی تأیید شد |

### چندشرکتی‌سازی سراسری (۱۴۰۵/۰۶/۰۲)
- قبلاً seedهای central/accounting/inventory/treasury فقط **اولین شرکت** را پر می‌کردند و شرکت‌های بعدی ترازنامه/گروه/انبار/بانک نداشتند؛ اکنون همه با cursor روی هر شرکت فعال seed می‌شوند.
- یکتایی‌های سراسری جدول‌های حسابداری/انبار/خزانه به ایندکس‌های درون‌شرکتی تبدیل شدند تا seed چندشرکتی بدون خطا اجرا شود (مهاجرت‌ها در `_Ensure` مربوطه با `DROP ... UQ` + ساخت `UX_*` است).
- روی دیتابیس زنده اجرا و تأیید شد: شرکت ۳ (تست) اکنون ۱۱ حساب، ۴ کل، ۵ معین، ۵ تفصیلی، ۲ گروه (مشتریان/تأمین‌کنندگان)، ۴ قانون مالیات، ۲ انبار، ۵ کالای طلا، بانک/صندوق/نرخ ارز و ۳ طرف‌حساب لینک‌شده به تفصیلی‌های حسابداری دارد.

### کنترل چندشرکتی ارز
- در دیتابیس `TarazinMaster` برای شرکت‌های ۱ و ۳ کیف‌پول‌های `USD/EUR/AED` و دارایی‌های `XAU-18/SIKKEH-EMAMI` مستقل وجود دارد.
- یکتایی قدیمی سراسری با ایندکس‌های `UX_Wallets_Company_Currency` و `UX_AssetHoldings_Company_Item` جایگزین شده است.
- تمام مسیرهای `WalletMovementManual`، `FxTransactionCreate`، `FxCombinedCreate` و `ConvertExecute` در خواندن/نوشتن موجودی به `central.fn_MobileCompanyId()` محدود هستند.
- هیچ رکورد موقت تست ارزی یا خزانه‌ای در دیتابیس باقی نمانده است.

### وضعیت محیط
- startup زنجیرهٔ `Ensure → Seed → Backfill → MobileSecurity` بدون خطای SQL بالا آمد.
- فید `TABLOTALA_FR` در محیط محلی timeout می‌شود؛ scheduler آن را به‌عنوان خطای منبع ثبت می‌کند و startup/سایر فیدها ادامه می‌یابند.
- بیلد Web و Data با ۰ هشدار و ۰ خطا پاس شد. بیلد MAUI Android با ۰ هشدار و ۰ خطا پاس شد. بیلد MAUI Windows با ۰ خطا پاس شد؛ دو هشدار `MSB3277` ناشی از conflict وابستگی `Microsoft.AspNetCore.WebUtilities` در Stimulsoft 2024.3.2 باقی است و باید با ارتقای سازگار Stimulsoft یا تثبیت binding در CI بررسی شود. هشدار `TZN0001` مربوط به layout فیزیکی Build بود و assetها در `filtered.layout.resfiles` ثبت شده‌اند؛ publish/pack و تست دستگاهی Windows/Android هنوز باید در device lab تکرار شود.

*This modular breakdown is saved as **Handoff_ModuleBreakdown.md** for quick reference and to avoid repeated deep‑dive reviews.*