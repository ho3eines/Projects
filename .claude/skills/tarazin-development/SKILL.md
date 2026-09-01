---
name: tarazin-development
description: >
  راهنمای الزامی کدنویسی پروژهٔ «ترازین» — MANDATORY guide for any work on this
  codebase (Tarazin.Share / Tarazin.Data / Tarazin.Ui / Tarazin.Web / Tarazin.Maui).
  Read this BEFORE creating or editing any .razor page, component, dialog, service,
  permission, navigation item, or .sql script. Covers the 5-project dependency
  rules, the DbService + named embedded TSQL script data layer, module folder
  layout, MudDialog patterns, App Bar / NavMenu (TarazinModules) navigation,
  MudBlazor 9.8.0 version traps (MUD0002, ValidateAsync, ActivatorContent), the
  4-layer RBAC model, session and active company/fiscal-year context, RTL theme
  and fonts, the print/PDF pipeline (QuestPDF), code style rules, build/test
  commands, and copy-paste patterns for CRUD tables, forms, menus, and dialogs.
---

# SKILL.md — توسعهٔ «ترازین» (راهنمای کدنویسی)

> ## ⚖️ قانون الزامی
> **قبل از هر تغییر، ساخت صفحه/کامپوننت/مودال، افزودن سرویس یا دریافت هر پارامتر جدید، اول این سند را کامل بخوان.** هر چیزی که اینجا نوشته شده با کد واقعی پروژه هماهنگ است (بررسی‌شده) و هر تغییر باید **مطابق این اسکیل** باشد. اگر بین این سند و کدی که می‌بینی اختلاف بود، **این سند را به‌روز کن** و طبق واقعیتِ کد رفتار کن.

راهنمای جامع توسعه روی این کدبیس — به‌خصوص **بخش ۶ (MudBlazor 9.8.0)** که پر از تله‌های نسخه‌ای است.

---

## ۱. معماری و جریان وابستگی

پنج پروژه با وابستگی **یک‌طرفه**:

```
Tarazin.Share  (مدل‌ها/ثابت‌ها — بدون وابستگی)
      ↓
Tarazin.Data   (Dapper + اسکریپت‌های TSQL نامدار Embedded)
      ↓
Tarazin.Ui     (RCL مشترک: صفحات Razor، سرویس‌ها، تم، MudBlazor)
      ↓
Tarazin.Web    (Blazor Server)   و   Tarazin.Maui (Blazor Hybrid)
```

- **قانون طلایی:** هیچ پروژه‌ای نباید به پروژهٔ بالاتر از خود ارجاع دهد (یک‌طرفه). ارجاع `Tarazin.Maui` از `Tarazin.Ui` ممنوع است (چرخه).
- هاست (Web/Maui) فقط DI را راه‌اندازی می‌کند: `AddTarazinUiServices()` + تنظیمات مخصوص هاست. منطق کسب‌وکار هرگز در هاست‌ها نیست.
- هر دو هاست **همان UI مشترک** (`App.razor` از Tarazin.Ui) را اجرا می‌کنند — یک صفحه یک‌بار نوشته می‌شود و در وب و موبایل یکی است.

---

## ۲. لایهٔ داده (Tarazin.Data)

### اصل اصلی: «هیچ SQL خام در Razor نیست»
همهٔ SQL در اسکریپت‌های نامدار Embedded است: `Tarazin.Data/Scripts/{schema}/{Name}.sql` → در استارت‌آپ توسط `ScriptCatalog` لود و با کلید `(Schema, ScriptName)` در دسترس قرار می‌گیرد.

### API اصلی `DbService` (تزریق کن: `@inject DbService Db`)
| متد | کاربرد |
|-----|--------|
| `QueryAsync<T>(schema, script, parameters?, ct)` | لیست ردیف‌ها (Dapper → `IReadOnlyList<T>`) |
| `QueryFirstOrDefaultAsync<T>(schema, script, parameters?, ct)` | یک ردیف یا null |
| `ExecuteAsync(schema, script, parameters?, ct)` | عملیات تغییردهنده + **ثبت خودکار ممیزی** |
| `ExecuteReturningAsync<T>(schema, script, parameters?, ct)` | عملیات atomic که مقدار تولیدشده برمی‌گرداند + ممیزی |
| `ScalarAsync(schema, script, parameters?, ct)` | یک مقدار تکی |
| `TestConnectionAsync(ct)` | آزمون اتصال (صفحهٔ /diag) |

- پارامترها با anonymous object: `new { FromDate = date, OnlyNonZero = 1 }` — Dapper نگاشت می‌کند.
- `ExecuteAsync`/`ExecuteReturningAsync` خودکار ردیف ممیزی ثبت می‌کنند؛ لازم نیست دستی ثبت کنی.
- خطاها با `SafeFailure`/`Describe` به پیام امن تبدیل می‌شوند — **هرگز متن خام استثنا را به UI نده**.

### قوانین اسکریپت‌ها
1. هر اسکریپت در پوشهٔ اسکیمهٔ خودش (`accounting/`، `currency/`، ...) — ماژول فقط اسکریپت‌های اسکیمهٔ خودش را صدا می‌زند (چک با `tools/cross-schema-scan.sh`).
2. اسکریپت‌ها کاملاً schema-qualified: `[central].[FiscalYears]`، نه `FiscalYears`.
3. اگر اسکریپت به اسکیمهٔ دیگری دسترسی دارد، در کامنت هدر صریحاً اعلام کن (مثل `DocumentInsert.sql` → `central.FiscalYears`).
4. نام ستون‌های خروجی باید با aliasهای مدل‌ها در `Tarazin.Share` یکی باشد.
5. فایل‌های `_Ensure.sql`/`_Seed.sql` در هر اسکیمه ساختار/دادهٔ اولیه را می‌سازند.

### مثال استفاده از صفحهٔ Razor
```csharp
var rows = await Db.QueryAsync<InventoryMovement>(
    "inventory", "MovementInsert", new { ItemId = id, Quantity = qty });
var id = await Db.ExecuteReturningAsync<int>("accounting", "DocumentInsert", new { ... });
```

---

## ۳. لایهٔ UI (Tarazin.Ui) — ساختار صفحات

### چیدمان ماژول
```
Tarazin.Ui/Modules/{Module}/
  ├── Pages/        → {Dashboard, Entry, Special, Reports, Settings}.razor
  ├── Components/   → کامپوننت‌های خصوصی ماژول (دیالوگ‌ها اینجا)
  ├── Services/     → سرویس‌های ماژول (در صورت نیاز)
  └── _Imports.razor → فقط وقتی Components داری: `@using Tarazin.Modules.{Module}.Components`
```

