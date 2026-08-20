# ADR-004: MAUI Blazor Hybrid host — one shared UI, two hosts

- **Status**: Accepted, security amendment 2026-08-18, TLS amendment 2026-08-20, simplification amendments 2026-08-20(v2, v3)
- **Date**: 2026-08-12
- **Relates to**: PRD v2.1 (Blazor Hybrid), ADR-001 (shared core), ADR-003 (contracts)
- **Technical story**: adds a native desktop/mobile shell on top of the shared UI.

> **Simplification amendment 2026-08-20 v2 (تصمیم مالک پروژه):** مدل broker
> (registry مشتری با `CustomerGuid`، nonce/replay، نشست‌های bearer با
> refresh/revoke، و principalهای موقت SQL از جنس `tz_m_*` با RLS مخصوص موبایل)
> به‌طور کامل کنار گذاشته شد. جایگزین: یک endpoint منفرد `POST /api/mobile/login`
> که نام کاربری/رمز را دقیقاً مثل ورود وب با PBKDF2 بررسی می‌کند و پس از ورود
> موفق، همان رشتهٔ اتصال سرور (`appsettings.json`/secret استقرار) را
> رمزگذاری‌شده با AES-256-CBC تحت کلید مشتق از رمز ورود (SHA-256) برمی‌گرداند؛
> MAUI با همان رمز تایپ‌شده کلید را مشتق و در حافظه رمزگشایی می‌کند و همان مسیر
> مستقیم `DbService` را اجرا می‌کند. دلیل تصمیم: سادگی عملیاتی و حذف زنجیرهٔ
> صدور principal که دیباگ استقرار را دشوار می‌کرد. پیامد امنیتی پذیرفته‌شده:
> MAUI با همان هویت اتصال سرور کار می‌کند و مرز امنیتی به HTTPS + احراز هویت
> کاربر + عدم ذخیره‌سازی محلی تکیه دارد. تاریخچهٔ قبلی این ADR بازنویسی نمی‌شود.

> **Simplification amendment 2026-08-20 v3 (تصمیم مالک پروژه):** خودِ ورود هم از
> API جدا شد و محلی/مشترک شد. API فقط یک نقش دارد: bootstrap یک‌بارهٔ اتصال —
> `POST /api/mobile/connection` همان اعتبار نام کاربری/رمز را سمت سرور می‌سنجد و
> رشتهٔ اتصال رمزگذاری‌شده را برمی‌گرداند؛ سپس ورود واقعی در هر دو هاست از یک مسیر
> (`AuthService` → PBKDF2 → `DbService`) اجرا می‌شود و UI در هر دو پروژه دقیقاً
> یکسان عمل می‌کند. API در پروژهٔ Web می‌ماند. این amendment جایگزین جزئیات v2
> دربارهٔ «ورود از طریق API» می‌شود.

> **TLS amendment 2026-08-20 (تصمیم مالک پروژه):** بند «بدون bypass گواهی» این ADR
> ملغی می‌شود. اتصال SQL در همهٔ محیط‌ها با `Encrypt=true` و
> `TrustServerCertificate=true` ساخته می‌شود: رمزنگاری کانال الزامی می‌ماند، اما
> اعتبارسنجی گواهی SQL Server غیرفعال است تا گواهی خودامضای SQL محلی خطای TLS
> («گواهی SQL Server توسط این دستگاه تأیید نمی‌شود») ایجاد نکند. پیامد: اصالت
> سرور SQL احراز نمی‌شود؛ برای استقرارهای حساس ریسک را با شبکه مقایسه کنید.

> **Security amendment (v2 — قانون پروژه، به درخواست مالک محصول):** اشتراک UI و
> مسیر `DbService` حفظ شده است، اما MAUI دیگر connection string دائمی را
> embed/read نمی‌کند و initialization دیتابیس را اجرا نمی‌کند. پیکربندی آن فقط
> endpoint عمومی HTTPS است. **رشتهٔ اتصال SQL فقط از API و فقط به صورت
> رمزگذاری‌شده دریافت می‌شود** (`POST /api/mobile/connection/encrypted`، AES
> per-session با کلید مشتق از توکن جلسه)، در حافظهٔ MAUI رمزگشایی و به UI مشترک
> (`DbService`) برای اجرا داده می‌شود. مسیر credential خام/کوتاه‌عمر برای اتصال
> SQL حذف شده و `UseEncryptedMaster=false` در استارتاپ با خطا رد می‌شود. بندهای
> قدیمی این ADR دربارهٔ connection configuration مشترک یا bootstrap از MAUI با
> این amendment جایگزین می‌شوند.

---

## Context

ADR-001 established one Blazor Server project (`Tarazin.Web`) hosting all seven
modules with the UI built in MudBlazor. The product owner wants the same
application as a **native desktop/mobile app** (Windows, Android, iOS, macOS)
without duplicating any UI code — the classic **MAUI Blazor Hybrid** scenario
(one Razor component library, two hosts: browser + WebView).

