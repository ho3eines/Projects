---
name: tarazin-ui-ux
description: >
  راهنمای الزامی طراحی و ساخت رابط کاربری «ترازین» — MANDATORY guide for any UI or
  UX work on this codebase. Read this BEFORE creating or editing any .razor page,
  list/table, form, dialog, picker, dashboard card, empty state, skeleton, sub-nav
  item, or any `tz-*` CSS class. It is the component catalog + copy-paste page
  skeletons + design-token reference: every shared component's exact parameter
  list, the `TarazinAccents` palette and `--tz-accent` contract, the `tz-*` CSS
  class contracts in wwwroot/css/app.css, the picker stack
  (EntityPickerField/EntityPickerService, AccountPickerField/AccountPickerService),
  the base-table CRUD flow (EntityCrudService + EntityEditorDialog and the four
  coordinated edits a new entity needs), the MudBlazor 9.8.0 parameter traps
  (MUD0002), the Razor literal-vs-expression rule, and the RTL/responsive/dark-mode
  and prefers-reduced-motion obligations. **هرگز کامپوننت تازه نساز تا این فهرست را
  چک نکرده باشی.** Complements (does not replace) `tarazin-development` for
  architecture/data/RBAC and `tarazin-reporting` for report pages and print dialogs.
---

# SKILL.md — UI/UX «ترازین» (کاتالوگ کامپوننت + اسکلت صفحه)

> ## ⚖️ قانون الزامی
> **۱) قبل از ساخت هر تکهٔ UI، §۲ (کاتالوگ کامپوننت‌ها) را بخوان.** اگر کامپوننتی
> برای کارت، جدول، فرم، حالت خالی، اسکلتون، انتخابگر، اکشن ردیف یا چیپ وضعیت وجود
> دارد، **همان را استفاده کن**؛ ساختن نسخهٔ موازی ممنوع است.
> **۲) اگر چیزی کم بود، «کامپوننت مشترک» بساز، نه کد inline.** فایل جدید در
> `Tarazin.Ui/Components/` + یک قرارداد CSS در `app.css` + یک ردیف در جدول §۲ همین
> سند. صفحه هرگز نباید markup تکراری داشته باشد.
> **۳) این سند و کد باید همیشه یکی باشند.** اگر اختلافی دیدی، **این سند را به‌روز کن**
> و مطابق کد واقعی رفتار کن.
>
> مکمل‌ها (تکرار نکن، ارجاع بده):
> - معماری/داده/RBAC/ناوبری/تم → `.claude/skills/tarazin-development/SKILL.md`
> - صفحات گزارش، دیالوگ چاپ، خروجی PDF → `.claude/skills/tarazin-reporting/SKILL.md`

---

## ۱. قوانین پایه (نقض نکن)

1. **بازاستفاده > ساخت.** جدول جدید = `TzDataTable`. حالت خالی = `EmptyState`.
   لودینگ جدول = `TableSkeleton`. سربرگ = `PageHeader`. نوار عملیات = `PageToolbar`.
   بخش فرم = `FormSection`. آیکون‌های ویرایش/حذف ردیف = `EntityActions`.
   چیپ فعال/غیرفعال = `StatusChip`. کارت آمار = `StatCard`. کارت ماژول = `ModuleCard`.
2. **`@using` لازم نیست.** `Tarazin.Ui/_Imports.razor` این‌ها را سراسری کرده است:
   `MudBlazor`, `Tarazin`, `Tarazin.Components`, `Tarazin.Components.Chart`,
   `Tarazin.Layout`, `Tarazin.Models`, `Tarazin.Services`, `Tarazin.Theme`,
   `Tarazin.Data`, `System.Globalization`, `System.Text.Json`, و فضاهای
   `Microsoft.AspNetCore.Components*` + `Microsoft.JSInterop` + `Microsoft.Extensions.Configuration`.
   **تنها استثنا:** کامپوننت‌های خصوصی یک ماژول → همان ماژول باید
   `Modules/{Module}/_Imports.razor` با `@using Tarazin.Modules.{Module}.Components`
   داشته باشد، وگرنه CS0246.
