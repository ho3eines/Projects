---
name: mudblazor
description: MudBlazor component patterns for Tarazin — Table, Dialog, Form, TextField, Select, DatePicker, NumericField, Snackbar, Grid. Grounded in the official MudBlazor docs API. RTL/Persian aware.
category: blazor
author: ho3eines, Hermes Agent
license: MIT
platforms: [windows, linux, macos]
metadata:
  hermes:
    tags: [blazor, mudblazor, components, table, dialog, form, persian, rtl]
    related_skills: [tarazin-project-architecture, blazor-data-access, mudblazor-crud-dialogs, blazor-server-admin-pages]
---

# MudBlazor — Component Patterns for Tarazin

MudBlazor is the **only** UI kit allowed in Tarazin (PRD v2/v3 — ADR-005).
All Tarazin pages live in `Tarazin.Ui/Modules/...` (web) or are shared via the
RCL (also used by `Tarazin.Maui`). No Bootstrap, no hand-rolled grid/dialog.

Official docs: https://mudblazor.com/docs/overview
All snippets below are verified against the MudBlazor `dev` docs source.

## When to Use
- Building any page/component in Tarazin (`Tarazin.Ui` RCL).
- Replacing a Bootstrap/custom component with its MudBlazor equivalent.
- Adding tables, forms, dialogs, pickers, or feedback (snackbar) UI.
- Anything RTL/Persian (date picker culture, right-aligned layout).

## Setup (already done in Tarazin)
- Both hosts register: `builder.Services.AddMudServices();`
- `Tarazin.Ui/App.razor` renders `<MudThemeProvider/>`, `<MudDialogProvider/>`,
  `<MudSnackbarProvider/>`, `<MudPopoverProvider/>` (wrap the `<MudLayout>`).
- Pages inject `DbService` (never `HttpClient`) for data.

---

## 1. MudTable (lists / grids)

Basic (in-memory `Items`):

```razor
<MudTable Items="@_rows" Hover="true" Dense="true" Striped="true"
          Loading="@_loading" Breakpoint="Breakpoint.Sm">
    <HeaderContent>
        <MudTh>شناسه</MudTh>
        <MudTh>عنوان</MudTh>
    </HeaderContent>
    <RowTemplate>
        <MudTd DataLabel="شناسه">@context.Id</MudTd>
        <MudTd DataLabel="عنوان">@context.Title</MudTd>
    </RowTemplate>
    <NoRecordsContent><MudText>رکوردی یافت نشد</MudText></NoRecordsContent>
    <LoadingContent><MudText>در حال بارگذاری...</MudText></LoadingContent>
    <PagerContent><MudTablePager /></PagerContent>
</MudTable>
```

Server-side paging (Tarazin standard — data from `DbService`):

```razor
<MudTable ServerData="ServerReload" @ref="_table" Dense="true" Hover="true">
    <ToolBarContent>
        <MudTextField T="string" Value="@_search" ValueChanged="OnSearch"
                      Placeholder="جستجو" Adornment="Adornment.Start"
                      AdornmentIcon="@Icons.Material.Filled.Search" />
    </ToolBarContent>
    <HeaderContent>
        <MudTh><MudTableSortLabel SortLabel="title" T="Row">عنوان</MudTableSortLabel></MudTh>
    </HeaderContent>
    <RowTemplate>
        <MudTd DataLabel="عنوان">@context.Title</MudTd>
    </RowTemplate>
    <PagerContent><MudTablePager /></PagerContent>
</MudTable>

@code {
    private MudTable<Row> _table = default!;
    private string _search = "";

    private async Task<TableData<Row>> ServerReload(TableState state, CancellationToken token)
    {
        var rows = (await Db.QueryAsync<Row>("schema", "ListScript",
            new { SearchText = _search, SkipRows = state.Page * state.PageSize,
                  TakeSize = state.PageSize,
                  SortLabel = state.SortLabel,
                  SortDir = state.SortDirection == SortDirection.Ascending ? "ASC" : "DESC" })).ToList();
        var total = Convert.ToInt32(await Db.ScalarAsync("schema", "ListCount", new { SearchText = _search }));
        return new TableData<Row> { Items = rows, TotalItems = total };
    }

    private void OnSearch(string s) { _search = s; _table.ReloadServerData(); }
}
```

Key facts:
- `ServerData` returns `Task<TableData<T>>`; call `_table.ReloadServerData()` to
  refresh after a mutation.