MAUI Blazor Hybrid renders Blazor components in a `BlazorWebView` with the
components executing **in-process on the native runtime** (no server, no SignalR).
That means any component/service that works in-process (MudBlazor UI, Dapper,
DI) can be shared as-is; only host plumbing differs.

## Decision

Restructure the repo into **five projects** (see ADR-005 for the Share/Data
split rationale):

| Project | Kind | Role |
|---|---|---|
| `Tarazin.Share` | Class library | Models/contracts only (`Tarazin.Models`), no dependencies |
| `Tarazin.Data` | Class library | Data layer: `DbService`, `ScriptCatalog` (embedded scripts `Tarazin.Scripts.{schema}.{name}.sql`), `AuditService`, `PasswordHasher`, `ICurrentUser`, `TarazinDbInitializer` |
| `Tarazin.Ui` | Razor Class Library (RCL), `RootNamespace=Tarazin` | ALL UI: `Modules/`, `Layout/`, `Services/` (`UserSession`, `AuthService`, `AddTarazinUiServices`), `App.razor` (Router + MudBlazor providers + init) |
| `Tarazin.Web` | ASP.NET Core Blazor Server | Thin web shell: `Program.cs`, `Pages/_Host.cshtml`, `appsettings.json` |
| `Tarazin.Maui` | .NET MAUI (Blazor Hybrid) | Thin native shell: `MauiProgram.cs`, `MainPage.xaml` (BlazorWebView → `Tarazin.App`), `wwwroot/index.html`, `Platforms/`, `Resources/` |

Key mechanisms:

1. **Shared services** — `AddTarazinUiServices()` in `Tarazin.Ui/Services/ServiceCollectionExtensions.cs` registers UI services (`UserSession`, `ICurrentUser`, `AuthService`) and delegates to `AddTarazinDataServices()` in `Tarazin.Data` (`ScriptCatalog` singleton self-loading embedded scripts, `DbService`, `AuditService`). Both hosts call it.
2. **Server-only startup** — `TarazinDbInitializer.EnsureInitializedAsync(IServiceProvider)` در Web اجرا و `_Ensure.sql` → `_Seed.sql` → bootstrap admin را با secretهای server-side انجام می‌دهد. MAUI provider مجوز initialization/master ندارد.
3. **Scripts as embedded resources** — `Tarazin.Data/Scripts/**/*.sql` are `EmbeddedResource` in `Tarazin.Data` (`Tarazin.Scripts.{schema}.{name}.sql`); `ScriptCatalog` loads them from its own assembly so the packaged MAUI app never needs a content root. Files remain in the repo for editing/tooling (`tools/cross-schema-scan.sh`).
4. **Shared static assets** — `Tarazin.Ui/wwwroot/css/app.css` is served by both hosts at `_content/Tarazin.Ui/css/app.css` (web static assets + BlazorWebView RCL assets).
5. **Namespaces** — models `Tarazin.Models` (assembly `Tarazin.Share`); data `Tarazin.Data`; RCL root `Tarazin`; web host `Tarazin.Web`; MAUI `Tarazin.Maui` — no ambiguity across assemblies.
6. **MAUI config and encrypted connection-string delivery** — `Tarazin.Maui/appsettings.json` فقط `ServerEndpoint` عمومی HTTPS را دارد (amendments 2026-08-20 v2/v3). ورود در هر دو هاست از یک مسیر (`AuthService`/PBKDF2 محلی) اجرا می‌شود؛ `ApiConnectionSession` فقط در شروع سرد یک‌بار نام کاربری/رمز را به `POST /api/mobile/connection` می‌فرستد تا رشتهٔ اتصال سرور — رمز‌شده با AES-256-CBC تحت کلید مشتق از رمز ورود (SHA-256) — گرفته و در همان حافظه رمزگشایی شود و به `DbService` مشترک برسد. هیچ کلید، token یا شناسهٔ مشتری در بستهٔ MAUI ذخیره نمی‌شود.

## Consequences

- **One UI, two products**: every new page/module is written once in
  `Tarazin.Ui` and instantly available in the browser and the native app.
- **Platform verification (important)**: مسیر مستقیم `Microsoft.Data.SqlClient` و broker باید برای هر TFM/runtime هدف در CI و E2E همان پلتفرم build و اجرا شود. هیچ targetی اجازه ندارد برای دورزدن ناسازگاری، credential دائمی یا bypass گواهی اضافه کند.
- **Scoped ≠ per-circuit in MAUI**: in the MAUI host there are no Blazor
  circuits; scoped services behave like app-wide singletons (fine for a
  single-user desktop app).
- **CI**: web build (ubuntu) + MAUI build (windows-latest with
  `dotnet workload install maui`, `-f net8.0-windows10.0.19041.0`) +
  cross-schema scan.

## Alternatives considered

- Duplicate UI in a separate MAUI project: rejected — the whole point of
  Blazor Hybrid is one component set.
- MAUI app pointing its WebView at the hosted web URL: rejected — offline /
  native integration, and it would resurrect a client-server data layer.
- Keeping everything in one csproj (MAUI can't host an ASP.NET Core server
  project): not possible — RCL is the required sharing unit.
