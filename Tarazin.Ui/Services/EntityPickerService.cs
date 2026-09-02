using MudBlazor;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// تنظیمات فراخوانی Entity Picker — عمومی و قابل استفاده برای هر نوع موجودیت.
/// </summary>
/// <typeparam name="T">نوع موجودیت (BankRow, CustomerRow, ProductRow, ...)</typeparam>
public sealed class EntityPickerOptions<T>
{
    // ─── ظاهر دیالوگ ───
    /// <summary>عنوان دیالوگ (مثلاً «انتخاب بانک»، «انتخاب مشتری»).</summary>
    public string Title { get; init; } = "انتخاب";

    /// <summary>متن placeholder فیلد جستجو.</summary>
    public string SearchPlaceholder { get; init; } = "جستجو...";

    /// <summary>عرض دیالوگ.</summary>
    public MaxWidth MaxWidth { get; init; } = MaxWidth.Medium;

    // ─── منبع داده (یکی از دو) ───
    /// <summary>لیست مستقیم آیتم‌ها (برای لیست‌های کوچک).</summary>
    public List<T>? Items { get; set; }

    /// <summary>بارگذاری غیرهمگام (برای لیست‌های بزرگ؛ اسکلتون خودکار نمایش داده می‌شود).</summary>
    public Func<Task<List<T>>>? LoadAsync { get; init; }

    // ─── ستون‌ها (الزامی) ───
    /// <summary>تعریف ستون‌های جدول انتخاب.</summary>
    public List<Components.SelectorDialog<T>.SelectorColumn<T>> Columns { get; init; } = new();

    // ─── رفتار ───
    /// <summary>متن نمایشی برای آیتم انتخاب‌شده (در خلاصهٔ پایین دیالوگ).</summary>
    public Func<T, string>? DisplayText { get; set; }

    /// <summary>فیلدهای قابل جستجو (پیش‌فرض: خروجی همهٔ ستون‌ها).</summary>
    public Func<T, string[]>? SearchFields { get; set; }

    /// <summary>تعداد ردیف در هر صفحه.</summary>
    public int RowsPerPage { get; init; } = 10;

    /// <summary>فعال‌سازی Virtualization برای لیست‌های خیلی بزرگ (۲۰۰+ ردیف).</summary>
    public bool EnableVirtualization { get; init; } = false;
}

/// <summary>
/// سرویس سراسری Entity Picker — یک دیالوگ <see cref="Components.SelectorDialog{T}"/> باز می‌کند
/// و نتیجه را به صورت نوع‌امن برمی‌گرداند.
/// ثبت در DI: <c>builder.Services.AddScoped&lt;EntityPickerService&gt;();</c>
/// </summary>
public sealed class EntityPickerService
{
    private readonly IDialogService _dialogs;

    public EntityPickerService(IDialogService dialogs)
    {
        _dialogs = dialogs;
    }

    /// <summary>
    /// باز کردن دیالوگ انتخاب عمومی. در صورت لغو یا بستن، null برمی‌گردد.
    /// </summary>
    /// <typeparam name="T">نوع موجودیت.</typeparam>
    /// <param name="options">تنظیمات انتخاب.</param>
    /// <returns>آیتم انتخاب‌شده یا null.</returns>
    public async Task<T?> PickAsync<T>(EntityPickerOptions<T> options)
    {
        ArgumentNullException.ThrowIfNull(options);

        var parameters = new DialogParameters<Components.SelectorDialog<T>>
        {
            { x => x.Items, options.Items ?? new List<T>() },
            { x => x.Title, options.Title },
            { x => x.SearchPlaceholder, options.SearchPlaceholder },
            { x => x.Columns, options.Columns },
            { x => x.DisplayText, options.DisplayText },
            { x => x.SearchFields, options.SearchFields },
            { x => x.RowsPerPage, options.RowsPerPage },
            { x => x.EnableVirtualization, options.EnableVirtualization },
        };

        var dlgOptions = new DialogOptions
        {
            MaxWidth = options.MaxWidth,
            FullWidth = true,
            CloseButton = true,
            CloseOnEscapeKey = true,
            BackdropClick = false,
        };

        var dialog = await _dialogs.ShowAsync<Components.SelectorDialog<T>>(options.Title, parameters, dlgOptions);
        var result = await dialog.Result;

        if (result is null || result.Canceled)
            return default;

        if (result.Data is Components.SelectorDialog<T>.SelectorResult<T> picked)
            return picked.Item;

        return default;
    }

    /// <summary>
    /// انتخاب چندتایی — لیستی از آیتم‌های انتخاب‌شده برمی‌گرداند (در حالت لغو، لیست خالی).
    /// </summary>
    public async Task<List<T>> PickManyAsync<T>(EntityPickerOptions<T> options)
    {
        ArgumentNullException.ThrowIfNull(options);

        var parameters = new DialogParameters<Components.SelectorDialog<T>>
        {
            { x => x.Items, options.Items ?? new List<T>() },
            { x => x.Title, options.Title },
            { x => x.SearchPlaceholder, options.SearchPlaceholder },
            { x => x.Columns, options.Columns },
            { x => x.DisplayText, options.DisplayText },
            { x => x.SearchFields, options.SearchFields },
            { x => x.RowsPerPage, options.RowsPerPage },
            { x => x.EnableVirtualization, options.EnableVirtualization },
            { x => x.MultiSelect, true },
            { x => x.ConfirmLabel, "تأیید" },
        };

        var dlgOptions = new DialogOptions
        {
            MaxWidth = options.MaxWidth,
            FullWidth = true,
            CloseButton = true,
            CloseOnEscapeKey = true,
            BackdropClick = false,
        };

        var dialog = await _dialogs.ShowAsync<Components.SelectorDialog<T>>(options.Title, parameters, dlgOptions);
        var result = await dialog.Result;

        if (result is null || result.Canceled)
            return new();

        if (result.Data is Components.SelectorDialog<T>.SelectorResult<T> picked)
            return picked.Items;

        return new();
    }
}