- `MudTableSortLabel SortLabel="x" T="Row"` drives `state.SortLabel`.
- `DataLabel` gives responsive column headers on mobile.
- For totals, show a `MudText` below the table (don't rely on `FooterContent`).

---

## 2. MudDialog (CRUD editor — see `mudblazor-crud-dialogs`)

Open from a page:

```csharp
@inject IDialogService DialogService

var parameters = new DialogParameters<EditorDialog> { { x => x.Model, model } };
var options = new DialogOptions { MaxWidth = MaxWidth.Small, FullWidth = true,
                                  CloseButton = true, CloseOnEscapeKey = true };
var dialog = await DialogService.ShowAsync<EditorDialog>("عنوان", parameters, options);
var result = await dialog.Result;
if (result is { Canceled: false })
    await LoadAsync();   // reload list from SQL
```

Inside the dialog component (`<MudDialog>` root):

```razor
<MudDialog>
    <DialogContent>
        <MudForm @ref="_form" @bind-IsValid="_isValid">
            <MudTextField T="string" @bind-Value="Model.Title" Label="عنوان"
                          Required="true" RequiredError="عنوان الزامی است" />
        </MudForm>
    </DialogContent>
    <DialogActions>
        <MudButton OnClick="Cancel">انصراف</MudButton>
        <MudButton Color="Color.Primary" Variant="Variant.Filled"
                   OnClick="SaveAsync" Disabled="_busy">ذخیره</MudButton>
    </DialogActions>
</MudDialog>

@code {
    [CascadingParameter] private IMudDialogInstance MudDialog { get; set; } = default!;
    [Parameter, EditorRequired] public EditorModel Model { get; set; } = default!;
    private MudForm _form = default!;
    private bool _isValid;
    private bool _busy;

    private void Cancel() => MudDialog.Cancel();

    private async Task SaveAsync()
    {
        if (!_isValid) return;
        _busy = true;
        try { /* Db.ExecuteAsync("schema", "Upsert", Model); */ }
        finally { _busy = false; }
        MudDialog.Close(DialogResult.Ok(true));
    }
}
```

Key facts:
- `IMudDialogInstance` (cascading) → `Close(DialogResult.Ok(value))` / `Cancel()`.
- `DialogParameters<T>` uses expression keys: `{ x => x.Model, value }`.
- `result.Canceled` is true on Cancel/escape/backdrop; `result.Data` holds the
  `Ok` payload.

---

## 3. MudForm (validation)

```razor
<MudForm @ref="_form" @bind-IsValid="_isValid">
    <MudTextField T="string" @bind-Value="_name" Label="نام"
                  Required="true" RequiredError="نام الزامی است" />
    <MudTextField T="string" @bind-Value="_email" Label="ایمیل"
                  Validation="@(new EmailAddressAttribute())" />
    <MudButton OnClick="@(() => _form.ValidateAsync())">بررسی</MudButton>
    <MudButton OnClick="@(() => _form.ResetAsync())">بازنشانی</MudButton>
</MudForm>
```

Key facts:
- `Required="true"` + `RequiredError="..."`; disable submit with `Disabled="@(!_isValid)"`.
- `Validation` accepts `ValidationAttribute` or `Func<T, IEnumerable<string>>`.
- Data-annotation attributes on the model also work (`[Required]`, `[EmailAddress]`).

---

## 4. MudTextField / MudNumericField

```razor
<MudTextField T="string" @bind-Value="Text" Label="استاندارد" Variant="Variant.Outlined" />
<MudNumericField T="int" @bind-Value="Count" Label="تعداد" Min="0" Max="1000" />
<MudNumericField T="decimal" @bind-Value="Amount" Label="مبلغ" Step=".01M"
                  Culture="@(CultureInfo.GetCultureInfo("fa-IR"))" />
```

Key facts:
- Always specify `T="..."` (generic) for strongly-typed binding.
- Helpers: `HelperText`, `Adornment`, `AdornmentIcon`, `InputType="InputType.Password"`.
- Two-way binding inside `RowTemplate`: use
  `Value="context.X" ValueChanged="v => context.X = v"` (never `@bind-Value` on
  a table row context).

---

## 5. MudSelect

```razor
<MudSelect @bind-Value="_role" Label="نقش" Placeholder="انتخاب نقش"
           Adornment="Adornment.Start" AdornmentIcon="@Icons.Material.Filled.Shield">
    <MudSelectItem Value="@("admin")">مدیر</MudSelectItem>
    <MudSelectItem Value="@("user")">کاربر</MudSelectItem>
</MudSelect>

@* enum or object binding *@
<MudSelect @bind-Value="_drink" Label="نوشیدنی">
    @foreach (Drink d in Enum.GetValues(typeof(Drink)))
        { <MudSelectItem Value="@d">@d</MudSelectItem> }
</MudSelect>
```

Key facts:
- For nullable: model holds `(int?)null`; pass the literal `null` in the model,
  not in the component expression.
- Bound objects need `ToStringFunc` or a sensible `ToString()`.

---

## 6. MudDatePicker (Persian / RTL)

```razor
<MudDatePicker @bind-Date="_date" Label="تاریخ" Culture="@PersianCulture"
               DateFormat="yyyy/MM/dd" TitleDateFormat="dddd, dd MMMM" />

@code {
    private DateTime? _date = DateTime.Today;

    private CultureInfo PersianCulture
        => new CultureInfo("fa-IR")
        {
            DateTimeFormat = { ShortDatePattern = "yyyy/MM/dd", FirstDayOfWeek = DayOfWeek.Saturday }
        };
}
```

Key facts:
- `@bind-Date` is `DateTime?`. For editable text input add `Editable="true"`.
- Persian culture: `new CultureInfo("fa-IR")`; set `FirstDayOfWeek = Saturday`.
- `MudTimePicker` is the time-only sibling (`@bind-Time="TimeSpan?"`).

---

## 7. MudSnackbar (feedback)

```csharp
@inject ISnackbar Snackbar

Snackbar.Add("ذخیره شد", Severity.Success);
Snackbar.Add("خطا در ذخیره", Severity.Error);
Snackbar.Add("هشدار", Severity.Warning);

// with action
Snackbar.Add("عملیات ناموفق بود", Severity.Error, cfg =>
{
    cfg.Action = "تلاش مجدد";
    cfg.OnClick = _ => RetryAsync();
});
```

Key facts:
- `Severity`: `Normal`, `Success`, `Warning`, `Error`, `Info`.
- `cfg.Action`, `cfg.ActionColor`, `cfg.OnClick`, `cfg.RequireInteraction`.
- Requires `<MudSnackbarProvider/>` in `App.razor` (Tarazin has it).

---

## 8. MudGrid / MudItem (layout)

```razor
<MudGrid>
    <MudItem xs="12" sm="6" md="4">
        <MudPaper Class="pa-4">...</MudPaper>
    </MudItem>
</MudGrid>
```

Key facts:
- 12-column flex grid. `xs` (phone) / `sm` (tablet) / `md`/`lg` (desktop).
- Use `MudPaper Class="pa-4"` for card-like surfaces.
- `MudSpacer` pushes items right inside toolbars/flex rows.

---

## 9. Icons & misc

```razor
<MudIconButton Icon="@Icons.Material.Filled.Edit"   Color="Color.Primary" OnClick="..." />
<MudIconButton Icon="@Icons.Material.Filled.Delete" Color="Color.Error"   OnClick="..." />
<MudButton Variant="Variant.Filled" Color="Color.Primary" StartIcon="@Icons.Material.Filled.Add">افزودن</MudButton>
<MudSwitch @bind-Value="_active" Color="Color.Primary">فعال</MudSwitch>
<MudCheckBox T="bool" @bind-Value="_agree" Label="موافقم" />
```

---

## 10. RTL / Persian conventions (Tarazin)

- `App.razor` / `_Host.cshtml` use `<html lang="fa" dir="rtl">`.
- Date pickers: always pass `Culture="fa-IR"` (see §6).
- Numbers: `MudNumericField` with `Culture="fa-IR"` shows Persian digits if the
  culture is set; otherwise use `InvariantCulture` for storage.
- Table `DataLabel` ensures headers appear on small screens (RTL safe).

## 11. Pitfalls (hard-won)

1. **Don't `@bind-Value` on a `RowTemplate` context** — use
   `Value` + `ValueChanged`.
2. **`MudSelect` nullable** — set `null` in the model, not the markup.
3. **`DialogParameters<T>`** keys are lambda expressions, not strings.
4. **`ShowMessageBoxAsync` returns `bool?`** — only `true` means confirm.
5. **`result.Canceled`** (not `result == null`) detects cancel in dialogs.
6. **Server-side table** — must call `ReloadServerData()` after C/U/D.
7. **No `HttpClient`** in Tarazin pages — use `DbService`.
8. **Provider missing** — `<MudDialogProvider/>` and `<MudSnackbarProvider/>`
   must wrap the layout or dialogs/snackbars won't render.
9. **`MudForm` submit** — guard with `@bind-IsValid` + `Disabled="@(!_isValid)"`.

## 12. Verification

```text
dotnet build Tarazin.Web/Tarazin.Web.csproj -c Release
bash tools/cross-schema-scan.sh
```

Then manually:
- Table: loads, pages, sorts, search filters.
- Dialog: opens, saves (new + edit), cancel changes nothing.
- Form: required fields block submit; validation messages show.
- DatePicker: Persian calendar renders, value binds.
- Snackbar: appears on success/error.
