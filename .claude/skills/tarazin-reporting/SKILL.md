---
name: tarazin-reporting
description: >
  راهنمای الزامی گزارش‌سازی در «ترازین» — MANDATORY guide for building or
  editing any report page (.razor under Modules/*/Pages/*Reports*), print
  dialog, or PDF export. Read this BEFORE creating or editing a report page,
  a QuestPDF builder, or a print dialog. Covers the unified report skeleton
  (PageHeader + filter bar + MudTable + pager + summary), the print/PDF
  pipeline (ReportPrintDialog + PdfReportService.BuildTablePdf + IPdfSaver),
  Shamsi date and fiscal-year conventions, when to use Stimulsoft vs QuestPDF,
  and the copy-paste pattern with a complete example.
---

# SKILL.md — گزارش‌سازی در «ترازین» (نحوهٔ گزارش‌نویسی)

> ## ⚖️ قانون الزامی
> **قبل از ساخت یا ویرایش هر صفحهٔ گزارش، دیالوگ چاپ یا خروجی PDF، اول این سند را کامل بخوان.** همهٔ گزارش‌های سیستم باید **یک روال واحد** را دنبال کنند: اسکلت یکسان صفحه، فیلتر یکسان، جدول یکسان، و خط لولهٔ چاپ/PDF یکسان. اگر بین این سند و کدی که می‌بینی اختلاف بود، **این سند را به‌روز کن** و طبق واقعیتِ کد رفتار کن.

---

## ۱. اصول کلی — «یک روال برای همهٔ گزارش‌ها»

هر گزارش سیستم از این ۵ لایه ساخته می‌شود (به همین ترتیب):

```
١. PageHeader        → عنوان + زیرعنوان + دکمه‌های «بروزرسانی» و «چاپ / PDF»
٢. فیلترها           → MudGrid از MudDatePicker + MudSelect + دکمهٔ «اجرا»
٣. جدول              → MudTable (Hover + Dense + Striped + DataLabel + Pager)
٤. جمع‌بندی          → StatCard (داشبوردی) یا MudText (جمع ستون) زیر جدول
٥. چاپ / PDF         → ReportPrintDialog (پیش‌نمایش + چاپ + دانلود PDF)
```

- **همهٔ گزارش‌ها چاپ/PDF دارند** (دکمهٔ «چاپ / PDF» در PageHeader). هیچ گزارشی نباید فقط جدول روی صفحه باشد.
- **داده همیشه از اسکریپت نامدار** با `Db.QueryAsync<TRow>(schema, "ScriptName", ...)` می‌آید — هرگز SQL خام در Razor.
- **خطاها با Snackbar** (`Severity.Error`) و پیام امن `ex.Message` (که خودش `Db.Describe` است) — هرگز متن خام استثنا.
- **تاریخ‌ها شمسی نمایش داده می‌شوند** (`FaCulture`) و نام فایل PDF با تاریخ شمسی ساخته می‌شود (`PdfFileNames`).

---

## ۲. اسکلت صفحهٔ گزارش (Skeleton)

فایل: `Modules/{Module}/Pages/{Module}Reports.razor` با `@page "/{module}/reports"`.

```razor
@page "/{module}/reports"
@inject DbService Db
@inject UserSession Session
@inject ISnackbar Snackbar
@inject IDialogService Dialog
@inject PdfReportService Pdf

<PageTitle>گزارشات — {ماژول}</PageTitle>

<PageHeader Title="گزارش {عنوان}" Subtitle="{شرح گزارش}." Eyebrow="{ماژول}">
    <MudButton Variant="Variant.Outlined" Color="Color.Primary" OnClick="LoadAsync" Disabled="_loading"
               StartIcon="@Icons.Material.Filled.Refresh">بروزرسانی</MudButton>
    <MudButton Variant="Variant.Outlined" Color="Color.Secondary" OnClick="PrintAsync" Disabled="_loading || _rows.Count == 0"
               StartIcon="@Icons.Material.Filled.Print">چاپ / PDF</MudButton>
</PageHeader>

@* ── فیلترها ── *@
<MudPaper Elevation="1" Class="pa-4 mb-4">
    <MudGrid>
        <MudItem xs="12" sm="6" md="3">
            <MudDatePicker Label="از تاریخ" Culture="FaCulture" @bind-Date="_from" />
        </MudItem>
        <MudItem xs="12" sm="6" md="3">
            <MudDatePicker Label="تا تاریخ" Culture="FaCulture" @bind-Date="_to" />
        </MudItem>
        <MudItem xs="12" sm="6" md="3">
            <MudButton Variant="Variant.Filled" Color="Color.Primary" FullWidth="true"
                       StartIcon="@Icons.Material.Filled.Search" OnClick="LoadAsync" Disabled="_loading">اجرا</MudButton>
        </MudItem>
    </MudGrid>
</MudPaper>

@* ── جدول ── *@
<MudPaper Elevation="1" Class="pa-4">
    <MudTable Items="_rows" Loading="_loading" Hover="true" Dense="true" Striped="true"
              Breakpoint="Breakpoint.Sm" RowsPerPage="25">
        <HeaderContent>
            <MudTh>تاریخ</MudTh><MudTh>شماره</MudTh><MudTh>شرح</MudTh><MudTh>مبلغ</MudTh>
        </HeaderContent>
        <RowTemplate>
            <MudTd DataLabel="تاریخ">@context.MovementDate.ToString("yyyy/MM/dd")</MudTd>
            <MudTd DataLabel="شماره">@context.MovementNumber</MudTd>
            <MudTd DataLabel="شرح">@context.Description</MudTd>
            <MudTd DataLabel="مبلغ">@context.Amount.ToString("N0")</MudTd>
        </RowTemplate>
        <NoRecordsContent><MudText Color="Color.Secondary">داده‌ای نیست.</MudText></NoRecordsContent>
        <PagerContent><MudTablePager PageSizeOptions="@(new int[] { 25, 50, 100 })" /></PagerContent>
    </MudTable>

    @if (_rows.Count > 0)
    {
        <MudText Typo="Typo.body2" Class="mt-4">
            جمع: <b>@_rows.Sum(r => r.Amount).ToString("N0")</b>
        </MudText>
    }
</MudPaper>

@code {
    private static readonly CultureInfo FaCulture = CultureInfo.GetCultureInfo("fa-IR");
    private const string Schema = "{module}";

    private List<{Row}Row> _rows = new();
    private DateTime? _from;
    private DateTime? _to;
    private bool _loading;

    protected override async Task OnInitializedAsync()
    {
        // پیش‌فرض بازه = سال مالی فعال (اگر در دسترس است)، وگرنه یک ماه اخیر.
        _from = DateTime.Today.AddMonths(-1);
        _to = DateTime.Today;
        await LoadAsync();
    }

    private async Task LoadAsync()
    {
        _loading = true;
        try
        {
            _rows = (await Db.QueryAsync<{Row}Row>(Schema, "{ScriptName}", new
            {
                FromDate = _from?.Date ?? DateTime.Today.AddMonths(-1),
                ToDate = _to?.Date ?? DateTime.Today,
                CompanyId = Session.ActiveCompanyId,
                FiscalYearId = Session.ActiveFiscalYearId
            })).ToList();
        }
        catch (Exception ex) { Snackbar.Add(ex.Message, Severity.Error); }
        finally { _loading = false; }
    }

    private async Task PrintAsync() => await ReportDialog.ShowAsync(this, "{عنوان گزارش}", _rows, BuildPdf);
}
```

**قوانین اسکلت:**
- دکمهٔ «چاپ / PDF» فقط وقتی فعال است که داده باشد: `Disabled="_loading || _rows.Count == 0"`.
- `Breakpoint="Breakpoint.Sm"` + `RowsPerPage="25"` + `MudTablePager` برای همهٔ جدول‌ها (مگر کمتر از ۲۰ ردیف قطعی).
- ستون‌های عددی `ToString("N0")`، تاریخ‌ها `yyyy/MM/dd` (یا با `FaCulture`)، وضعیت‌ها با `MudChip` رنگی.
- اگر گزارش چند زیرگزارش دارد → `MudTabs`؛ فیلترهای مشترک یک‌بار بالای تب‌ها.

---

## ۳. خط لولهٔ چاپ / PDF (پیش‌نمایش + چاپ + دانلود)

**قلب روال چاپ، کامپوننت مشترک `ReportPrintDialog` است** (در `Tarazin.Ui/Components/`) — همان دیالوگی که فاکتور طلا (`GoldInvoicePrintDialog`) و گزارش چک‌ها (`ChequeDuePrintDialog`) هم از همان الگو پیروی می‌کنند. برای گزارش‌های جدولی از همین کامپوننت عمومی استفاده کن:

```csharp
// باز کردن دیالوگ چاپ از صفحه:
private async Task PrintAsync()
{
    if (_rows.Count == 0) return;
    await Dialog.ShowAsync<ReportPrintDialog>("چاپ گزارش", new DialogParameters<ReportPrintDialog>
    {
        { x => x.Title, "گزارش سفارش‌ها" },
        { x => x.Subtitle, "سفارش‌ها بر اساس وضعیت در بازهٔ تاریخ" },
        { x => x.RangeText, $"از {_from:yyyy/MM/dd} تا {_to:yyyy/MM/dd}" },
        { x => x.Body, TableBody },                              // RenderFragment جدول
        { x => x.Summary, ReportSummary },                       // RenderFragment اختیاری
        { x => x.BuildPdf, BuildPdf }                            // Func<string, byte[]>
    }, new DialogOptions { MaxWidth = MaxWidth.Large, FullWidth = true, CloseButton = true, CloseOnEscapeKey = true });
}
```

### الف) RenderFragment جدول (بدنهٔ چاپی)

جدول داخل دیالوگ باید **بدون فیلتر، بدون pager و با هدر کامل** باشد — همان ردیف‌های `_rows`:

```razor
@* تعریف RenderFragment در سطح صفحه (نه داخل متد) *@
private RenderFragment TableBody => @<MudTable Items="_rows" Dense="true" Hover="true" Striped="true" Breakpoint="Breakpoint.Sm" Class="gp-lines-table">
    <HeaderContent>
        <MudTh>تاریخ</MudTh><MudTh>شماره</MudTh><MudTh>شرح</MudTh><MudTh>مبلغ</MudTh>
    </HeaderContent>
    <RowTemplate>
        <MudTd DataLabel="تاریخ">@context.MovementDate.ToString("yyyy/MM/dd")</MudTd>
        <MudTd DataLabel="شماره">@context.MovementNumber</MudTd>
        <MudTd DataLabel="شرح">@context.Description</MudTd>
        <MudTd DataLabel="مبلغ">@context.MovementAmount.ToString("N0")</MudTd>
    </RowTemplate>
</MudTable>;
```

### ب) ساخت PDF با QuestPDF (سمت سرور / بومی)

تابع `BuildPdf` در صفحه، ردیف‌ها را به رشته‌های آماده تبدیل می‌کند و با `PdfReportService.BuildTablePdf` PDF می‌سازد:

```csharp
private byte[] BuildPdf(string paperSize)
{
    var columns = new List<TableReportColumn>
    {
        new() { Header = "تاریخ" },
        new() { Header = "شماره" },
        new() { Header = "شرح" },
        new() { Header = "مبلغ", AlignRight = true }
    };
    var rows = _rows.Select(r => (IReadOnlyList<string>)new string[]
    {
        r.MovementDate.ToString("yyyy/MM/dd"),
        r.MovementNumber,
        r.Description,
        r.Amount.ToString("N0")
    }).ToList();

    return Pdf.BuildTablePdf("گزارش سفارش‌ها", "سفارش‌ها بر اساس وضعیت",
        $"از {_from:yyyy/MM/dd} تا {_to:yyyy/MM/dd}", columns, rows,
        new[] { $"جمع: {_rows.Sum(r => r.Amount):N0}" }, paperSize);
}
```

- **نام فایل PDF** هرگز دستی ساخته نمی‌شود — از `PdfFileNames` (`Tarazin.Ui/Services/PdfFileNames.cs`): `PdfFileNames.Invoice(...)`، `PdfFileNames.ChequeReport(...)` یا `PdfFileNames.Sanitize(عنوان) + "-" + PdfFileNames.ShamsiDate(...)`.
- `BuildTablePdf` خودش تشخیص می‌دهد جدول عریض است (بیش از ۶ ستون) → landscape، وگرنه portrait. اندازهٔ A4/A5 را دیالوگ از سلکتور می‌گیرد.
- **فونت:** Vazirmatn به‌صورت EmbeddedResource همراه `PdfReportService` است؛ نیازی به CDN نیست و روی وب/اندروید/iOS/ویندوز یکی است.

### ج) ذخیره‌سازی (IPdfSaver)

- **وب (Blazor Server):** `WebPdfSaver` → بلاب در مرورگر دانلود می‌شود (`tarazin.downloadPdfBytes` در `print-pdf.js`).
- **MAUI:** `MauiPdfSaver` → فایل در `FileSystem.AppDataDirectory` نوشته و با Launcher باز می‌شود (بدون html2pdf سنگین در WebView).

هیچ صفحه‌ای نباید مستقیم `IJSRuntime` را برای دانلود صدا بزند — همیشه `IPdfSaver.SaveAsync(fileName, bytes)`.

---

## ۴. تاریخ شمسی و بازهٔ سال مالی

1. **نمایش:** تاریخ‌ها در جدول با `ToString("yyyy/MM/dd")` و تاریخ‌های شمسیِ فرمتی با `CultureInfo.GetCultureInfo("fa-IR")` (const `FaCulture` در هر صفحه). اگر نیاز به تبدیل میلادی→شمسی داری: `PersianCalendar` در `Tarazin.Ui/Services/PersianDate.cs`.
2. **پیش‌فرض بازهٔ فیلتر:**
   - اگر ماژول به `AccountingContextService` دسترسی دارد (حسابداری/خزانه/طلا): بازه = **سال مالی فعال** (`Context.GetActiveFiscalYearAsync()` → `StartDate`/`EndDate`).
   - بقیه: `DateTime.Today.AddMonths(-1)` تا `DateTime.Today`.
3. **نام فایل PDF:** همیشه تاریخ شمسی (`PdfFileNames.ShamsiDate`) — نه میلادی.
4. **گزارشات BI/Stimulsoft:** همان پارامترهای `FromDate`/`ToDate` را به اسکریپت می‌دهند (مقادیر nullable).

---

## ۵. خلاصهٔ آماری (StatCard)

اگر گزارش چند عدد کلیدی دارد (مثل گزارش چک‌ها)، بالای جدول یک `MudGrid` از `StatCard` بگذار (نمونه: `TreasuryChequeReport.razor`):

```razor
<MudGrid Class="mb-4">
    <StatCard Label="چک‌های باز" Value="@_rows.Count.ToString("N0")"
              Icon="@Icons.Material.Filled.ReceiptLong" Accent="#1E4B73" />
    <StatCard Label="سررسیدشده" Value="@OverdueCount.ToString("N0")"
              Icon="@Icons.Material.Filled.NotificationImportant" Accent="#C62828" Hint="سررسید گذشته" />
    <StatCard Label="جمع" Value="@_rows.Sum(r => r.Amount).ToString("N0")"
              Icon="@Icons.Material.Filled.WarningAmber" Accent="#9C3B2E" Hint="ریال" />
</MudGrid>
```

قوانین: حداکثر ۴ کارت؛ `Hint` برای واحد/توضیح کوتاه؛ رنگ‌های Accent ثابت پروژه (آبی `#1E4B73`، قرمز `#C62828`، نارنجی `#EF6C00`، سبز `#0E4D4A`).

---

## ۶. چه موقع Stimulsoft و چه موقع QuestPDF؟

| نیاز | موتور | چرا |
|------|-------|-----|
| گزارش جدولی ساده (لیست + فیلتر + چاپ) | **QuestPDF + ReportPrintDialog** | سبک، سمت سرور/بومی، یکسان در وب و MAUI |
| فاکتور/سند رسمی با چیدمان خاص | **QuestPDF** (`BuildInvoicePdf`) + دیالوگ اختصاصی | کنترل کامل چیدمان |
| داشبورد BI با چند گزارش و خروجی PDF/Excel | **Stimulsoft** (`BiReportService` + `StiBlazorViewer`) | فقط صفحهٔ `/bi/reports` و فیش حقوق |
| خروجی Excel | Stimulsoft Viewer یا دکمهٔ Excel آن | فقط BI |

- **قانون:** گزارش‌های ماژولی (حسابداری، خزانه، طلا، انبار، ارز، فروشگاه، حقوق، انبار) → QuestPDF. فقط BI و فیش حقوق Stimulsoft دارند.
- لایسنس Stimulsoft: بدون کلید واترمارک trial می‌گیرد (مستند: `docs/BI_MODULE.md`).

---

## ۷. الگوی کامل کپی‌پذیر (یک گزارش با چاپ)

نمونهٔ کامل پیاده‌شده در پروژه:
- **`Modules/Treasury/Pages/TreasuryChequeReport.razor`** — StatCard + فیلتر + جدول + `ChequeDuePrintDialog` (الگوی مرجع چاپ).
- **`Modules/GoldShop/Components/GoldInvoicePrintDialog.razor`** — دیالوگ چاپ با پیش‌نمایش A4/A5 + دکمهٔ «دانلود PDF».
- **`Modules/Store/Pages/StoreReports.razor`** — ساده‌ترین گزارش جدولی با چاپ (بعد از اعمال این اسکیل).

### چک‌لیست «چاپ / PDF» برای هر گزارش:
- [ ] دکمهٔ «چاپ / PDF» در `PageHeader` با `Disabled="_loading || _rows.Count == 0"`.
- [ ] `ReportPrintDialog` با `Body` (جدول) + `BuildPdf` (QuestPDF).
- [ ] نام فایل از `PdfFileNames` (تاریخ شمسی + پاک‌سازی کاراکتر).
- [ ] `IPdfSaver.SaveAsync` — نه `IJSRuntime` مستقیم.
- [ ] پیش‌نمایش A4/A5 + دکمهٔ «چاپ» (`window.print`) + «دانلود PDF».

---

## ۷.۵. قانون بیلد پس از تغییر گزارش

> **بعد از هر تغییر در `Tarazin.Ui`** (هر صفحهٔ گزارش، `PdfReportService`, دیالوگ چاپ) حتماً این زنجیره را طی کن، وگرنه سرورِ `--no-build` همان کد کهنه را سرو می‌کند (باگ «ستون‌ها درست شد ولی هدر نه»):
> ۱. `dotnet test Tarazin.Tests` → ۲. `dotnet build Tarazin.Web/Tarazin.Web.csproj` → ۳. `bash tools/check-stale-build.sh` (خروجی باید `0` باشد) → ۴. ریاستارت dev server.
> **سریع‌ترین راه:** `bash tools/run-checks.sh` همین زنجیره را پشت‌سرهم اجرا می‌کند (تست → بیلد وب → گارد stale).

---

## ۸. چک‌لیست نهایی هر صفحهٔ گزارش

- [ ] `@page "/{module}/reports"` + `PageTitle` + `PageHeader` (با دکمه‌های بروزرسانی/چاپ).
- [ ] فیلترها در `MudPaper` با `MudDatePicker` (شمسی) + دکمهٔ «اجرا».
- [ ] `MudTable` با `Hover + Dense + Striped + Breakpoint.Sm + RowsPerPage + PagerContent`.
- [ ] `MudTd DataLabel="..."` روی همهٔ ستون‌ها (موبایل).
- [ ] `NoRecordsContent` فارسی.
- [ ] جمع‌بندی: `StatCard` (اگر چند کلید) یا `MudText` جمع ستون.
- [ ] داده از اسکریپت نامدار + `Session.ActiveCompanyId`/`ActiveFiscalYearId`.
- [ ] خطا با `Snackbar(Severity.Error)` + `finally { _loading = false; }`.
- [ ] چاپ/PDF با `ReportPrintDialog` + `BuildTablePdf` + `PdfFileNames`.
- [ ] بیلد بدون خطا: `dotnet build Tarazin.Web/Tarazin.Web.csproj --nologo -v q`.
- [ ] **قانون طلایی بیلد:** بعد از هر تغییر در یک فایل `Tarazin.Ui` (صفحه/کامپوننت/سرویس PDF) حتماً `dotnet build Tarazin.Web` بزن، سپس `bash tools/check-stale-build.sh` (باید `0` بدهد) و بعد سرور را ریاستارت کن — چرا که `dotnet test` یا بیلدِ تکیِ `Tarazin.Ui` کپیِ `Tarazin.Web/bin` را به‌روز نمی‌کند و سرورِ `--no-build` کد کهنه را سرو می‌کند.
- [ ] تست‌های PDF سبز: `dotnet test Tarazin.Tests/Tarazin.Tests.csproj --nologo` — انازهٔ صفحهٔ فاکتور (پرتره) و گزارش چک‌ها (landscape) را MediaBox چک می‌کند و صفحه‌بندی/راست‌چینی را نگهبانی می‌کند. اگر قرمز شد، خروجی PDF تازت خراب است.

---

## ۹. مستندات مرتبط

| سند | موضوع |
|-----|-------|
| `.claude/skills/tarazin-development/SKILL.md` | راهنمای عمومی کدنویسی پروژه (معماری، MudBlazor 9، RBAC) |
| `docs/BI_MODULE.md` | موتور Stimulsoft، لایسنس، فونت و خروجی BI |
| `docs/Handoff_ModuleBreakdown.md` | تفکیک ماژول‌ها و وضعیت هر بخش |
| `Tarazin.Ui/Services/PdfReportService.cs` | موتور مشترک PDF (QuestPDF) — فاکتور، چک، جدول عمومی |
| `Tarazin.Ui/Services/PdfFileNames.cs` | نام فایل استاندارد فارسی + پاک‌سازی |
| `Tarazin.Ui/Components/ReportPrintDialog.razor` | دیالوگ مشترک چاپ/پیش‌نمایش/دانلود PDF |