**نکتهٔ مهم (کنوانسیون پروژه):** صفحات ماژول کامپوننت‌های همان ماژول را با نام ساده صدا می‌زنند؛ برای این کار هر ماژولی که پوشهٔ `Components/` دارد، باید `_Imports.razor` در همان سطح ماژول داشته باشد: `@using Tarazin.Modules.{Module}.Components` (نمونه: `Modules/Currency/_Imports.razor`، `Modules/Bi/_Imports.razor`). بدون آن، کامپوننت پیدا نمی‌شود (CS0246).
الگوی ثابت هر ماژول: `Dashboard` / (لیست روز) / `Entry` (ثبت) / `Special` (عملیات ویژه) / `Reports` / `Settings`.

### افزودن یک صفحهٔ جدید (دستورالعمل گام‌به‌گام)
> **ⓘ قبل از ساخت هر صفحهٔ Razor** اول `.claude/skills/tarazin-ui-ux/SKILL.md` را بخوان — کاتالوگ کامپوننت‌های مشترک (§‌۲) و اسکلت‌های کپی‌پذیر صفحه (لیست/CRUD، فرم، داشبورد، گزارش — §‌۳) آنجاست؛ همین سند فقط معماری/داده/RBAC را پوشش می‌دهد.
1. **فایل صفحه:** `Modules/{Module}/Pages/{Name}.razor` با `@page "/{module}/{name}"` و `@inject` سرویس‌ها + `Db`.
2. **دسترسی:** اگر دسترسی جدید لازم است، کلید را در `Tarazin.Share/Permissions.cs` (در `TarazinPermissions`) تعریف کن؛ نقش‌های پیش‌فرض در `TarazinRoles`؛ seed در استارت‌آپ همگام می‌شود.
3. **ناوبری:** آیتم را در `Tarazin.Ui/Theme/TarazinModules.cs` → `All` اضافه کن (عنوان/آیکون/دسترسی). `HideInNav: true` برای صفحاتی که از داخل صفحات دیگر باز می‌شوند (اما گارد مسیر دارند).
4. **سرویس:** اگر سرویس جدید داری، در `Tarazin.Ui/Services/ServiceCollectionExtensions.cs` ثبت کن (scope: `AddScoped`).
5. **داده:** اسکریپت را در `Tarazin.Data/Scripts/{schema}/{Name}.sql` بنویس و با `Db.QueryAsync`/`ExecuteAsync` صدا بزن.
6. **صفحه را با `PageHeader` شروع کن** (عنوان/زیرعنوان/چشمک) و RTL را رعایت کن.

### کامپوننت‌های مشترک (بازاستفاده کن، نساز)
| کامپوننت | کاربرد |
|----------|--------|
| `PageHeader` | سربرگ صفحه: `Title`، `Subtitle`، `Eyebrow` |
| `StatCard` | کارت آمار داشبورد |
| `ModuleSubNav` | زیرمنوی ماژول (از `TarazinModules` خودکار) |
| `EntityEditorDialog` | دیالوگ استاندارد ویرایش موجودیت (چندکِیند) |
| `AccountPickerField` / `AccountPickerDialog` | انتخاب حساب (جداول پایه) |
| `Chart/BaseColForm` و ... | فرم‌های جداول پایه (وراثت) |

---

## ۴. مودال‌ها (MudDialog) — الگوی کامل

### الف) ساخت کامپوننت دیالوگ
فایل `Modules/{Module}/Components/{Name}Dialog.razor` (در **Components**، نه Pages):

```razor
@inject DbService Db
@inject UserSession Session
@inject ISnackbar Snackbar

<MudDialog>
    <DialogContent>
        <MudForm @ref="_form" @bind-IsValid="_isValid">
            <MudGrid Spacing="2">
                <MudItem xs="12">
                    <MudTextField Label="عنوان" @bind-Value="_model.Title" Required="true"
                                  RequiredError="عنوان الزامی است." Variant="Variant.Outlined" />
                </MudItem>
            </MudGrid>
        </MudForm>
    </DialogContent>
    <DialogActions>
        <MudButton Variant="Variant.Text" Color="Color.Default" OnClick="Cancel" Disabled="_busy">
            انصراف
        </MudButton>
        <MudButton Variant="Variant.Filled" Color="Color.Primary" StartIcon="@Icons.Material.Filled.Save"
                   OnClick="SaveAsync" Disabled="_busy">
            ذخیره
        </MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter] private IMudDialogInstance MudDialog { get; set; } = default!;
    [Parameter, EditorRequired] public MyModel Model { get; set; } = default!;
    private MudForm? _form;
    private bool _isValid;
    private bool _busy;

    private void Cancel() => MudDialog.Cancel();

    private async Task SaveAsync()
    {
        if (_busy || _form is null) return;
        await _form.ValidateAsync();          // نه Validate() — منسوخ است
        if (!_isValid) return;
        _busy = true;
        try
        {
            await Db.ExecuteAsync("schema", "ScriptName",
                new { Title = Model.Title.Trim(), UpdatedBy = Session.UserName });
            Snackbar.Add("ذخیره شد.", Severity.Success);
            MudDialog.Close(DialogResult.Ok(true));
        }
        catch (Exception ex) { Snackbar.Add(ex.Message, Severity.Error); }
        finally { _busy = false; }
    }
}
```

### ب) باز کردن دیالوگ از صفحه
```csharp
@inject IDialogService Dialog

// ارسال پارامتر به دیالوگ (کلیدها = نام [Parameter]های دیالوگ):
var dlg = await Dialog.ShowAsync<MyDialog>("عنوان دیالوگ", new DialogParameters
{
    ["Model"] = item
}, new DialogOptions
{
    MaxWidth = MaxWidth.Small,
    FullWidth = true,
    CloseButton = true,
    CloseOnEscapeKey = true
});

var result = await dlg.Result;
if (result is { Canceled: false })
    await ReloadAsync();   // بعد از موفقیت، لیست را تازه کن
```

### ج) تأیید حذف (MessageBox)
```csharp
var confirmed = await Dialog.ShowMessageBoxAsync(
    "تأیید حذف", $"آیا از حذف «{row.Title}» مطمئن هستید؟",
    yesText: "حذف", cancelText: "انصراف");
if (confirmed is not true) return;
await Db.ExecuteAsync("schema", "DeleteScript", new { Id = row.Id, UpdatedBy = Session.UserName });
Snackbar.Add("حذف شد.", Severity.Success);
```

