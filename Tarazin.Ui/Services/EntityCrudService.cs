using MudBlazor;
using Tarazin.Components;
using Tarazin.Data;

namespace Tarazin.Services;

/// <summary>
/// الگوی مشترک عملیات CRUD جداول پایه: فرم ایجاد/ویرایش در MudDialog و
/// تأیید حذف در MudBlazor MessageBox.
/// </summary>
public sealed class EntityCrudService
{
    private static readonly DialogOptions DeleteOptions = new()
    {
        MaxWidth = MaxWidth.ExtraSmall,
        FullWidth = true,
        CloseOnEscapeKey = true,
        BackdropClick = false
    };

    private readonly DbService _db;
    private readonly IDialogService _dialogs;
    private readonly ISnackbar _snackbar;

    public EntityCrudService(DbService db, IDialogService dialogs, ISnackbar snackbar)
    {
        _db = db;
        _dialogs = dialogs;
        _snackbar = snackbar;
    }

    /// <summary>نمایش فرم و برگرداندن true فقط پس از ذخیرهٔ موفق.</summary>
    public async Task<bool> ShowEditorAsync(EntityEditorModel model)
    {
        var parameters = new DialogParameters<EntityEditorDialog>
        {
            { x => x.Model, model }
        };
        var options = new DialogOptions
        {
            MaxWidth = MaxWidth.Small,
            FullWidth = true,
            CloseButton = true,
            CloseOnEscapeKey = true
        };

        var dialog = await _dialogs.ShowAsync<EntityEditorDialog>(model.DialogTitle, parameters, options);
        var result = await dialog.Result;
        return result is { Canceled: false };
    }

    /// <summary>گرفتن تأیید MessageBox و اجرای حذف؛ لغو یا خطا false برمی‌گرداند.</summary>
    public async Task<bool> ConfirmDeleteAsync(EntityEditorModel model)
    {
        if (model.IsNew)
            return false;

        var confirmed = await _dialogs.ShowMessageBoxAsync(
            "تأیید حذف",
            $"آیا از حذف {model.EntityTitle} «{model.DisplayLabel}» مطمئن هستید؟ این عملیات قابل بازگشت نیست.",
            yesText: "حذف",
            cancelText: "انصراف",
            options: DeleteOptions);

        if (confirmed is not true)
            return false;

        try
        {
            var affected = await DeleteAsync(model);
            if (affected == 0)
                throw new InvalidOperationException("رکورد پیدا نشد یا قبلاً حذف شده است.");

            _snackbar.Add($"{model.EntityTitle} با موفقیت حذف شد.", Severity.Success);
            return true;
        }
        catch (Exception ex)
        {
            _snackbar.Add(ex.Message, Severity.Error);
            return false;
        }
    }

    private Task<int> DeleteAsync(EntityEditorModel model) => model.Kind switch
    {
        EntityEditorKind.News =>
            _db.ExecuteAsync("central", "NewsDelete", new { NewsId = model.Id }),
        EntityEditorKind.Blog =>
            _db.ExecuteAsync("central", "BlogDelete", new { PostId = model.Id }),
        EntityEditorKind.Gallery =>
            _db.ExecuteAsync("central", "GalleryDelete", new { GalleryItemId = model.Id }),
        EntityEditorKind.User =>
            _db.ExecuteAsync("central", "UserDelete", new { UserId = model.Id }),
        EntityEditorKind.Account =>
            _db.ExecuteAsync("accounting", "ChartOfAccountDelete", new { AccountId = model.Id }),
        EntityEditorKind.GoldItem =>
            _db.ExecuteAsync("goldshop", "GoldItemDelete", new { GoldItemId = model.Id, CompanyId = _db.CurrentCompanyId }),
        EntityEditorKind.GoldPrice =>
            _db.ExecuteAsync("goldshop", "GoldPriceDelete", new { PriceId = model.Id, CompanyId = _db.CurrentCompanyId }),
        EntityEditorKind.InventoryItem =>
            _db.ExecuteAsync("inventory", "ItemDelete", new { ItemId = model.Id }),
        EntityEditorKind.Warehouse =>
            _db.ExecuteAsync("inventory", "WarehouseDelete", new { WarehouseId = model.Id }),
        EntityEditorKind.Employee =>
            _db.ExecuteAsync("payroll", "EmployeeDelete", new { EmployeeId = model.Id }),
        EntityEditorKind.Product =>
            _db.ExecuteAsync("store", "ProductDelete", new { ProductId = model.Id }),
        EntityEditorKind.Customer =>
            _db.ExecuteAsync("store", "CustomerDelete", new { CustomerId = model.Id }),
        EntityEditorKind.CurrencyRate =>
            _db.ExecuteAsync("treasury", "CurrencyRateDelete", new { RateId = model.Id }),
        _ => throw new ArgumentOutOfRangeException(nameof(model.Kind), model.Kind, "نوع رکورد برای حذف پشتیبانی نمی‌شود.")
    };
}
