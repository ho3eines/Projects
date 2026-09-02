using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// محیط کاری انبار: انتخاب «انبار فعال» نشست (مثل سال مالی در حسابداری).
///
/// عملیات انبار (فاکتور خرید/فروش، گزارش‌ها، انبارگردانی) روی انبار فعال انجام
/// می‌شود و انبار همیشه به شرکت فعال وابسته است — انبار یک شرکت در هیچ صفحه/گزارشی
/// برای شرکت دیگر دیده نمی‌شود (همهٔ کوئری‌ها با CompanyId اسکوپ می‌شوند).
/// </summary>
public sealed class InventoryContextService
{
    private readonly DbService _db;
    private readonly UserSession _session;

    public InventoryContextService(DbService db, UserSession session)
    {
        _db = db;
        _session = session;
    }

    /// <summary>انبارهای فعالِ شرکت جاری (برای انتخاب‌کنندهٔ انبار).</summary>
    public async Task<IReadOnlyList<WarehouseRow>> GetWarehousesAsync(CancellationToken ct = default)
    {
        if (_session.ActiveCompanyId is not int companyId)
            return Array.Empty<WarehouseRow>();
        return await _db.QueryAsync<WarehouseRow>("inventory", "WarehouseList",
            new { CompanyId = companyId }, ct);
    }

    /// <summary>انبار فعال نشست را تنظیم می‌کند (پایدار در session store).</summary>
    public async Task SetActiveWarehouseAsync(WarehouseRow warehouse)
    {
        await _session.UpdateActiveWarehouseAsync(warehouse.WarehouseId, warehouse.Title);
    }

    /// <summary>پاک‌کردن انبار فعال (وقتی شرکت عوض شد یا انبار حذف شد).</summary>
    public Task ClearActiveWarehouseAsync() => _session.UpdateActiveWarehouseAsync(null, null);

    /// <summary>
    /// اگر انبار فعالی انتخاب نشده (یا متعلق به شرکت قبلی باشد)، آن را به انبار
    /// پیش‌فرض تنظیمات یا اولین انبار شرکت بازنشانی می‌کند. null برمی‌گرداند اگر
    /// شرکتی فعال نیست یا هیچ انباری برای شرکت وجود ندارد.
    /// </summary>
    public async Task<WarehouseRow?> EnsureActiveWarehouseAsync(CancellationToken ct = default)
    {
        if (_session.ActiveCompanyId is not int companyId)
            return null;

        var warehouses = (await GetWarehousesAsync(ct)).ToList();
        if (warehouses.Count == 0)
        {
            await ClearActiveWarehouseAsync();
            return null;
        }

        // اگر انبار فعال هنوز برای همین شرکت معتبر است، همان را نگه دار.
        if (_session.ActiveWarehouseId is int whId &&
            warehouses.Any(w => w.WarehouseId == whId))
            return warehouses.First(w => w.WarehouseId == whId);

        // بازنشانی: انبار پیش‌فرض تنظیمات، وگرنه اولین انبار.
        WarehouseRow? pick = null;
        var settings = await _db.QueryFirstOrDefaultAsync<InventorySettingsRow>(
            "inventory", "InventorySettingsGet", new { CompanyId = companyId }, ct);
        if (settings?.DefaultWarehouseId is int dw)
            pick = warehouses.FirstOrDefault(w => w.WarehouseId == dw);

        pick ??= warehouses.First();
        await _session.UpdateActiveWarehouseAsync(pick.WarehouseId, pick.Title);
        return pick;
    }
}