### د) نکات مودال
- نمونه‌های واقعی برای رجوع: `EntityEditorDialog` (چندکِیند با `switch`)، `RoleEditorDialog`، `CompanyFormDialog`، `AccountGroupManagerDialog`، `RateEditDialog`.
- اعتبارسنجی داخل دیالوگ همیشه `MudForm` + `ValidateAsync()` + `@bind-IsValid`.
- دکمه‌ها فارسی («انصراف»/«ذخیره»/«حذف»)، `_busy` در حین ذخیره، و بعد از موفقیت `MudDialog.Close(DialogResult.Ok(...))`.

---

## ۵. نوبار و ناوبری (App Bar + Drawer)

دو لایهٔ ناوبری داریم و هر دو از کاتالوگ واحد `TarazinModules.All` تغذیه می‌شوند:

### الف) نوار بالا (App Bar) — `Layout/MainLayout.razor`
ساختار از چپ به راست (RTL):
- دکمهٔ **منو** → باز/بستن Drawer.
- **چیپ «شرکت | سال مالی»** — یک `MudMenu` با `ActivatorContent`؛ کلیک را **خودت** وصل کن:
  ```razor
  <MudMenu ActivatorContent="context => @<MudChip OnClick="() => context.ToggleAsync()" ...>@_envLabel</MudChip>">
      @foreach (var year in _years) { <MudMenuItem OnClick="() => SelectYearAsync(year)">@year.Title</MudMenuItem> }
  </MudMenu>
  ```
  ⚠️ در MudBlazor 9، `ActivatorContent` **کلیک خودکار ندارد** — بدون `context.ToggleAsync()` منو هرگز باز نمی‌شود.
- **سوئیچ حالت تیره** (`Prefs.IsDarkMode`).
- **منوی آواتار کاربر** (نام/نقش + تنظیمات + خروج) — همان `MudMenu` + `ToggleAsync`.

### ب) منوی کناری (Drawer) — `Layout/NavMenu.razor`
```razor
<MudNavMenu Class="tz-nav" Color="Color.Secondary">
    <MudNavLink Href="/" Match="NavLinkMatch.All">خانه</MudNavLink>
    <MudNavLink Href="/diag">عیب‌یابی اتصال</MudNavLink>
    @if (!Session.IsAuthenticated) { <MudNavLink Href="/login">ورود</MudNavLink> }

    @foreach (var mod in TarazinModules.All)
    {
        @if (Session.CanView(mod.Key))
        {
            <MudNavGroup Title="@mod.Title" Icon="@mod.Icon" Expanded="IsExpanded(mod)">
                @foreach (var item in mod.Items)
                {
                    @if (!item.HideInNav && Session.HasPermission(item.Permission))
                    {
                        <MudNavLink Href="@item.Url" Icon="@item.Icon">@item.Title</MudNavLink>
                    }
                }
            </MudNavGroup>
        }
    }
</MudNavMenu>
```

### ج) قانون نوبار
- **برای افزودن آیتم به منو فقط `TarazinModules.All` را ویرایش کن** — Drawer و زیرمنو و گارد مسیر همگی خودکار از همین کاتالوگ ساخته می‌شوند. هرگز `NavMenu.razor`/`MainLayout.razor` را برای آیتم‌های جدید دستی ویرایش نکن.
- `HideInNav: true` → در منو نمی‌آید ولی گارد مسیر دارد (صفحه‌هایی که از داخل صفحات دیگر باز می‌شوند).

---

## ۶. MudBlazor 9.8.0 — قوانین و تله‌های نسخه‌ای ⚠️

اینها با Reflection/decompile روی خود MudBlazor 9.8.0 تأیید شده‌اند. رعایت نکنی، کد **بی‌صدا کار نمی‌کند** (هشدار MUD0002) یا کامپایل نمی‌شود.

| قدیمی/غلط | درست در v9 | اثر |
|-----------|-----------|-----|
| `OnChange` روی `MudSelect` | `ValueChanged` (EventCallback) | هندلر قبلاً هرگز صدا زده نمی‌شد |
| `OnSelectedValueChanged` روی `MudSelect` | `ValueChanged` | همان |
| `MudForm.Validate()` | `MudForm.ValidateAsync()` | `Validate()` منسوخ است (CS0618) |
| `MudMenu` با `ActivatorContent` بدون کلیک | `@onclick="() => context.ToggleAsync()"` روی محتوا | در v9 دیوارهٔ ActivatorContent **کلیک خودکار ندارد**؛ باید به `MenuContext` وصل کنی |
| `AlignItems` روی `MudGrid` | حذف کن (پارامتر وجود ندارد) | بی‌صدا نادیده گرفته می‌شد |
| `PanelClass` روی `MudTabs` | `TabPanelsClass` | padding پنل اعمال نمی‌شد |
| `DisableGutters` روی `MudList` | `Gutters="false"` | نادیده گرفته می‌شد |
| `HelperText` روی `MudSwitch` | `MudText` جدا زیر سوئیچ | توضیح نمایش داده نمی‌شد |
| `Title` روی `MudIconButton` | دورش `MudTooltip` بگذار | tooltip نداشت |
| `Rows` روی `MudTextField` | `Lines` | ارتفاع textarea درست نمی‌شد |
| `StartIcon` روی `MudChip` | `Icon` | آیکون نادیده گرفته می‌شد |
| `Wrap="Wrap"` | `Wrap="Wrap.Wrap"` (enum `MudBlazor.Wrap`) | خطای کامپایل |
| `Typo="h6"` | `Typo="Typo.h6"` | پیشوند enum لازم است |
| `Size.XSmall` | `Size.Tiny` / `Size.Small` | در این نسخه XSmall نیست |

**قانون سرانگشتی:** هر attribute که روی کامپوننت MudBlazor شک داری، با یک پروب Reflection (یا سورس گیتهاب نسخهٔ v9.8.0) تأیید کن — هشدارهای MUD0002 یعنی رفتار خراب، نه فقط زیبایی.

---

## ۷. RBAC و دسترسی‌ها — ۴ لایهٔ اعمال

دسترسی‌ها فقط در یک جا تعریف می‌شوند و در ۴ لایه اعمال می‌شوند:

### منبع واحد (تعریف)
`Tarazin.Share/Permissions.cs` → `TarazinPermissions` (کلیدهای `{module}.{action}`) + `TarazinRoles` (نقش‌های پیش‌فرض). در استارت‌آپ با `[central].[Permissions]/[Roles]` همگام می‌شود.