3. **`@namespace Tarazin.Components` در کامپوننت‌های مشترک تزئینی است، نه باگ.**
   `Tarazin.Ui.csproj` دارد `<RootNamespace>Tarazin</RootNamespace>`، پس فایل‌های
   پوشهٔ `Components/` **از قبل** در `Tarazin.Components` هستند. بعضی فایل‌ها این
   دایرکتیو را دارند و بعضی نه؛ هر دو یکی است — **آن را «مشکل» تلقی نکن و برای
   یکدست‌سازی، فایل‌های سالم را دست نزن.**
4. **متن UI فارسی، کد انگلیسی، کامنت فارسی (توضیح «چرا»).**
5. **RTL پیش‌فرض است.** `App.razor` → `<MudRTLProvider RightToLeft="true">`. آیکون
   «برو» در RTL باید به چپ اشاره کند: `Icons.Material.Filled.West` (کارت ماژول) یا
   `Icons.Material.Filled.ArrowBack` (کارت آمار).
6. **اعداد فارسی/جداکننده** → کلاس `tz-num` روی عنصر عددی (tabular-nums).
7. **هیچ متن خام استثنا در UI.** پیام امن با `Db.Describe`. (لیست تخلف‌های موجود در §۱۲.)
8. **هیچ SQL خام در Razor** — اسکریپت نامدار + `DbService` (رجوع: `tarazin-development` §۲).

---

## ۲. کاتالوگ کامپوننت‌های مشترک (`Tarazin.Ui/Components/`)

> همه در فضای `Tarazin.Components` و بدون `@using` قابل استفاده‌اند.

### ۲.۱ `PageHeader` — سربرگ هر صفحه (اجباری)
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Eyebrow` | `string?` | — (بالای عنوان، ریز) |
| `Title` | `string` | `""` (با `Typo.h4`) |
| `Subtitle` | `string?` | — |
| `ChildContent` | `RenderFragment?` | — (داخل `tz-pagehead__actions`) |

```razor
<PageHeader Eyebrow="حسابداری" Title="اسناد حسابداری"
            Subtitle="ثبت، ویرایش و بررسی اسناد سال مالی فعال">
    <MudButton Variant="Variant.Filled" Color="Color.Primary"
               StartIcon="@Icons.Material.Filled.Add" OnClick="NewAsync">سند جدید</MudButton>
</PageHeader>
```

### ۲.۲ `PageToolbar` — نوار عملیات بالای جدول
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `ChildContent` | `RenderFragment?` | — (فیلترها/جستجو) |
| `AddText` | `string` | `"ردیف جدید"` |
| `AddIcon` | `string?` | — |
| `AddClick` | `EventCallback` | — |
| `OnAddClick` | `Func<Task>?` | — |
| `AddDisabled` | `bool` | `false` |
| `Class` | `string?` | — |

دکمهٔ «افزودن» **فقط** وقتی رندر می‌شود که `AddClick.HasDelegate` یا `OnAddClick is not null`.

```razor
<PageToolbar AddText="کالای جدید" AddIcon="@Icons.Material.Filled.Add" OnAddClick="CreateAsync">
    <MudTextField @bind-Value="_search" Placeholder="جستجو..." Immediate="true"
                  Adornment="Adornment.Start" AdornmentIcon="@Icons.Material.Filled.Search"
                  Variant="Variant.Outlined" Margin="Margin.Dense" Class="mt-0" />
</PageToolbar>
```

### ۲.۳ `TzDataTable<T>` — جدول استاندارد (اسکلتون + حالت خالی + پیجر یکجا)
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Items` | `IReadOnlyList<T>?` **EditorRequired** | — |
| `Loading` | `bool` | `false` → `TableSkeleton` |
| `HeaderContent` | `RenderFragment` **EditorRequired** | — |
| `RowTemplate` | `RenderFragment<T>` **EditorRequired** | — (`Context="item"`) |
| `EmptyTitle` | `string` | `"داده‌ای برای نمایش وجود ندارد."` |
| `EmptyDescription` | `string?` | — |
| `EmptyIcon` | `string` | `Icons.Material.Filled.Inbox` |
| `ShowPager` | `bool` | **`false`** |
| `RowsPerPage` | `int` | `25` |
| `SkeletonColumns` | `int` | `4` |
| `SkeletonRows` | `int` | `6` |
| `Class` | `string?` | — |

داخلش: `MudPaper Elevation="1" Class="pa-4"` → `MudTable` با
`Hover Dense Striped Breakpoint="Breakpoint.Sm"`، `NoRecordsContent` → `EmptyState`،
`PagerContent` → `MudTablePager PageSizeOptions="@(new int[] { 25, 50, 100 })"`.

