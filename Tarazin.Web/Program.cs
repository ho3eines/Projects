using System.Globalization;
using MudBlazor;
using MudBlazor.Services;
using Tarazin.Data;
using Tarazin.Services;

var fa = CultureInfo.GetCultureInfo("fa-IR");
CultureInfo.DefaultThreadCurrentCulture = fa;
CultureInfo.DefaultThreadCurrentUICulture = fa;

var builder = WebApplication.CreateBuilder(args);

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

var app = builder.Build();

// ── Startup: ensure database/schemas, seed idempotently, bootstrap admin ──
// اگر SQL در دسترس نباشد، برنامه به‌جای crash با پیام گنگ، بالا می‌آید و
// صفحهٔ /diag علت دقیق را نشان می‌دهد (مگر اینکه TARAZIN_FAIL_FAST=1 باشد).
using (var scope = app.Services.CreateScope())
{
    var logger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Tarazin.Startup");
    var (raw, source) = TarazinConnection.ResolveRaw(app.Configuration);

    logger.LogInformation("رشتهٔ اتصال — منبع: {Source} | مقدار: {Value}",
        source, TarazinConnection.Mask(raw));

    try
    {
        await TarazinDbInitializer.EnsureInitializedAsync(scope.ServiceProvider);
        logger.LogInformation("راه‌اندازی دیتابیس با موفقیت انجام شد.");
    }
    catch (Exception ex)
    {
        logger.LogError(ex, "راه‌اندازی دیتابیس ناموفق بود. برای جزئیات به /diag بروید.");

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