### لایهٔ ۱ — فیلتر منو (NavMenu)
فقط آیتم‌هایی نمایش داده می‌شوند که `Session.HasPermission(item.Permission)` باشد (کد بالا).

### لایهٔ ۲ — گارد مسیر (MainLayout)
```csharp
var required = TarazinModules.RequiredPermissionFor(path);
_denied = required is not null && !Session.HasPermission(required);
_denyMessage = !Session.IsAuthenticated
    ? "برای دسترسی به این بخش ابتدا وارد شوید."
    : "شما دسترسی لازم برای این بخش را ندارید. ...";
```
مسیرهای عمومی (`/`، `/login`، `/diag`) و مسیرهای ناشناخته → بدون محافظت (`null`). وقتی `_denied` شود، دیالوگ «دسترسی ندارید» نشان داده می‌شود.

### لایهٔ ۳ — چک داخل صفحه (دکمه‌های حساس)
```csharp
@if (Session.HasPermission(TarazinPermissions.DocumentEdit))
{
    <MudButton Variant="Variant.Filled" Color="Color.Primary" OnClick="EditAsync">ویرایش</MudButton>
}
```

### لایهٔ ۴ — سطح داده (اسکریپت‌ها)
اسکریپت‌های کسب‌وکار خودشان اعتبارسنجی وضعیت را دارند (مثلاً `DocumentInsert` فقط وضعیت‌های مجاز سند را می‌پذیرد؛ `FeedApply` اجازهٔ ورود مستقیم آنلاین به معامله را نمی‌دهد). UI همیشه بعد از خطا پیام امن `Db.Describe` را نشان می‌دهد.

### افزودن دسترسی جدید
1. ثابت در `TarazinPermissions` (مثلاً `MyModuleExtra = "mymodule.extra"`).
2. اگر نقش پیش‌فرضی باید داشته باشد، در `TarazinRoles` اضافه کن (seed خودکار در استارت‌آپ).
3. برای گارد مسیر، آیتم را در `TarazinModules.All` با همان `Permission` ثبت کن.

---

## ۸. نشست، احراز هویت و محیط فعال

- `UserSession` (Scoped): کاربر، نقش، دسترسی‌ها + `ActiveCompanyId`/`ActiveFiscalYearId`. بازیابی نشست بعد از رفرش در `App.razor` → `OnAfterRenderAsync` → `Session.RestoreAsync()`.
- `AuthService`: PBKDF2 (۱۰۰k دور + مقایسهٔ زمان‌ثابت) — رمز هرگز plain نیست.
- **محیط فعال (شرکت + سال مالی):** `AccountingContextService` + `SetActiveContextAsync` → بعد از تغییر محیط، صفحه را با `Nav.NavigateTo(Nav.Uri, forceLoad: true)` دوباره بارگذاری کن (الگوی جاافتاده در MainLayout) — چون صفحات فقط در لحظهٔ رندر، `Session.ActiveFiscalYearId` را می‌خوانند.
- **تغییر محیط در UI:** از چیپ «شرکت | سال مالی» در نوار بالا (MudMenu + `context.ToggleAsync`).

---

## ۹. تم، RTL و فونت

- تم: `Tarazin.Ui/Theme/TarazinTheme.cs` → `MudTheme` فارسی (پالت کاغذی + سبز + طلایی، حالت تیره).
- RTL: در `App.razor` → `<MudRTLProvider RightToLeft="true">`؛ در HTML هاست `dir="rtl"`؛ در MAUI، `MainPage.xaml` عمداً `LeftToRight` می‌ماند (آینه‌ای شدن WebView).
- فونت: Vazirmatn (گوگل‌فونتز در CSS برای UI؛ در PDF از TTF جاسازی‌شدهٔ `VazirmatnFontRegistrar` — هیچ وابستگی به فونت سیستمی نیست).
- حالت تیره: `UiPreferences` (در حافظه) + سوئیچ نوار بالا.

---

## ۱۰. گزارش‌ها و چاپ (موتور چاپ عمومی — QuestPDF)

> **⚠️ اسکیل جداگانهٔ گزارش‌سازی:** برای ساخت/ویرایش هر صفحهٔ گزارش، دیالوگ چاپ یا خروجی PDF، اول `.claude/skills/tarazin-reporting/SKILL.md` را بخوان — «یک روال واحد» برای همهٔ گزارش‌ها: اسکلت صفحه + `ReportPrintDialog` + `PdfReportService.BuildTablePdf` + `PdfFileNames`.

- **موتور واحد:** همهٔ چاپ‌ها (سند، فاکتور، چک، گزارش‌های ماژولی، BI) با **QuestPDF** (`PdfReportService`) و قالب‌های قابل‌طراحی (`PrintTemplateService`/صفحهٔ دیزاینر) انجام می‌شوند.
- **صفحهٔ `/bi/reports`:** کاتالوگ گزارش‌های BI از اسکریپت‌های نامدار + چاپ/PDF با موتور چاپ عمومی (`TemplatePrintDialog`).
- **فونت:** همیشه «Vazirmatn» از TTF جاسازی‌شده (`VazirmatnFontRegistrar.Register()` — idempotent؛ در static ctorِ `PdfReportService` و استارتاپ).

---

## ۱۱. قواعد نگارش کد

1. **نام‌گذاری:** کلاس‌ها/متدها انگلیسی PascalCase؛ عنوان‌ها/متن‌های UI فارسی. کامنت‌ها فارسی (توضیح «چرا»، نه «چی»).
2. **هیچ SQL خام در Razor** — همیشه اسکریپت نامدار + `DbService`.
3. **هیچ متن خطای خام استثنا** در UI — از پیام‌های امن (`Db.Describe`) استفاده کن.
4. **هیچ secret** در کد/appsettings — از env (`TARAZIN_SQL_CONNECTION`) یا secret store.
5. **صفحات RTL** و با `PageHeader` شروع شوند؛ `Typo.Typo.*` با پیشوند enum.
6. **نال‌پذیری:** `_form!` وقتی `@ref` بعد از رندر ست می‌شود؛ `?.` برای نال.
7. **ماژول‌ها مستقل:** ماژول فقط از اسکیمهٔ خودش اسکریپت می‌خواند؛ اشتراک بین ماژول‌ها از اسکیمهٔ `central`.
8. **اعتبارسنجی فرم:** `ValidateAsync()` + `@bind-IsValid`.
9. **نوار وضعیت:** بعد از عملیات موفق `Snackbar.Add(..., Severity.Success)`؛ خطاها `Severity.Error`.
10. **دیالوگ‌ها در `Modules/{Module}/Components/`** بگذار، نه Pages.