```razor
<TzDataTable T="ItemRow" Items="_rows" Loading="_loading" ShowPager="true"
             SkeletonColumns="5" EmptyTitle="کالایی ثبت نشده است."
             EmptyDescription="با دکمهٔ «کالای جدید» اولین ردیف را بسازید.">
    <HeaderContent>
        <MudTh>کد</MudTh>
        <MudTh>عنوان</MudTh>
        <MudTh>وضعیت</MudTh>
        <MudTh Style="text-align:center">عملیات</MudTh>
    </HeaderContent>
    <RowTemplate Context="item">
        <MudTd DataLabel="کد" Class="tz-num">@item.Code</MudTd>
        <MudTd DataLabel="عنوان">@item.Title</MudTd>
        <MudTd DataLabel="وضعیت"><StatusChip IsActive="item.IsActive" /></MudTd>
        <MudTd DataLabel="عملیات">
            <EntityActions EditClicked="() => EditAsync(item)"
                           DeleteClicked="() => DeleteAsync(item)" />
        </MudTd>
    </RowTemplate>
</TzDataTable>
```

### ۲.۴ `EmptyState` — حالت خالی
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Title` | `string` | `"داده‌ای برای نمایش وجود ندارد."` |
| `Description` | `string?` | — |
| `Icon` | `string` | `Icons.Material.Filled.Inbox` |
| `ChildContent` | `RenderFragment?` | — (دکمه‌های اقدام) |

ساختار: `MudPaper Elevation="0" Outlined="true" Class="tz-empty-state pa-6"` →
`MudStack AlignItems="AlignItems.Center" Justify="Justify.Center" Spacing="2"`.
**در `TzDataTable` خودکار رندر می‌شود** — فقط برای حالت‌های خالیِ غیرجدولی مستقیم صدا بزن.

### ۲.۵ `TableSkeleton` — اسکلتون جدول
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Rows` | `int` | `5` |
| `Columns` | `int` | `4` |

`aria-hidden="true"` دارد. **در `TzDataTable` خودکار است**؛ مستقیم فقط برای لیست‌های سفارشی.

### ۲.۶ `FormSection` — بخش‌بندی فرم‌ها
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Title` | `string` | `""` |
| `Description` | `string?` | — |
| `Icon` | `string?` | — (با `Color.Primary`) |
| `Class` | `string?` | — |
| `ChildHeader` | `RenderFragment?` | — (سمت مخالف عنوان در هدر) |
| `ChildContent` | `RenderFragment?` | — |

```razor
<FormSection Title="اطلاعات پایه" Icon="@Icons.Material.Filled.Badge"
             Description="کد و عنوان در گزارش‌ها نمایش داده می‌شود.">
    <MudGrid Spacing="2">
        <MudItem xs="12" md="4">
            <MudTextField Label="کد" @bind-Value="_model.Code" Variant="Variant.Outlined"
                          Required="true" RequiredError="کد الزامی است." />
        </MudItem>
    </MudGrid>
</FormSection>
```

### ۲.۷ `EntityActions` — آیکون‌های ویرایش/حذف ردیف
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `EditClicked` / `DeleteClicked` | `EventCallback` | — |
| `ShowEdit` / `ShowDelete` | `bool` | `true` |
| `EditDisabled` / `DeleteDisabled` | `bool` | `false` |
| `ChildContent` | `RenderFragment?` | — (اکشن اضافه) |

`MudStack Row` + `MudTooltip` («ویرایش»/«حذف») + `MudIconButton` (`Edit`/`DeleteOutline`،
`Color.Primary`/`Color.Error`، `Size.Small`، با `aria-label`).
⚠️ **هرگز `Title="..."` روی `MudIconButton` نگذار** (§۹) — همین کامپوننت الگوی درست است.

### ۲.۸ `StatusChip` — چیپ فعال/غیرفعال
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `IsActive` | `bool` | `false` |
| `ActiveText` | `string` | `"فعال"` |
| `InactiveText` | `string` | `"غیرفعال"` |

`MudChip T="string" Size="Size.Small" Variant="Variant.Outlined"` با
`Icon` (نه `StartIcon`) = `CheckCircle`/`PauseCircle` و `Color.Success`/`Color.Default`.

### ۲.۹ `StatCard` — کارت آمار داشبورد
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Label` | `string` | `""` |
| `Value` | `string` | `"—"` |
| `Icon` | `string` | `Icons.Material.Filled.Insights` |
| `Accent` | `string` | `TarazinAccents.Ink` |
| `Hint` | `string?` | — |
| `Loading` | `bool` | `false` → `MudSkeleton` جای مقدار |
| `Href` | `string?` | — (اگر بدهی، کل کارت لینک می‌شود + فلش `ArrowBack`) |
| `Xs` / `Sm` / `Md` | `int` | `12` / `6` / `3` |

