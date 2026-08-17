using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Services;

/// <summary>
/// اطمینان از وجود محیط کاری معتبر (شرکت + سال مالی) برای کاربر واردشده.
///
/// این سرویس تنها نقطهٔ ورود UI برای منطق زیر است:
///   * اگر کاربر هیچ شرکت قابل‌دسترسی ندارد → باید UI یک Modal اجباری
///     «ایجاد شرکت مالی» نمایش دهد (CreateCompanyAsync).
///   * پس از انتخاب/ایجاد شرکت، بررسی می‌کند که آیا برای سال شمسی جاری
///     سال مالی وجود دارد یا نه. اگر نبود، به‌صورت سیستمی ایجاد می‌کند
///     (FiscalYearEnsure) و سند افتتاحیه را می‌سازد (DocumentOpeningEnsure).
///
/// ⚠ این سرویس هیچ «مسیر ایجاد دستی سال مالی» به UI نمی‌دهد؛ ایجاد سال
///    فقط توسط همین سرویس و در لحظهٔ نیاز انجام می‌شود.
/// </summary>
public sealed class AccountingContextService
{
    private readonly DbService _db;
    private readonly UserSession _session;

    public AccountingContextService(DbService db, UserSession session)
    {
        _db = db;
        _session = session;
    }

    /// <summary>شرکت‌های قابل‌دسترسی کاربر.</summary>
    public Task<IReadOnlyList<CompanyRow>> GetAuthorizedCompaniesAsync(CancellationToken ct = default)
        => _db.QueryAsync<CompanyRow>("central", "UserAuthorizedCompanies",
            new { UserId = _session.UserId }, ct);

    /// <summary>سال‌های مالی قابل‌دسترسی کاربر برای یک شرکت.</summary>
    public Task<IReadOnlyList<FiscalYearRow>> GetAuthorizedFiscalYearsAsync(int companyId, CancellationToken ct = default)
        => _db.QueryAsync<FiscalYearRow>("central", "UserAuthorizedFiscalYears",
            new { UserId = _session.UserId, CompanyId = companyId }, ct);

    /// <summary>
    /// تضمین وجود سال مالی جاری برای شرکت داده‌شده.
    /// در صورت نبود، سال مالی و سند افتتاحیه را به‌صورت اتمیک می‌سازد.
    /// همیشه ردیف سال مالی را برمی‌گرداند.
    /// </summary>
    public async Task<FiscalYearRow> EnsureCurrentFiscalYearAsync(int companyId, CancellationToken ct = default)
    {
        var year = PersianDate.CurrentYear;
        var start = PersianDate.StartOfYear(year);
        var end = PersianDate.EndOfYear(year);
        var yearName = PersianDate.YearName(year);

        var fy = await _db.QueryFirstOrDefaultAsync<FiscalYearRow>(
            "central", "FiscalYearEnsure",
            new
            {
                CompanyId = companyId,
                YearName = yearName,
                StartDate = start,
                EndDate = end,
                UserId = _session.UserId,
                CreatedBy = _session.UserName
            }, ct);

        if (fy is null)
            throw new InvalidOperationException("ایجاد یا بازیابی سال مالی با خطا مواجه شد.");

        // سند افتتاحیه را هم تضمین کن (در یک اسکریپت جدا ولی با همان
        // الگوی اتمیک/Idempotent).
        await _db.ExecuteAsync("accounting", "DocumentOpeningEnsure",
            new
            {
                CompanyId = companyId,
                FiscalYearId = fy.FiscalYearId,
                CreatedBy = _session.UserName
            }, ct);

        return fy;
    }

    /// <summary>
    /// ایجاد یک شرکت مالی جدید برای کاربر.
    /// پس از ایجاد:
    ///   * شرکت به کاربر اختصاص داده می‌شود.
    ///   * سال مالی جاری برای شرکت به‌صورت خودکار ایجاد می‌شود.
    ///   * سند افتتاحیه ساخته می‌شود.
    ///   * محیط فعال کاربر روی همین شرکت/سال تنظیم می‌شود.
    /// </summary>
    public async Task<(CompanyRow Company, FiscalYearRow FiscalYear)> CreateCompanyAsync(
        string companyName, CancellationToken ct = default)
    {
        if (string.IsNullOrWhiteSpace(companyName))
            throw new ArgumentException("نام شرکت الزامی است.", nameof(companyName));

        var result = await _db.ExecuteReturningAsync<NewIdRow>(
            "central", "CompanyUpsert",
            new
            {
                CompanyId = 0,
                CompanyName = companyName.Trim(),
                IsActive = true,
                CreatedBy = _session.UserName
            }, ct);

        if (result is null || result.NewId <= 0)
            throw new InvalidOperationException("ایجاد شرکت مالی با خطا مواجه شد.");

        // اختصاص شرکت به کاربر.
        await _db.ExecuteAsync("central", "CompanyAssignToUser",
            new { UserId = _session.UserId, CompanyId = result.NewId, CreatedBy = _session.UserName }, ct);

        var companies = await GetAuthorizedCompaniesAsync(ct);
        var company = companies.FirstOrDefault(c => c.CompanyId == result.NewId)
                      ?? throw new InvalidOperationException("شرکت ایجادشده در فهرست دسترسی‌های کاربر یافت نشد.");

        // ایجاد خودکار سال مالی جاری و سند افتتاحیه.
        var fy = await EnsureCurrentFiscalYearAsync(company.CompanyId, ct);

        // فعال‌سازی محیط.
        await SetActiveContextAsync(company, fy, ct);

        return (company, fy);
    }

