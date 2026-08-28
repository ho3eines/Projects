using System.Text.Json;
using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// دیسپچر پس‌زمینهٔ رویدادهای <c>payroll.Outbox</c> (ADR-002 dual-write).
///
/// <c>PayrollFinalize.sql</c> رویداد <c>PayrollFinalized</c> را در
/// <c>payroll.Outbox</c> می‌نویسد و مصرف‌کننده‌های cross-schema
/// (<c>accounting.GLPostFromPayroll</c> + <c>treasury.CashMoveFromPayroll</c>)
/// باید اجرا شوند تا افزون‌سازی (dual-write) به حسابداری و خزانه انجام شود.
/// این سرویس آن صف را تخلیه می‌کند با Retry و ثبت LastError.
///
/// چرخه:
///   1. Claim اتمیک تا N ردیف آماده (OutboxClaim؛ با Lease منقضی‌شونده تا اگر
///      worker وسط کار از بین رفت، ردیف دوباره برداشته شود — قرابت *at-least-once*).
///   2. برای هر ردیف PayrollFinalized، payload را پارس و مصرف‌کننده‌ها را
///      به‌ترتیب accounting سپس treasury اجرا می‌کند.
///   3. موفقیت کامل → OutboxMarkSuccess؛ هر شکست → OutboxMarkFailure (با
///      LastError و پاک‌کردن ClaimedAt برای تلاش مجدد).
///
/// مثل <c>PriceFeedScheduler</c> به‌صورت singleton ثبت می‌شود؛ فقط Web در
/// <c>Program.cs</c> بعد از راه‌اندازی دیتابیس آن را استارت می‌کند. برای هر
/// چرخه یک scope تازه ساخته می‌شود چون DbService scoped است.
/// </summary>
public sealed class PayrollOutboxDispatcher : IDisposable
{
    /// <summary>نام رویدادی که این دیسپچر پردازش می‌کند (پایهٔ <c>PayrollFinalize.sql</c>).</summary>
    public const string EventTypePayrollFinalized = "PayrollFinalized";

    private static int _started;                    // Interlocked guard per host process
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PayrollOutboxDispatcher> _logger;
    private Timer? _timer;
    private volatile bool _busy;

    public PayrollOutboxDispatcher(IServiceScopeFactory scopeFactory, ILogger<PayrollOutboxDispatcher> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>شروع دیسپچر — فقط یک بار در فرایند (guard شده).</summary>
    public void Start()
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
            return;

        _logger.LogInformation("دیسپچر رویدادهای حقوق و دستمزد استارت شد");
        _timer = new Timer(Tick, null, TimeSpan.FromSeconds(15), TimeSpan.FromSeconds(30));
    }

    private async void Tick(object? state)
    {
        if (_busy)
            return;

        _busy = true;
        try
        {
            await ProcessPendingAsync(CancellationToken.None);
        }
        catch (Exception ex)
        {
            _logger.LogError("خطا در تخلیهٔ Outbox حقوق ودستمزد ({ErrorType})", ex.GetType().Name);
        }
        finally
        {
            _busy = false;
        }
    }

    /// <summary>تخلیهٔ یک دوره از صف؛ برای هر ردیف مصرف‌کننده‌ها اجرا و نتیجه ثبت می‌شود.</summary>
    public async Task<int> ProcessPendingAsync(CancellationToken ct = default)
    {
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<DbService>();

        // Claim اتمیک ردیف‌های آماده (حداکثر ۵۰ در هر چرخه).
        var claimed = await db.QueryAsync<PayrollOutboxRow>(
            "payroll", "OutboxClaim", new { MaxRows = 50, LeaseSeconds = 60 }, ct);

        var processed = 0;
        foreach (var row in claimed)
        {
            ct.ThrowIfCancellationRequested();

            try
            {
                await DispatchAsync(db, row, ct);
                await db.ExecuteAsync("payroll", "OutboxMarkSuccess", new { OutboxId = row.OutboxId }, ct);
                processed++;
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                throw;
            }
            catch (Exception ex)
            {
                // LastError فقط پیام امنِ لایهٔ داده را نگه می‌دارد (نه متن خام SQL).
                await db.ExecuteAsync("payroll", "OutboxMarkFailure",
                    new { OutboxId = row.OutboxId, LastError = DbService.Describe(ex) }, ct);
                _logger.LogWarning("ردیف Outbox {OutboxId} ({EventKey}) ناموفق ماند ({ErrorType})",
                    row.OutboxId, row.EventKey, ex.GetType().Name);
            }
        }

        if (processed > 0)
            _logger.LogInformation("{Processed} رویداد حقوق ودستمزد با موفقیت اعمال شد", processed);

        return processed;
    }

    /// <summary>
    /// اجرای مصرف‌کننده‌های یک رویداد. رویداد PayrollFinalized باعث انجام
    /// افزون‌سازی به حسابداری و سپس خزانه می‌شود (ترتیب مهم: اول GL، بعد صندوق).
    /// </summary>
    private static async Task DispatchAsync(DbService db, PayrollOutboxRow row, CancellationToken ct)
    {
        // فقط رویدادهای PayrollFinalized الان پشتیبانی می‌شوند؛ سایر EventTypeها
        // به‌عنوان ناشناخته در نظر گرفته و به‌طور امن (skip) رد می‌شوند.
        if (!CanHandle(row.EventType))
        {
            // MarkedSuccess قرار می‌گیرد تا صف برای همیشه گیر نکند؛ رویدادهای
            // ناشناخته آینده نسخه‌دار می‌شوند (PayloadVersion) و جدا مدیریت می‌شوند.
            return;
        }

        if (!TryParseEvent(row, out var e))
            throw new InvalidOperationException("Payload رویداد PayrollFinalized نامعتبر است.");

        var parameters = new
        {
            RunId = e.RunId,
            Period = e.Period,
            EmployeeCount = e.EmployeeCount,
            NetTotal = e.NetTotal,
            CompanyId = e.CompanyId
        };

        // اول سند حسابداری (PayrollPostings)، سپس حرکت صندوق (CashMovements).
        await db.ExecuteAsync("accounting", "GLPostFromPayroll", parameters, ct);
        await db.ExecuteAsync("treasury", "CashMoveFromPayroll", parameters, ct);
    }

    /// <summary>آیا دیسپچر این EventType را پشتیبانی می‌کند؟</summary>
    public static bool CanHandle(string eventType) =>
        string.Equals(eventType, EventTypePayrollFinalized, StringComparison.OrdinalIgnoreCase);

    /// <summary>
    /// پارس payload رویداد PayrollFinalized؛ برای تست‌پذیریِ خالص (بدون وابستگی)
    /// به‌صورت static نگه‌داشته شده است.
    /// </summary>
    public static bool TryParseEvent(PayrollOutboxRow row, out PayrollFinalizedEvent parsed)
    {
        if (row is null || string.IsNullOrWhiteSpace(row.Payload))
        {
            parsed = default!;
            return false;
        }

        try
        {
            var e = JsonSerializer.Deserialize<PayrollFinalizedEvent>(row.Payload);
            if (e is null || e.RunId <= 0 || string.IsNullOrEmpty(e.Period))
            {
                parsed = default!;
                return false;
            }
            parsed = e;
            return true;
        }
        catch (JsonException)
        {
            parsed = default!;
            return false;
        }
    }

    public void Dispose()
    {
        _timer?.Dispose();
        _timer = null;
    }
}