**خودش `MudItem` است** — باید مستقیم داخل `MudGrid` بنشیند، نه داخل `MudItem` دیگر.

```razor
<MudGrid Spacing="3">
    <StatCard Label="اسناد امروز" Value="@_todayCount.ToString("N0")" Loading="_loading"
              Icon="@Icons.Material.Filled.Description" Accent="TarazinAccents.Ink"
              Href="/accounting/documents" Hint="کل اسناد ثبت‌شدهٔ امروز" />
    <StatCard Label="مانده صندوق" Value="@_cash.ToString("N0")" Loading="_loading"
              Icon="@Icons.Material.Filled.AccountBalanceWallet" Accent="TarazinAccents.Gold" />
</MudGrid>
```

### ۲.۱۰ `ModuleCard` + `ModuleCardSpec` — کارت ورود به ماژول
| پارامتر | نوع | پیش‌فرض |
|---|---|---|
| `Icon` / `Title` / `Lead` | `string` | `""` |
| `Url` | `string` | `"#"` |
| `Accent` | `string` | `TarazinAccents.Ink` |

`ModuleCardSpec(string Icon, string Title, string Lead, string Url, string Accent)` +
`ModuleCardSpec.FromModule(TarazinModule m)` — برای ساختن گرید از کاتالوگ ماژول‌ها:

```razor
<div class="tz-modgrid">
    @foreach (var spec in TarazinModules.All.Where(m => Session.CanView(m.Key)).Select(ModuleCardSpec.FromModule))
    {
        <ModuleCard Icon="@spec.Icon" Title="@spec.Title" Lead="@spec.Lead"
                    Url="@spec.Url" Accent="@spec.Accent" />
    }
</div>
```

### ۲.۱۱ `ModuleSubNav` — زیرمنوی ماژول
`Module` (`TarazinModule?`) + `CurrentPath` (`string`). **در `MainLayout` یک‌بار رندر
می‌شود؛ در صفحات صدا نزن.** خودش با `!item.HideInNav && Session.HasPermission(item.Permission)`
فیلتر و با `TarazinModules.IsActive` فعال‌سازی می‌کند و به `Session.Changed` گوش می‌دهد.

**نشانگر کشویی (`tz-subnav__indicator`):** نوار باریک accent زیر تبِ فعال که با تغییر تب
می‌لغزد. قرارداد سه‌بخشی — (۱) `wwwroot/js/subnav.js` تابع `tarazinSubnav.sync(container)`
را دارد که جای تب فعال را اندازه می‌گیرد و نوار را با `width/transform` می‌برد زیر آن
(بعلاوه `ResizeObserver` برای زوم/فونت دیرهنگام)؛ (۲) `ModuleSubNav` بعد از هر رندر
در `OnAfterRenderAsync` آن را صدا می‌زند (با گارد `JSDisconnectedException`)؛ (۳) CSS نوار
را در `app.css` تعریف می‌کند (`--tz-accent` روی ریشهٔ `.tz-subnav` است، رنگ از همان می‌آید).
اگر جاوااسکریپت در دسترس نباشد نوار فقط پنهان می‌ماند — تب فعال هنوز با پس‌زمینهٔ tint دیده می‌شود.
در `prefers-reduced-motion` ترنزیشن نوار هم خاموش می‌شود.

### ۲.۱۲ `PrintBrandHeader` — سربرگ چاپ
`CompanyName` (پیش‌فرض «ترازین — سامانه یکپارچه مدیریت کسب‌وکار»)، `Title`،
`HeaderOnly` (`true`)، `QrEnabled` (`true`)، `QrPayload?`.
فقط در چاپ دیده می‌شود (`print-only`). جزئیات چاپ → `tarazin-reporting`.

### ۲.۱۳ انتخابگرها
`EntityPickerField<T>`، `AccountPickerField`، `SelectorDialog<T>` → §۶.

