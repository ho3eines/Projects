using System.Globalization;
using System.Text;
using MudBlazor;
using MudBlazor.Services;
using Tarazin.Data;
using Tarazin.Services;
using Tarazin.Web;

// جلوگیری از نمایش «؟» به‌جای حروف فارسی در کنسول ویندوز/dotnet watch.
Console.InputEncoding = Encoding.UTF8;
Console.OutputEncoding = Encoding.UTF8;

var fa = CultureInfo.GetCultureInfo("fa-IR");
CultureInfo.DefaultThreadCurrentCulture = fa;
CultureInfo.DefaultThreadCurrentUICulture = fa;

var builder = WebApplication.CreateBuilder(args);

// === Stimulsoft License ===
string licensePath = Path.Combine(
    AppContext.BaseDirectory,
    "wwwroot",
    "License",
    "Stimul20240302.key");

if (File.Exists(licensePath))
{
    Stimulsoft.Base.StiLicense.LoadFromFile(licensePath);
}
else
{
    // برای دیباگ
    System.Diagnostics.Debug.WriteLine($"License file not found: {licensePath}");
}

// ── Blazor Server (web host) — the UI itself lives in Tarazin.Ui ─────────
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// ── MudBlazor UI kit (providers are rendered by the shared App.razor) ─────
builder.Services.AddMudServices(config =>
{
    config.SnackbarConfiguration.PositionClass = Defaults.Classes.Position.BottomStart;
    config.SnackbarConfiguration.NewestOnTop = true;
    config.SnackbarConfiguration.ShowCloseIcon = true;
    config.SnackbarConfiguration.VisibleStateDuration = 3500;
    config.SnackbarConfiguration.PreventDuplicates = false;
});

// ── Tarazin services: UI layer (session/auth) + Data layer (DbService, ...) ─
builder.Services.AddTarazinUiServices();

// نشست ورود را در protected session storage مرورگر نگه می‌داریم تا با
// رفرش صفحه (که circuit و UserSession حافظه‌ای را از بین می‌برد) کاربر
// از سیستم خارج نشود. فقط مخصوص هاست وب است؛ MAUI به آن نیازی ندارد.
builder.Services.AddScoped<ISessionStore, ProtectedSessionStore>();



var app = builder.Build();

// ── Startup: ensure database/schemas, seed idempotently, bootstrap admin ──
// اگر SQL در دسترس نباشد، برنامه به‌جای crash با پیام گنگ، بالا می‌آید و
// صفحهٔ /diag علت دقیق را نشان می‌دهد (مگر اینکه TARAZIN_FAIL_FAST=1 باشد).
using (var scope = app.Services.CreateScope())
{
    var logger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Tarazin.Startup");
    var (raw, source) = TarazinConnection.ResolveRaw(app.Configuration);

    logger.LogInformation("ConnectionString: {Source} | Value: {Value}",
        source, TarazinConnection.Mask(raw));

    try
    {
        await TarazinDbInitializer.EnsureInitializedAsync(scope.ServiceProvider);

        // فقط «اتصال موفق» کافی نیست؛ مقصد واقعی SQL Server، نام دیتابیس،
        // فایل MDF/LDF و شمارنده‌های اصلی را لاگ می‌کنیم تا اتصال به instance
        // اشتباه (مثلاً . در برابر localhost,1433) فوراً مشخص شود.
        try
        {
            var db = scope.ServiceProvider.GetRequiredService<DbService>();
            var storage = await db.QueryFirstOrDefaultAsync<DatabaseStorageInfo>(
                "central", "DatabaseStorageInfo");

            logger.LogInformation(
                "Database ready | Server={Server} | Database={Database} | Files={Files} | " +
                "BaseDetil={BaseDetil} | BaseDetilLink={BaseDetilLink} | PriceRates={PriceRates} | RateHistory={RateHistory}",
                storage?.ServerName, storage?.DatabaseName, storage?.DataFiles,
                storage?.BaseDetilCount, storage?.BaseDetilLinkCount,
                storage?.PriceRateCount, storage?.RateHistoryCount);
        }
        catch (Exception proofEx)
        {
            // خطای نمایش اطلاعات تشخیصی نباید راه‌اندازی موفق دیتابیس را خراب کند.
            logger.LogWarning(proofEx, "Database initialized, but persistence details could not be read");
        }
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "DataBase Error");

        if (Environment.GetEnvironmentVariable("TARAZIN_FAIL_FAST") == "1")
            throw;
    }
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

// مدل Blazor Server کلاسیک (net8): blazor.server.js و دارایی‌های استاتیک
// MudBlazor/Tarazin.Ui از طریق static web assets و UseStaticFiles سرو می‌شوند.
// (MapStaticAssets که در net9+ اضافه شد، در net8 وجود ندارد و لازم هم نیست.)
app.MapBlazorHub();
app.MapFallbackToPage("/_Host");



app.Run();