---

## ۱۲. بیلد و تست

> **⚠️ قانون طلایی بیلد:** بعد از **هر تغییر در `Tarazin.Ui`** (صفحهٔ Razor، کامپوننت، سرویس، تم، …) حتماً `dotnet build Tarazin.Web/Tarazin.Web.csproj` را بزن.
> `dotnet test` یا بیلدِ تکیِ `Tarazin.Ui` فقط `Tarazin.Ui/bin` را به‌روز می‌کند؛ کپیِ `Tarazin.Web/bin` **تازه نمی‌شود** و سروری که با `dotnet run --no-build` بالا می‌آید، همان کد کهنه را سرو می‌کند (باگ «ستون‌ها درست شد ولی هدر نه`). — **اسکریپت یک‌جا زنجیرهٔ کامل:** `bash tools/run-checks.sh` (تست + بیلد وب + گارد stale + گاردهای pymupdf: **۴ب هدر راست‌چین**، **۴ج A5L قالب چاپ**، **۴د A5L جدول عمومی/BuildTablePdf**، **۴هـ بدون هدر/QR مستقل**، **۴و چندصفحه‌گی BuildTablePdf**، **۴ز A5L چندصفحه BuildInvoicePdf**، **۴ط هدر فقط روی صفحاتِ دارای ردیف**). گیت pymupdf اسکریپت `tools/check-rtl-headers.sh` (حالت‌ها `all|generic|a5l|table|noheader|table-many|invoice-a5l-many|table-summary-pages`) است که فایل‌های dump تست `Dump_rtl_header_pdfs_for_pymupdf` را می‌خواند (`%TEMP%/tarazin-pdf/rtl-headers`). گام‌های pymupdf بدون نصب pymupdf رسماً SKIP می‌شوند نه Fail (محلی اختیاری)؛ در CI (Python 3.12 + pymupdf) الزامی‌اند و چهار گارد به‌صورت **step جدا و نام‌دار** هم اجرا می‌شوند: A5L قالب (`Run A5L template guard` → `bash tools/check-rtl-headers.sh a5l`)، چندصفحه‌گی جدول عمومی (`Run BuildTablePdf multi-page guard` → `bash tools/check-rtl-headers.sh table-many`)، چندصفحه‌گی فاکتور طلا (`Run BuildInvoicePdf multi-page guard` → `bash tools/check-rtl-headers.sh invoice-a5l-many`) و هدر فقط روی صفحاتِ دارای ردیف (`Run table-header-on-table-pages guard` → `bash tools/check-rtl-headers.sh table-summary-pages` — در A5 پرتوره با صفحهٔ جمع‌بندی، هدر فقط روی صفحاتِ دارای ردیف لازم است).

```bash
# بیلد کامل وب (هشدارها/خطاها را ببین)
dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo

# بیلد بدون قفل DLL — اگر dev server در حال اجراست خروجی را جدا کن:
dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo -o /tmp/out

# بیلد MAUI اندروید (نیازمند ANDROID_HOME):
export ANDROID_HOME="/c/Program Files (x86)/Android/android-sdk"
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-android --nologo

# بیلد MAUI ویندوز:
dotnet build Tarazin.Maui/Tarazin.Maui.csproj -f net8.0-windows10.0.19041.0 --nologo

# ⚠️ تست واحد (اجباری قبل از هر بیلد/PR) — گاردهای بازگشت‌پذیر روی خروجی PDF:
#   - ابعاد/جهتٔ صفحه (MediaBox): فاکتور پرتره، گزارش چک‌ها landscape (A4/A5)
#   - صفحه‌بندی فاکتورهای بلند (تعداد صفحات)
#   - راست‌به‌چپ بودن سلول‌ها (گاردِ منبع AlignRight — بازگشت به چپ‌چین نمی‌شود)
dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo

# ⚠️ گارد ضد «سرور با کد قدیمی» — قبل از ریاستارت dev server حتماً اجرا کن:
#   اگر Tarazin.Ui بیلد شده ولی Tarazin.Web نه، سرورِ `--no-build` کپیِ کهنهٔ DLL را لود می‌کند
#   و تغییرات (مثل فیکس RTL) در عمل اعمال نمی‌شود. خروجی 1 یعنی: اول Tarazin.Web را بیلد کن.
bash tools/check-stale-build.sh   # 0 = امن برای ریاستارت | 1 = stale — اول rebuild کن

# اجرای dev server (پورت‌های پیش‌فرض 65220 https / 65221 http):
dotnet run --project Tarazin.Web
```

- **تست‌ها:** `dotnet test Tarazin.Tests/Tarazin.Tests.csproj` — پروژهٔ `Tarazin.Tests` (xUnit) به `Tarazin.Ui` ارجاع می‌دهد و `PdfReportService` را با دادهٔ واقعی اجرا می‌کند (SkiaSharp/QuestPDF روی win-‌x64 و linux-x64 کار می‌کند). اگر هرگانه‌ی MediaBox/صفحه‌بندی/RTL قرمز شد، باگ صفحهٔ PDF برگشته؛ قبل از ادامه درستش کن.

- **قفل DLL:** اگر dev server در حال اجراست، بیلد عادی با MSB3021/3027 خطا می‌دهد (فایل‌های قفل). از `-o /tmp/out` استفاده کن یا سرور را ریاستارت کن.
- **هشدارها:** پروژه هدف «بدون هشدار» دارد — MUD0002/CS0618 را جدی بگیر (رفتار خراب)، CS8669/CS8618/CS8602 را هم پاک کن.
- **پیش‌نمایش زنده:** بعد از تغییر، dev server را ریاستارت کن تا بیلد جدید لود شود — **قبل از ریاستارت `bash tools/check-stale-build.sh` را اجرا کن** (گارد ضد باگ «سرور با کد قدیمی»: اگر کپی `Tarazin.Web/bin/Tarazin.Ui.dll` قدیمی‌تر از `Tarazin.Ui/bin` بود، اول `dotnet build Tarazin.Web` را بزن؛ وگرنه سرورِ `--no-build` همان کد کهنه را سرو می‌کند).
- **ریاستارت امن خودکار:** از `bash tools/start-dev-server.sh` برای ریاستارت استفاده کن — این اسکریپت **خودش اول گارد stale را اجرا می‌کند** و اگر stale بود از شروع سرویس جلوگیری می‌کند (`--force` فقط برای موارد اضطراری؛ به‌طور پیش‌فرض ممنوع).
- **ترتیب استاندارد بعد از تغییر در `Tarazin.Ui`:** (۱) `dotnet test Tarazin.Tests` → (۲) `dotnet build Tarazin.Web` → (۳) `bash tools/check-stale-build.sh` (باید 0 بدهد) → (۴) ریاستارت dev server. این چهار قدم در بلاک بالا هم آمده است.

---

## ۱۳. الگوهای متداول کپی‌پذیر (Copy-Paste)

پنج الگوی پرتکرار با کد کامل و **مطابق کد واقعی پروژه** (نمونه‌ها: `StoreSettings.razor`، `ProductCategoryDialog.razor`، `MainLayout.razor`، `InventoryWarehouses.razor`). هر الگو را مستقیم کپی کن و فقط نام‌ها/اسکیمه/اسکریپت را عوض کن — جزئیات کامپوننت‌ها در `tarazin-ui-ux` (§‌۲) و اسکلت کامل صفحه در `tarazin-reporting` است.

### الف) جدول CRUD کامل — الگوی ترجیحی (`TzDataTable` + `EntityCrudService`)

> برای جداول پایه/موجودیت (انبار، کالا، مشتری، کارمند، نرخ، …) از این الگو استفاده کن — کامپوننت مشترک `TzDataTable` (اسکلتون + حالت خالی + pager یکجا) + سرویس `EntityCrudService` (فرم MudDialog + تأیید حذف استاندارد). نمونهٔ بیلدشدهٔ واقعی: `Modules/Inventory/Pages/InventoryWarehouses.razor`.

```razor
@page "/{module}/{name}"
@inject DbService Db
@inject UserSession Session
@inject EntityCrudService Crud
@inject ISnackbar Snackbar

<PageHeader Eyebrow="{ماژول}" Title="{عنوان جمع}" Subtitle="{شرح}" />

<PageToolbar AddText="{ردیف} جدید" AddIcon="@Icons.Material.Filled.Add" OnAddClick="CreateAsync"
             AddDisabled="@(!Session.HasPermission({PermissionKey}))">
    <MudTextField @bind-Value="_search" Placeholder="جستجو..." Immediate="true"
                  Adornment="Adornment.Start" AdornmentIcon="@Icons.Material.Filled.Search"
                  Variant="Variant.Outlined" Margin="Margin.Dense" Class="mt-0" />
</PageToolbar>

<TzDataTable T="{Row}Row" Items="_filtered" Loading="_loading" ShowPager="true"
             SkeletonColumns="4" EmptyTitle="{ردیفی} ثبت نشده است.">
    <HeaderContent>
        <MudTh>کد</MudTh><MudTh>عنوان</MudTh><MudTh>وضعیت</MudTh>
        <MudTh Style="text-align:center">عملیات</MudTh>
    </HeaderContent>
    <RowTemplate Context="item">
        <MudTd DataLabel="کد" Class="tz-num">@item.Code</MudTd>
        <MudTd DataLabel="عنوان">@item.Title</MudTd>
        <MudTd DataLabel="وضعیت"><StatusChip IsActive="item.IsActive" /></MudTd>
        <MudTd DataLabel="عملیات">
            <EntityActions EditClicked="() => EditAsync(item)"
                           DeleteClicked="() => DeleteAsync(item)"
                           EditDisabled="!Session.HasPermission({PermissionKey})"
                           DeleteDisabled="!Session.HasPermission({PermissionKey})" />
        </MudTd>
    </RowTemplate>
</TzDataTable>
```

```csharp
@code {
    private const string Schema = "{schema}";
    private const string {PermissionKey} = "{module}.{action}";   // از Permissions.cs — حدس نزن

    private IReadOnlyList<{Row}Row> _rows = Array.Empty<{Row}Row>();
    private string _search = "";
    private bool _loading = true;

    private IReadOnlyList<{Row}Row> _filtered =>
        string.IsNullOrWhiteSpace(_search) ? _rows
            : _rows.Where(r => (r.Title ?? "").Contains(_search, StringComparison.OrdinalIgnoreCase)).ToList();

    protected override async Task OnInitializedAsync() => await ReloadAsync();

    private async Task ReloadAsync()
    {
        _loading = true;
        try { _rows = await Db.QueryAsync<{Row}Row>(Schema, "{ScriptList}", new { CompanyId = Db.CurrentCompanyId }); }
        finally { _loading = false; }
    }

    // از کارخانهٔ صحیح EntityEditorModel استفاده کن (نام دقیق را از Component/EntityEditorModel.cs بردار)
    private async Task CreateAsync()
    {
        var model = EntityEditorModel.From{Entity}(null);
        if (await Crud.ShowEditorAsync(model)) await ReloadAsync();
    }
    private async Task EditAsync({Row}Row row)
    {
        var model = EntityEditorModel.From{Entity}(row);
        if (await Crud.ShowEditorAsync(model)) await ReloadAsync();
    }
    private async Task DeleteAsync({Row}Row row)
    {
        var model = EntityEditorModel.From{Entity}(row);
        if (await Crud.ConfirmDeleteAsync(model)) await ReloadAsync();
    }
}
```

> ⚠️ **نکته‌های الزامی:** (۱) نام کارخانهٔ `From{Entity}` را از `Tarazin.Ui/Components/EntityEditorModel.cs` و کلید دسترسی را از `Tarazin.Share/Permissions.cs` بردار — **حدس نزن**؛ `TarazinPermissions.InventoryEdit`‌ای در کاتالوگ نیست، فقط `{module}.{action}` است. (۲) `EntityActions` از پارامترهای **`EditClicked`/`DeleteClicked`** استفاده می‌کند (نه `OnEdit`/`OnDelete` که قدیمی‌اند) — اگر صفحه‌ای `OnEdit` دارد، آن را اصلاح کن. (۳) آیکون‌ها همیشه با `@Icons.Material.Filled.X` (با `@`).

> **نسخهٔ ساده/ابزاری (MudTable دستی):** وقتی جدول خیلی ساده است و فیلتر/پکر دلخواه می‌خواهی، از `MudTable Hover Dense Striped` + `MudTd DataLabel` مستقیماً استفاده کن — اما برای CRUDهای موجودیت، الگوی بالا (`TzDataTable`) ترجیح دارد.

---

### ب) فرم (MudForm)
```razor
<MudForm @ref="_form" @bind-IsValid="_isValid">
    <MudGrid Spacing="2">
        <MudItem xs="12" sm="6">
            <MudTextField Label="عنوان" @bind-Value="_model.Title" Required="true"
                          RequiredError="عنوان الزامی است." Variant="Variant.Outlined" />
        </MudItem>
        <MudItem xs="12" sm="6">
            <MudNumericField T="int" Label="ترتیب نمایش" @bind-Value="_model.SortOrder"
                             Min="0" Variant="Variant.Outlined" />
        </MudItem>
        <MudItem xs="12">
            <MudSwitch T="bool" @bind-Value="_model.IsActive" Color="Color.Success">فعال</MudSwitch>
        </MudItem>
    </MudGrid>
</MudForm>
```

```csharp
private MudForm? _form;
private bool _isValid;

private async Task SaveAsync()
{
    if (_busy || _form is null) return;
    await _form.ValidateAsync();   // ⚠️ نه Validate() — در v9 منسوخ است
    if (!_isValid) return;
    // ... ذخیره با Db.ExecuteAsync + Snackbar + Close
}
```

**قوانین فرم:** اعتبارسنجی همیشه `ValidateAsync()` + `@bind-IsValid`؛ فیلدهای اجباری `Required="true"` + `RequiredError="..."`؛ مقدارهای نال (`_model.CategoryCode?.Trim()`) را قبل از ارسال به اسکریپت پاک‌سازی کن؛ `_form is null` را چک کن (قبل از رندر `@ref` ست نشده).

---

### ج) منو (MudMenu)

**روش ساده و امن (بدون باگ v9)** — اکتیویتور داخلی خود MudMenu کلیک را مدیریت می‌کند:
```razor
<MudMenu Text="عملیات" Icon="@Icons.Material.Filled.MoreVert" AnchorOrigin="Origin.BottomCenter"
         TransformOrigin="Origin.TopCenter" Variant="Variant.Outlined" Color="Color.Primary">
    <MudMenuItem OnClick="@(() => DoXAsync())" Icon="@Icons.Material.Filled.Edit">ویرایش</MudMenuItem>
    <MudMenuItem OnClick="@(() => DoYAsync())" Icon="@Icons.Material.Filled.CopyAll">کپی</MudMenuItem>
    <MudDivider />
    <MudMenuItem OnClick="@(() => DoZAsync())" Icon="@Icons.Material.Filled.Delete" Color="Color.Error">حذف</MudMenuItem>
</MudMenu>
```

**با ActivatorContent (محتوا/چیپ سفارشی)** — ⚠️ در MudBlazor 9 کلیک خودکار نیست؛ **باید** به `MenuContext` وصل کنی:
```razor
<MudMenu AnchorOrigin="Origin.BottomCenter" TransformOrigin="Origin.TopCenter">
    <ActivatorContent>
        <MudChip T="string" Size="Size.Small" Color="Color.Primary" Variant="Variant.Filled"
                 Style="cursor:pointer" OnClick="() => context.ToggleAsync()">  @* ← این خط حیاتی است *@
            @Label <MudIcon Icon="@Icons.Material.Filled.ExpandMore" Size="Size.Small" Class="ms-1" />
        </MudChip>
    </ActivatorContent>
    <ChildContent>
        <MudMenuItem OnClick="@(() => SelectAsync(x))">@x.Title</MudMenuItem>
    </ChildContent>
</MudMenu>
```

**قوانین منو:** بدون `context.ToggleAsync()` منو فقط با کیبورد باز می‌شود؛ آیتم فعال با `Icon="@Icons.Material.Filled.Check"` + `Disabled`؛ جداکننده با `MudDivider`؛ نمونه‌های واقعی: چیپ «شرکت | سال مالی» و منوی آواتار در `MainLayout.razor`.

---

### د) دیالوگ کامل (MudDialog) — سرتاسری

**۱. کامپوننت دیالوگ** `Modules/{Module}/Components/{Name}Dialog.razor`:
```razor
@inject DbService Db
@inject UserSession Session
@inject ISnackbar Snackbar

<MudDialog>
    <DialogContent>
        @* فرم با MudForm — الگوی «ب» *@
    </DialogContent>
    <DialogActions>
        <MudButton Variant="Variant.Text" Color="Color.Default" OnClick="Cancel" Disabled="_busy">انصراف</MudButton>
        <MudButton Variant="Variant.Filled" Color="Color.Primary" StartIcon="@Icons.Material.Filled.Save"
                   OnClick="SaveAsync" Disabled="_busy">ذخیره</MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter] private IMudDialogInstance MudDialog { get; set; } = default!;
    [Parameter, EditorRequired] public {Row}Row? Model { get; set; } = default!;   // null = جدید

    private {Row}Row _model = new();
    private MudForm? _form;
    private bool _isValid;
    private bool _busy;

    protected override void OnInitialized()
    {
        // کپی عمیق: ویرایشِ لغوشده نباید روی ردیفِ ارجاعیِ لیست اثر بگذارد.
        if (Model is not null)
            _model = new {Row}Row { /* کپی تک‌تک فیلدها */ };
    }

    private void Cancel() => MudDialog.Cancel();

    private async Task SaveAsync()
    {
        if (_busy || _form is null) return;
        await _form.ValidateAsync();
        if (!_isValid) return;
        _busy = true;
        try
        {
            await Db.ExecuteAsync("{schema}", "{ScriptUpsert}", new
            {
                Id = _model.Id,
                Title = _model.Title.Trim(),
                IsActive = _model.IsActive,
                CreatedBy = Session.UserName,
                UpdatedBy = Session.UserName
            });
            Snackbar.Add("ذخیره شد.", Severity.Success);
            MudDialog.Close(DialogResult.Ok(true));
        }
        catch (Exception ex) { Snackbar.Add(ex.Message, Severity.Error); }
        finally { _busy = false; }
    }
}
```

**۲. باز کردن از صفحه + تأیید حذف:**
```csharp
private async Task OpenNewAsync()
{
    var dlg = await Dialog.ShowAsync<{Name}Dialog>("{عنوان} جدید",
        new DialogParameters { ["Model"] = null },
        new DialogOptions { MaxWidth = MaxWidth.Small, FullWidth = true, CloseButton = true, CloseOnEscapeKey = true });
    if ((await dlg.Result) is { Canceled: false })
        await LoadAsync();
}