### ۲.۱۴ `TzNumericField<T>` — فیلد عددی استاندارد (جداکنندهٔ سه‌رقمی runtime)
به‌جای `MudNumericField` استفاده کنید. متن را خودش parse می‌کند، پس گروه‌بندی
سه‌رقمی «حین تایپ» اعمال می‌شود (نه فقط بعد از بلور). ارقام فارسی/عربی نرمال،
ممیز نقطه/اسلش/«،»، و `Min`/`Max`.

**بازخورد خطا (به‌جای ردِ بی‌صدا):**
- ورودیِ نامعتبر (ممیز تکراری، نویسهٔ غیرعددی، سرریز) متنِ تایپ‌شده را نگه می‌دارد
  و با `Error`/`ErrorText` مادبلیزر قرمز می‌شود — پیام از `TzNumericText.RejectionReason`
  می‌آید (خالص و تست‌شده). حالت‌های میانیِ تایپ («-»، «.») خطا نمی‌گیرند.
- خارج از بازهٔ `Min`/`Max` حین تایپ قرمز می‌شود («حداقل/حداکثر مجاز: X») و مقدارِ
  محدودشده فقط هنگام blur/Enter ثبت (clamp) می‌شود؛ وسط تایپ بی‌صدا عوض نمی‌شود.
- عددِ فراتر از دامنهٔ نوع صحیح (مثل int) خطا می‌گیرد، نه exception.

```razor
@* T: decimal, decimal?, int, int?, long, ... *@
<TzNumericField T="decimal?" @bind-Value="_amount" Label="مبلغ" />
@* شناسه‌ها (شماره فاکتور، شناسهٔ ردیف) گروه‌بندی نمی‌خواهند: *@
<TzNumericField T="int?" @bind-Value="_refId" GroupThousands="false" />
```

مغزِ فرمت‌بندی `TzNumericText.cs` است (تست واحد: `Tarazin.Tests/TzNumericTextTests.cs`).
قراردادِ خطای بالا در سطح کامپوننت هم بند شده است: `Tarazin.Tests/TzNumericFieldTests.cs`
(bUnit — رویدادها از طریق EventCallbackهای MudTextField داخلی زده می‌شوند). اگر قرارداد
تغییر کرد (مثلاً «ردِ سخت» به‌جای clamp) همان‌جا را به‌روز کنید.
هیچ‌جا `MudNumericField` جدید اضافه نکنید — حتی برای int.

**نمایش عدد در سلول‌های جدول** (`TzNumericText.Format`) — همان سبکِ فیلد:
در سلول‌های فقط‌خواندنیِ جداول (`TzDataTable`/`MudTable`) عدد را با overloadهای
نمایشِ `TzNumericText.Format` چاپ کنید، نه `ToString("N0")`/`("N2")` ثابت:

```razor
<MudTd DataLabel="مبلغ">@TzNumericText.Format(item.TotalAmount)</MudTd>
<MudTd DataLabel="نرخ">@TzNumericText.Format(item.AvgRate) @* decimal? → null = خالی *@</MudTd>
@* int/long (شمارنده‌ها) هم overload دارند: TzNumericText.Format(row.Count) *@
```

علت: `#,##0.####` گروه‌بندیِ همان `TzNumericField` را می‌دهد و ارقامِ اعشاریِ
واقعی را بی‌صدا گرد/صفرچسبان نمی‌کند (`12.5` همان `12.5` می‌ماند، نه `13` یا `12.50`).
استثناهای عمدی: وزن گرم (گرم‌های اندازه‌گیری‌شده) با رقم ثابت `"N3"` می‌ماند —
خودِ مقدار را قالب‌بندی نکنید، فقط سلول‌های پول/نرخ/مقدار را.
فرهنگ جاری است (fa-IR در وب و MAUI)؛ null → رشتهٔ خالی.

---

## ۳. اسکلت‌های آمادهٔ صفحه (کپی کن)

