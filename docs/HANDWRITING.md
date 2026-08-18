# دست‌خط نویسنده — قوانین نانوشتهٔ ترازین

> این فایل برای این است که هر کسی (یا هر عاملی) که روی پروژه کار می‌کند، دقیقاً مثل نویسندهٔ اصلی کد بزند — از نام‌گذاری تا کامنت و ساختار Razor.
> آخرین به‌روزرسانی: ۱۴۰۵/۰۵/۲۷ — بعد از اصلاح شرکت/نقش و بروزرسانی آنلاین ارز

---

## ۱. زبان و لحن

* **کامنت و متن UI فارسی است** — راست‌چین، اصطلاحات حسابداری/طلافروشی واقعی (مثلاً «سند موقت»، «نرخ سیستم»، «کیف پول»).
* کامنت‌های فنی با `/// <summary>` شروع می‌شوند و داخلش هم فارسی است، نه انگلیسی خشک.
* ارجاع به PRD با `§` — مثلاً `§34`، `§46`، `§56` — همیشه در خلاصهٔ کلاس/متد ذکر می‌شود تا معلوم شود چرا این قانون پیاده شده.
* هدر هر اسکریپت SQL ثابت است:
  ```sql
  -- =============================================
  -- Tarazin.Data/Scripts/{schema}/{Name}.sql
  -- Schema: {schema}
  -- Query|Execute. توضیح فارسی یک‌خطی
  -- =============================================
  ```
* هدر هر فایل C# مدل/سرویس یک `/// <summary>` فارسی دارد، نه انگلیسی.

## ۲. معماری ۵ پروژه — هرگز نشکن

```
Share (Tarazin.Models) ← Data (DbService, ScriptCatalog, Scripts) ← Ui (RCL) ← {Web, Maui}
```

* **Share** فقط POCO — هیچ using به Data/Ui ندارد. namespace ثابت `Tarazin.Models`.
* **Data** فقط داده — `DbService.QueryAsync<T>(schema, scriptName, params)` — هیچ Razor ندارد.
* **Ui** همهٔ صفحات — `Modules/{Name}/Pages/*.razor` + `Services/` + `Components/`.
* **Web/Maui** فقط پوسته — `Program.cs / MauiProgram.cs` فقط `AddTarazinUiServices()` و `App.razor` مشترک.

> قانون طلایی: صفحهٔ جدید فقط در `Tarazin.Ui/Modules/...`، مدل جدید فقط در `Tarazin.Share`، اسکریپت جدید فقط در `Tarazin.Data/Scripts/{schema}/`.

## ۳. Razor + MudBlazor

* هر صفحه با سه خط شروع می‌شود:
  ```razor
  @page "/module/route"
  @inject DbService Db
  @inject UserSession Session
  @inject ISnackbar Snackbar
  ```
* ترتیب: `@page` → `@inject` → `<PageTitle>` → `<PageHeader>` (با `Title`، `Subtitle`، `Eyebrow`) → `MudPaper`/`MudTable`.
* جدول‌ها همیشه `MudTable` با `Hover Dense Striped` + `HeaderContent` + `RowTemplate` + `NoRecordsContent`.
* مودال‌ها با `MudDialog` + `DialogContent`/`DialogActions` + `MudForm @ref` + `@bind-IsValid`.
* چک‌باکس‌ها در حلقه: `var localItem = item; <MudCheckBox Value="localItem.IsChecked" ValueChanged="@(v=>{localItem.IsChecked=v; StateHasChanged();})" Label="..." Dense />` — برای جلوگیری از capture اشتباه.
* آیکون‌ها فقط `Icons.Material.Filled.*`، رنگ‌ها `Color.Primary/Secondary` — هیچ CSS سفارشی زیاد.
* عددها با `ToString("N0")` / `N2` / `N4` — ریال `N0`، نرخ ارز `N2`/`N4`.

## ۴. C#

* فیلدهای خصوصی با `_` شروع: `_loading`, `_busy`, `_title`, `_groups`.
* کلاس‌های داخلی `sealed` + `record` برای DTO تابلویی (مثلاً `PermissionToggle`).
* متدهای async با `Async` پسوند، `CancellationToken ct = default` همیشه آخر.
* سرویس‌ها `sealed` و `DbService` را از `IServiceProvider` نمی‌گیرند — از DI.
* خطاها با `Snackbar.Add(ex.Message, Severity.Error)` — هیچ `try/catch` خاموش بدون log.
* برای جستجو/فیلتر: `HashSet<string>(StringComparer.OrdinalIgnoreCase)` — نه `Contains` ساده.

## ۵. SQL و اسکریپت‌های نامدار

* هر اسکریپت یک فایل `Scripts/{schema}/{Name}.sql` و یک کلید `Schema/Name` در `ScriptCatalog`.
* صفحات هرگز SQL خام ندارند — فقط `Db.QueryAsync<T>("schema","Name", new{...})`.
* نام ستون = نام پراپرتی مدل — Dapper map می‌کند. افزودن فیلد جدید = پراپرتی nullable + `ISNULL(col,NULL)` در اسکریپت.
* `UPSERT`ها با `IF @Id=0 INSERT ELSE UPDATE` + `SELECT SCOPE_IDENTITY() AS NewId`.
* تاریخ‌ها با `SYSUTCDATETIME()` ذخیره، با `ToLocalTime()` نمایش (شمسی در UI با `CultureInfo("fa-IR")`).
* `GO` برای batch جدا — اسکریپت‌ها با `GO` از هم جدا می‌شوند (`SqlScript.SplitBatches`).
* هر جا به اسکیمهٔ دیگر دست زده شد، هدر `-- Cross-schema: central.Companies` نوشته شود تا `tools/cross-schema-scan.sh` پاس شود.

## ۶. ماژول ارز — الگوی ویژه

* مرکز قیمت واحد: `currency.PriceRates` با 7 نرخ (`Online/Manual/System/Buy/Sell/Accounting/Mid`) + `Spread/Status/IsOverride`.
* نرخ آنلاین هرگز مستقیم معامله نمی‌شود — فقط با `RateOverride` (تأیید مدیر) یا `AutoPromote=1` به سیستم می‌رود (§46).
* دریافت آنلاین فقط از `PriceSources` (Endpoint + MappingsJson قابل ویرایش) — نه HTML Scrape (§61).
* هر معامله ارز: `Wallets` + `CurrencyMovements` + `accounting.Documents` + `treasury.CashMovements` + `central.Parties` در یک تراکنش.

## ۷. RBAC

* کاتالوگ دسترسی در `Tarazin.Share/Permissions.cs` — کلید `module.action` — منبع واحد برای seed و UI.
* `UserSession.HasPermission/HasAny/CanView` — گارد مرکزی در `MainLayout.RefreshPath` + فیلتر `NavMenu`/`Home`.
* `RoleEditorDialog` گروه‌بندی بر اساس `ModuleKey` + دکمه «انتخاب همه» هر گروه.

## ۸. چیزهایی که نویسنده هرگز نمی‌کند

* پروژه جدید خارج از 5 تا — ❌
* `HttpClient` برای داده — ❌ (فقط `PriceFeedService` برای بازار خارجی)
* Bootstrap دستی / جدول سفارشی / CSS زیاد — ❌ فقط MudBlazor
* `GO` داخل یک transaction — ❌
* نام انگلیسی برای ستون UI — ❌ همیشه فارسی
* `async void` به جز `Timer.Tick` — ❌

---

> اگر این قوانین را رعایت کنی، کدت از کد اصلی قابل تشخیص نیست — همین هدف این فایل است.