private async Task DeleteAsync({Row}Row row)
{
    var confirmed = await Dialog.ShowMessageBoxAsync(
        "تأیید حذف", $"آیا از حذف «{row.Title}» مطمئن هستید؟", yesText: "حذف", cancelText: "انصراف");
    if (confirmed is not true) return;
    try
    {
        await Db.ExecuteAsync("{schema}", "{ScriptDelete}", new { Id = row.Id, UpdatedBy = Session.UserName });
        Snackbar.Add("حذف شد.", Severity.Success);
        await LoadAsync();
    }
    catch (Exception ex) { Snackbar.Add(ex.Message, Severity.Error); }
}
```

**قوانین دیالوگ:** کلیدهای `DialogParameters` = نام `[Parameter]`های دیالوگ؛ `Model = null` یعنی «جدید»؛ نمونهٔ کامل پیاده‌شده: `ProductCategoryDialog.razor` + تب «دسته‌های کالا» در `StoreSettings.razor` (همان مسیر این الگو را طی کرده و بیلد/تأیید شده).

---

### ه) گزارش (چاپ / PDF)

> اسکیلِ اختصاصی گزارش‌سازی در `.claude/skills/tarazin-reporting/SKILL.md` است — برای ساخت هر صفحهٔ گزارش، دیالوگ چاپ یا خروجی PDF **اول آن را بخوان**. خلاصهٔ کپی‌پذیر، برگرفته از همان اسکیل:

1. **صفحهٔ گزارش:** `Modules/{Module}/Pages/{Module}Reports.razor` با `@page "/{module}/reports"` → `PageHeader` (با دکمه‌های «بروزرسانی» و «چاپ / PDF») + فیلترها (`MudDatePicker` شمسی در `MudPaper`) + جدول (`MudTable Hover Dense Striped Breakpoint.Breakpoint.Sm RowsPerPage`) + جمع ستون.
2. **داده:** `Db.QueryAsync<TRow>(schema, "{ScriptName}", new { FromDate, ToDate, CompanyId = Session.ActiveCompanyId, FiscalYearId = Session.ActiveFiscalYearId })` — هرگز SQL خام.
3. **چاپ/PDF با روال واحد:**
```csharp
private async Task PrintAsync() => await Dialog.ShowAsync<ReportPrintDialog>("چاپ گزارش",
    new DialogParameters<ReportPrintDialog>
    {
        { x => x.Title, "{عنوان}" },
        { x => x.Body, TableBody },                     // RenderFragment جدول (بدون pager)
        { x => x.Summary, ReportSummary },              // اختیاری
        { x => x.BuildPdf, BuildPdf }                   // Func<string, byte[]>
    }, new DialogOptions { MaxWidth = MaxWidth.Large, FullWidth = true });