### ۳.۱ صفحهٔ لیست/CRUD جدول پایه
نمونهٔ واقعی: `Tarazin.Ui/Modules/Inventory/Pages/InventoryItems.razor` — کپی کنید و با ماژول/موجودیت خود تطبیق دهید:
```razor
@page "/inventory/items"
@inject DbService Db
@inject UserSession Session
@inject EntityCrudService Crud
@inject ISnackbar Snackbar

<PageHeader Eyebrow="انبار" Title="کالاها" Subtitle="فهرست کالاهای شرکت فعال" />

<PageToolbar AddText="کالای جدید" AddIcon="@Icons.Material.Filled.Add" OnAddClick="CreateAsync"
             AddDisabled="@(!Session.HasPermission(ItemsEditPermission))">
    <MudTextField @bind-Value="_search" Placeholder="جستجو در کد/عنوان/گروه..." Immediate="true"
                  Adornment="Adornment.Start" AdornmentIcon="@Icons.Material.Filled.Search"
                  Variant="Variant.Outlined" Margin="Margin.Dense" Class="mt-0" />
</PageToolbar>

<TzDataTable T="ItemRow" Items="_filtered" Loading="_loading" ShowPager="true"
             SkeletonColumns="5" EmptyTitle="کالایی ثبت نشده است.">
    <HeaderContent>
        <MudTh>کد</MudTh>
        <MudTh>عنوان</MudTh>
        <MudTh>گروه</MudTh>
        <MudTh>وضعیت</MudTh>
        <MudTh Style="text-align:center">عملیات</MudTh>
    </HeaderContent>
    <RowTemplate Context="item">
        <MudTd DataLabel="کد" Class="tz-num">@item.ItemCode</MudTd>
        <MudTd DataLabel="عنوان">@item.ItemTitle</MudTd>
        <MudTd DataLabel="گروه">@(item.GroupTitle ?? item.Category)</MudTd>
        <MudTd DataLabel="وضعیت"><StatusChip IsActive="item.IsActive" /></MudTd>
        <MudTd DataLabel="عملیات">
            <EntityActions EditClicked="() => EditAsync(item)"
                           DeleteClicked="() => DeleteAsync(item)"
                           EditDisabled="!Session.HasPermission(ItemsEditPermission)"
                           DeleteDisabled="!Session.HasPermission(ItemsEditPermission)" />
        </MudTd>
    </RowTemplate>
</TzDataTable>

@code {
    private const string Schema = "inventory";
    private const string ItemsViewPermission = "inventory.view";
    private const string ItemsEditPermission = "inventory.admin";

    private IReadOnlyList<ItemRow> _rows = Array.Empty<ItemRow>();
    private string _search = "";
    private bool _loading = true;

    private IReadOnlyList<ItemRow> _filtered =>
        string.IsNullOrWhiteSpace(_search)
            ? _rows
            : _rows.Where(r => (r.ItemCode ?? "").Contains(_search, StringComparison.OrdinalIgnoreCase)
                            || (r.ItemTitle ?? "").Contains(_search, StringComparison.OrdinalIgnoreCase)
                            || (r.Category ?? "").Contains(_search, StringComparison.OrdinalIgnoreCase)).ToList();

    protected override async Task OnInitializedAsync() => await ReloadAsync();

    private async Task ReloadAsync()
    {
        _loading = true;
        try { _rows = await Db.QueryAsync<ItemRow>(Schema, "ItemList", new { CompanyId = Db.CurrentCompanyId }); }
        finally { _loading = false; }
    }

    private async Task CreateAsync()
    {
        var model = EntityEditorModel.FromInventoryItem();
        if (await Crud.ShowEditorAsync(model)) await ReloadAsync();
    }

    private async Task EditAsync(ItemRow row)
    {
        var model = EntityEditorModel.FromInventoryItem(row);
        if (await Crud.ShowEditorAsync(model)) await ReloadAsync();
    }

    private async Task DeleteAsync(ItemRow row)
    {
        var model = EntityEditorModel.FromInventoryItem(row);
        if (await Crud.ConfirmDeleteAsync(model)) await ReloadAsync();
    }
}
```
> ⚠️ نام دقیق کارخانهٔ `EntityEditorModel` (۱۳ کارخانه) و کلید دقیق دسترسی را از
> `Tarazin.Ui/Components/EntityEditorModel.cs` و `Tarazin.Share/Permissions.cs` بردار — **حدس نزن**.
> الگوی نام کارخانه‌ها `From{{Entity}}` است (`FromInventoryItem(ItemRow?)`، `FromGoldItem`، …) و
> **مجوزِ `TarazinPermissions.InventoryEdit` وجود ندارد** — صفحات انبار از const محلی
> `ItemsEditPermission = "inventory.admin"` استفاده می‌کنند. پارامترهای `EntityActions` فقط
> `EditClicked`/`DeleteClicked` (و `EditDisabled`/`DeleteDisabled`/`ShowEdit`/`ShowDelete`) است، نه `OnEdit`/`OnDelete`.