    /// <summary>
    /// فعال‌سازی یک (شرکت + سال مالی) به‌عنوان محیط فعال کاربر.
    /// پیش از فعال‌سازی، تضمین می‌کند سال مالی جاری شرکت وجود دارد.
    /// </summary>
    public async Task SetActiveContextAsync(CompanyRow company, FiscalYearRow year, CancellationToken ct = default)
    {
        // اگر کاربر سالی غیر از سال جاری انتخاب کرد، کاری نکن (همان استفاده می‌شود).
        // ولی اگر سال جاری را شرکت ندارد، Ensure آن را می‌سازد.
        var currentYearName = PersianDate.YearName(PersianDate.CurrentYear);
        if (string.Equals(year.YearName, currentYearName, StringComparison.Ordinal))
        {
            year = await EnsureCurrentFiscalYearAsync(company.CompanyId, ct);
        }

        await _db.ExecuteAsync("central", "UserActiveContextSet",
            new
            {
                UserId = _session.UserId,
                ActiveCompanyId = company.CompanyId,
                ActiveFiscalYearId = year.FiscalYearId
            }, ct);

        await _session.UpdateActiveContextAsync(company.CompanyId, company.CompanyName,
            year.FiscalYearId, year.YearName);
    }

    /// <summary>
    /// اطمینان از محیط فعال کاربر پس از ورود/بازیابی نشست.
    /// خروجی نشان می‌دهد آیا محیط آماده است یا کاربر باید شرکت بسازد.
    /// </summary>
    public async Task<ContextState> ResolveAsync(CancellationToken ct = default)
    {
        var companies = (await GetAuthorizedCompaniesAsync(ct)).ToList();
        if (companies.Count == 0)
            return ContextState.MissingCompany();

        // اگر محیط فعال معتبر است همان را نگه دار.
        if (_session.ActiveCompanyId is int cid && _session.ActiveFiscalYearId is int fid)
        {
            var comp = companies.FirstOrDefault(c => c.CompanyId == cid);
            if (comp is not null)
            {
                var years = await GetAuthorizedFiscalYearsAsync(cid, ct);
                var yr = years.FirstOrDefault(y => y.FiscalYearId == fid);
                if (yr is not null)
                    return ContextState.Ready(comp, yr, companies);
            }
        }

        // در غیر این صورت اولین شرکت را انتخاب و سال جاری را تضمین کن.
        var selected = companies[0];
        var fy = await EnsureCurrentFiscalYearAsync(selected.CompanyId, ct);
        await SetActiveContextAsync(selected, fy, ct);
        return ContextState.Ready(selected, fy, companies);
    }

    /// <summary>بستن سال مالی فعال (ایجاد/به‌روزرسانی سند اختتامیه + بستن سال).</summary>
    public async Task<long> CloseFiscalYearAsync(int companyId, int fiscalYearId, CancellationToken ct = default)
    {
        await _db.ExecuteAsync("accounting", "DocumentClosingGenerate",
            new
            {
                CompanyId = companyId,
                FiscalYearId = fiscalYearId,
                CreatedBy = _session.UserName
            }, ct);

        return 1;
    }

    /// <summary>نتیجهٔ ارزیابی محیط.</summary>
    public sealed record ContextState(
        bool IsReady,
        bool RequiresCompany,
        CompanyRow? Company,
        FiscalYearRow? FiscalYear,
        IReadOnlyList<CompanyRow> Companies)
    {
        public static ContextState MissingCompany() => new(false, true, null, null, Array.Empty<CompanyRow>());
        public static ContextState Ready(CompanyRow c, FiscalYearRow fy, IReadOnlyList<CompanyRow> all) =>
            new(true, false, c, fy, all);
    }

    /// <summary>ردیف خروجی اسکریپت‌های Upsert (NewId).</summary>
    public sealed class NewIdRow
    {
        public int NewId { get; set; }
    }
}