private byte[] BuildPdf(string paperSize)
{
    var cols = new List<TableReportColumn> { new() { Header = "تاریخ" }, new() { Header = "مبلغ", AlignRight = true } };
    var rows = _rows.Select(r => (IReadOnlyList<string>)new[] { r.Date.ToString("yyyy/MM/dd"), r.Amount.ToString("N0") }).ToList();
    return Pdf.BuildTablePdf("{عنوان}", "{شرح}", $"از {_from:yyyy/MM/dd} تا {_to:yyyy/MM/dd}", cols, rows, new[] { $"جمع: {_rows.Sum(r=>r.Amount):N0}" }, paperSize);
}
```
4. **نام فایل PDF:** هرگز دستی — از `PdfFileNames` (شمسی + پاک‌سازی). **دانلود:** همیشه از `IPdfSaver.SaveAsync(fileName, bytes)`، نه `IJSRuntime` مستقیم.
5. **موتور:** همهٔ گزارش‌ها و چاپ‌ها → **QuestPDF** (`PdfReportService`) — موتور واحد مشترک وب + MAUI؛ هیچ موتور دیگری وجود ندارد.
6. **قانون طلایی بیلد:** بعد از هر تغییر صفحهٔ گزارش → `dotnet build Tarazin.Web` + `check-stale-build.sh`، یا `bash tools/run-checks.sh`.

---

## ۱۴. نقشهٔ سریع فایل‌های کلیدی

| فایل | نقش |
|------|-----|
| `Tarazin.Ui/App.razor` | ریشه: Router + MudBlazor providers + بازیابی نشست |
| `Tarazin.Ui/Layout/MainLayout.razor` | نوار بالا + گارد مسیر + چیپ شرکت/سال مالی + منوی کاربر |
| `Tarazin.Ui/Layout/NavMenu.razor` | منوی کناری (Drawer) — از `TarazinModules` + فیلتر دسترسی |
| `Tarazin.Ui/Theme/TarazinModules.cs` | کاتالوگ ماژول‌ها/ناوبری/گارد (منبع نوبار) |
| `Tarazin.Share/Permissions.cs` | کاتالوگ دسترسی‌ها و نقش‌ها (منبع RBAC) |
| `Tarazin.Data/DbService.cs` | درگاه داده (اسکریپت نامدار + ممیزی) |
| `Tarazin.Ui/Services/ServiceCollectionExtensions.cs` | ثبت همهٔ سرویس‌های UI |
| `Tarazin.Ui/Components/EntityEditorDialog.razor` | الگوی مرجع مودال چندکِیند |
| `Tarazin.Ui/Components/EntityEditorModel.cs` | ۱۳ کارخانهٔ `From{Entity}` (نام دقیق را از اینجا بردار، حدس نزن) |
| `Tarazin.Ui/Services/EntityCrudService.cs` | CRUD مشترک: `ShowEditorAsync`/`ConfirmDeleteAsync` |
| `Tarazin.Ui/Components/TzDataTable.razor` | جدول استاندارد (اسکلتون + خالی + pager) |
| `Tarazin.Ui/Components/PageToolbar.razor` | نوار عملیات/فیلتر بالای جدول (`AddText`/`OnAddClick`) |
| `Tarazin.Ui/Components/ReportPrintDialog.razor` | دیالوگ مشترک چاپ/پیش‌نمایش/دانلود PDF |
| `Tarazin.Ui/_Imports.razor` | usingهای سراسری (Tarazin.Services، Tarazin.Data، MudBlazor) |
| `docs/BI_MODULE.md` | مستند موتور رندر گزارش + لایسنس |

---

## 🔁 حلقهٔ ارجاع

> مرجع اصلی پروژه: [`README.md`](../../README.md) — فهرست یک‌جای اسکیل‌ها: [`docs/SKILLS_INDEX.md`](../../docs/SKILLS_INDEX.md) — دست‌نوشت و وضعیت ماژول‌ها: [`docs/Handoff.md`](../../docs/Handoff.md) و [`docs/Handoff_ModuleBreakdown.md`](../../docs/Handoff_ModuleBreakdown.md).