### ۳.۲ صفحهٔ فرم/ثبت
```razor
<PageHeader Eyebrow="حسابداری" Title="ثبت سند" Subtitle="اطلاعات سرسند و آرتیکل‌ها" />

<MudForm @ref="_form" @bind-IsValid="_isValid">
    <MudStack Spacing="3">
        <FormSection Title="سرسند" Icon="@Icons.Material.Filled.Description">
            <MudGrid Spacing="2">
                <MudItem xs="12" md="4">
                    <MudDatePicker Label="تاریخ" @bind-Date="_model.Date" Variant="Variant.Outlined" />
                </MudItem>
                <MudItem xs="12" md="8">
                    <MudTextField Label="شرح" @bind-Value="_model.Text" Lines="2"
                                  Variant="Variant.Outlined" Required="true"
                                  RequiredError="شرح سند الزامی است." />
                </MudItem>
            </MudGrid>
        </FormSection>

        <FormSection Title="آرتیکل‌ها" Icon="@Icons.Material.Filled.List">
            <ChildHeader>
                <MudButton Variant="Variant.Text" Color="Color.Primary"
                           StartIcon="@Icons.Material.Filled.Add" OnClick="AddLine">افزودن ردیف</MudButton>
            </ChildHeader>
            <ChildContent>
                <TzDataTable T="EntryLine" Items="_lines" HeaderContent="@LineHeader" RowTemplate="@LineRow"
                             EmptyTitle="هنوز آرتیکلی اضافه نشده است." />
            </ChildContent>
        </FormSection>

        <MudStack Row="true" Justify="Justify.FlexEnd" Spacing="2">
            <MudButton Variant="Variant.Text" Color="Color.Default" OnClick="ResetAsync"
                       Disabled="_busy">انصراف</MudButton>
            <MudButton Variant="Variant.Filled" Color="Color.Primary" Disabled="_busy"
                       StartIcon="@Icons.Material.Filled.Save" OnClick="SaveAsync">ذخیره</MudButton>
        </MudStack>
    </MudStack>
</MudForm>
```
ذخیره همیشه: `await _form.ValidateAsync(); if (!_isValid) return;` + گارد `_busy` +
`Snackbar.Add("ذخیره شد.", Severity.Success)` + پیام خطای امن.

### ۳.۳ داشبورد ماژول
```razor
<PageHeader Eyebrow="طلا و جواهر" Title="داشبورد" Subtitle="نمای کلی امروز" />

<MudGrid Spacing="3" Class="align-center">
    <StatCard Label="فروش امروز" Value="@_sales" Loading="_loading" Accent="TarazinAccents.Gold"
              Icon="@Icons.Material.Filled.PointOfSale" Href="/goldshop/entry" />
    <StatCard Label="مانده مشتریان" Value="@_ar" Loading="_loading" Accent="TarazinAccents.Steel"
              Icon="@Icons.Material.Filled.Group" Href="/goldshop/customers" />
</MudGrid>
```
⚠️ برای تراز عمودی روی `MudGrid` **`Class="align-center"`** بگذار — `AlignItems` روی
`MudGrid` وجود ندارد (§۹).

### ۳.۴ صفحهٔ گزارش
اسکلت گزارش‌ها، `ReportPrintDialog`، `PdfReportService.BuildTablePdf` و `PdfFileNames`
**در همین سند تکرار نمی‌شوند** → `.claude/skills/tarazin-reporting/SKILL.md` را بخوان.
از این سند فقط `PageHeader` + `PageToolbar` (فیلترها) + `TzDataTable` (پیش‌نمایش) را بردار.

---

## 🔁 حلقهٔ ارجاع

> مرجع اصلی پروژه: [`README.md`](../../README.md) — فهرست یک‌جای اسکیل‌ها: [`docs/SKILLS_INDEX.md`](../../docs/SKILLS_INDEX.md) — دست‌نوشت و وضعیت ماژول‌ها: [`docs/Handoff.md`](../../docs/Handoff.md) و [`docs/Handoff_ModuleBreakdown.md`](../../docs/Handoff_ModuleBreakdown.md).
