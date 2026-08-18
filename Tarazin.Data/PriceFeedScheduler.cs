using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Logging;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// زمان‌بند بروزرسانی خودکار نرخ‌ها (PRD §56).
/// به‌صورت singleton ثبت می‌شود و فقط Web پس از راه‌اندازی دیتابیس آن را
/// در <c>Program.cs</c> استارت می‌کند؛ MAUI اجازهٔ initialization ندارد.
///
/// فاصلهٔ پیش‌فرض از تنظیم <c>currency.Settings/DefaultUpdateIntervalSeconds</c>
/// خوانده می‌شود (مدیر می‌تواند آن را از صفحهٔ «عملیات ویژه» تغییر دهد)؛
/// منبعِ هر‌Source هم FetchIntervalSeconds مخصوص خودش را دارد که هنگام
/// استارت‌آپ لحاظ می‌شود.
///
/// برای هر تیک یک scope تازه ساخته می‌شود (DbService/PriceFeedService scoped
/// هستند) — این الگو در Blazor Server و MAUI هر دو کار می‌کند.
/// </summary>
public sealed class PriceFeedScheduler : IDisposable
{
    private static int _started;                    // Interlocked guard per host process
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<PriceFeedScheduler> _logger;
    private Timer? _timer;
    private volatile bool _busy;

    public PriceFeedScheduler(IServiceScopeFactory scopeFactory, ILogger<PriceFeedScheduler> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    /// <summary>شروع زمان‌بند — فقط یک بار در فرایند (guard شده).</summary>
    public void Start()
    {
        if (Interlocked.Exchange(ref _started, 1) == 1)
            return;

        _logger.LogInformation("زمان‌بند بروزرسانی خودکار نرخ‌ها استارت شد");
        _timer = new Timer(Tick, null, TimeSpan.FromSeconds(10), TimeSpan.FromMinutes(5));
    }

    private async void Tick(object? state)
    {
        if (_busy)
            return;

        _busy = true;
        try
        {
            using var scope = _scopeFactory.CreateScope();
            var feed = scope.ServiceProvider.GetRequiredService<PriceFeedService>();
            var db = scope.ServiceProvider.GetRequiredService<DbService>();

            var result = await feed.FetchAllAsync();

            if (result.Results.Count > 0)
                _logger.LogInformation("چرخهٔ نرخ: {Ok}/{Total} منبع موفق", result.SuccessCount, result.TotalCount);

            // فاصلهٔ بعدی از تنظیم خوانده می‌شود (تغییرات مدیر بلافاصله اثر دارد).
            var interval = 300;
            try
            {
                var settings = (await db.QueryAsync<CurrencySettingRow>(
                    "currency", "SettingsList")).ToList();
                var raw = settings.FirstOrDefault(s => s.SettingKey == "DefaultUpdateIntervalSeconds")?.SettingValue;
                if (int.TryParse(raw, out var parsed) && parsed >= 10)
                    interval = parsed;
            }
            catch (Exception ex)
            {
                _logger.LogDebug("خواندن فاصلهٔ بروزرسانی ممکن نشد ({ErrorType})؛ پیش‌فرض ۳۰۰ ثانیه",
                    ex.GetType().Name);
            }

            if (interval >= 10)
                _timer?.Change(TimeSpan.FromSeconds(interval), TimeSpan.FromSeconds(interval));
        }
        catch (Exception ex)
        {
            _logger.LogError("خطا در چرخهٔ بروزرسانی خودکار نرخ‌ها ({ErrorType})", ex.GetType().Name);
        }
        finally
        {
            _busy = false;
        }
    }

    public void Dispose()
    {
        _timer?.Dispose();
        _timer = null;
    }
}
