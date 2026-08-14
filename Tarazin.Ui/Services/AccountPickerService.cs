using MudBlazor;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// تنظیمات فراخوانی Account Picker.
/// </summary>
public sealed class AccountPickerOptions
{
    /// <summary>عنوان Modal.</summary>
    public string Title { get; init; } = "انتخاب حساب";

    /// <summary>محدودسازی نوع حساب (NULL=همه).</summary>
    public AccountPickerType? AllowedType { get; init; }

    /// <summary>اگر true، فقط حساب‌های نهایی قابل ثبت سند (= BaseDetil) نمایش داده می‌شوند.</summary>
    public bool TransactionalOnly { get; init; }

    /// <summary>نمایش حساب‌های غیرفعال در لیست.</summary>
    public bool ShowInactive { get; init; }
}

public enum AccountPickerType
{
    Col,
    Moein,
    Detil
}

/// <summary>
/// سرویس سراسری Account Picker — یک Modal در
/// <see cref="Components.AccountPickerDialog"/> باز می‌کند.
/// </summary>
public sealed class AccountPickerService
{
    private readonly IDialogService _dialogs;

    public AccountPickerService(IDialogService dialogs)
    {
        _dialogs = dialogs;
    }

    /// <summary>نمایش Modal و بازگرداندن نتیجه. در صورت لغو، null برمی‌گردد.</summary>
    public async Task<AccountPickerResult?> PickAsync(AccountPickerOptions? options = null)
    {
        options ??= new AccountPickerOptions();

        var parameters = new DialogParameters<Components.AccountPickerDialog>
        {
            { x => x.Options, options }
        };

        var dlgOptions = new DialogOptions
        {
            MaxWidth = MaxWidth.Large,
            FullWidth = true,
            CloseButton = true,
            CloseOnEscapeKey = true,
            BackdropClick = false
        };

        var dialog = await _dialogs.ShowAsync<Components.AccountPickerDialog>(options.Title, parameters, dlgOptions);
        var result = await dialog.Result;
        if (result is null || result.Canceled)
            return null;
        if (result.Data is AccountPickerResult picked)
            return picked;
        return null;
    }
}
