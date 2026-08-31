using System.Globalization;
using System.Net;
using System.Text;
using System.Threading.RateLimiting;
using Microsoft.AspNetCore.HttpOverrides;
using Microsoft.AspNetCore.Mvc;
using MudBlazor;
using MudBlazor.Services;
using Tarazin.Data;
using Tarazin.Models;
using Tarazin.Services;
using Tarazin.Web;

// جلوگیری از نمایش «؟» به‌جای حروف فارسی در کنسول ویندوز/dotnet watch.
Console.InputEncoding = Encoding.UTF8;
Console.OutputEncoding = Encoding.UTF8;

// ── تک‌نمونه‌سازی (single-instance) ────────────────────────────────────────
// از اجرای هم‌زمان دو نمونهٔ هاست وب جلوگیری می‌کند؛ در غیر این صورت هر دو روی
// پورت‌های 65220/65221 رقابت می‌کنند، DLLهای در حال استفاده قفل می‌شوند و
// دسترسی HTTP/HTTPS ناپایدار می‌شود. مودِکس همنامِ فرایند محلی: دومین نمونه
// به‌جای خاموشی گیج‌کننده، پیام واضح چاپ و بلافاصله خروجی می‌کند.
using var singleInstanceLock = AcquireSingleInstanceLock();
if (singleInstanceLock is null)
{
    Console.ForegroundColor = ConsoleColor.Yellow;
    Console.WriteLine("یک نمونهٔ دیگر از Tarazin.Web در حال اجراست. برای راه‌اندازی مجدد ابتدا آن را متوقف کنید.");
    Console.ResetColor();
    return;
}

var fa = CultureInfo.GetCultureInfo("fa-IR");
CultureInfo.DefaultThreadCurrentCulture = fa;
CultureInfo.DefaultThreadCurrentUICulture = fa;

var builder = WebApplication.CreateBuilder(args);

// Forwarded protocol/client addresses are accepted only from explicitly listed
// immediate reverse proxies. Never clear the trust lists or accept forwarded
// headers from arbitrary clients: broker HTTPS checks and IP rate limits depend
// on these values being authentic.
var reverseProxyEnabled = builder.Configuration.GetValue<bool>("ReverseProxy:Enabled");
if (reverseProxyEnabled)
{
    var configuredProxies = builder.Configuration
        .GetSection("ReverseProxy:KnownProxies")
        .Get<string[]>() ?? Array.Empty<string>();
    if (configuredProxies.Length == 0)
        throw new InvalidOperationException("ReverseProxy:KnownProxies must list at least one trusted proxy IP when proxy handling is enabled.");

    var knownProxies = configuredProxies.Select(value =>
    {
        if (!IPAddress.TryParse(value, out var address))
            throw new InvalidOperationException("ReverseProxy:KnownProxies contains an invalid IP address.");
        return address;
    }).ToArray();

    builder.Services.Configure<ForwardedHeadersOptions>(options =>
    {
        options.ForwardedHeaders = ForwardedHeaders.XForwardedFor | ForwardedHeaders.XForwardedProto;
        options.ForwardLimit = 1;
        options.RequireHeaderSymmetry = true;
        options.KnownNetworks.Clear();
        options.KnownProxies.Clear();
        foreach (var proxy in knownProxies)
            options.KnownProxies.Add(proxy);
    });
}

// ── Blazor Server (web host) — the UI itself lives in Tarazin.Ui ─────────
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// مشخص‌کردن صریحِ پورت HTTPS (از پیکربندی) تا redirect پایدار باشد حتی اگر
// هاست هم‌زمان هر دو بایند شود یا launchSettings/ASPNETCORE_URLS ناهماهنگ باشند.
if (builder.Configuration.GetValue<int?>("Tarazin:HttpsPort") is int httpsPort)
    builder.Services.AddHttpsRedirection(options =>
    {
        options.RedirectStatusCode = StatusCodes.Status308PermanentRedirect;
        options.HttpsPort = httpsPort;
    });
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("mobile-connection", httpContext =>
        RateLimitPartition.GetFixedWindowLimiter(
            httpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown",
            _ => new FixedWindowRateLimiterOptions
            {
                PermitLimit = 5,
                Window = TimeSpan.FromMinutes(1),
                QueueLimit = 0,
                AutoReplenishment = true
            }));
});

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
builder.Services.AddScoped<MobileConnectionService>();

// نشست ورود را در protected session storage مرورگر نگه می‌داریم تا با
// رفرش صفحه (که circuit و UserSession حافظه‌ای را از بین می‌برد) کاربر
// از سیستم خارج نشود. فقط مخصوص هاست وب است؛ MAUI به آن نیازی ندارد.
builder.Services.AddScoped<ISessionStore, ProtectedSessionStore>();

// ذخیرهٔ PDF ساخته‌شده توسط PdfReportService — دانلود بلاب در مرورگر.
builder.Services.AddScoped<IPdfSaver, WebPdfSaver>();



var app = builder.Build();

// ── Startup: ensure database/schemas, seed idempotently, bootstrap admin ──
// اگر SQL در دسترس نباشد، برنامه به‌جای crash با پیام گنگ، بالا می‌آید و
// صفحهٔ /diag علت دقیق را نشان می‌دهد (مگر اینکه TARAZIN_FAIL_FAST=1 باشد).
using (var scope = app.Services.CreateScope())
{
    var logger = app.Services.GetRequiredService<ILoggerFactory>().CreateLogger("Tarazin.Startup");
    logger.LogInformation("SQL provider uses server-side deployment configuration; values redacted");

    try
    {
        await TarazinDbInitializer.EnsureInitializedAsync(scope.ServiceProvider);
        scope.ServiceProvider.GetRequiredService<PriceFeedScheduler>().Start();
        scope.ServiceProvider.GetRequiredService<PayrollOutboxDispatcher>().Start();

        // Do not emit SQL destinations, physical file paths, or provider details.
        logger.LogInformation("Database initialization completed");
    }
    catch (Exception ex)
    {
        logger.LogError("Database initialization failed ({ErrorType}): {SafeMessage}",
            ex.GetType().Name, DbService.Describe(ex));

        // Debug aid: full exception chain, gated behind an explicit env var.
        if (Environment.GetEnvironmentVariable("TARAZIN_DEBUG_INIT") == "1")
        {
            for (var e = ex; e is not null; e = e.InnerException)
                logger.LogError("  init>> {ErrorType}: {Message}", e.GetType().Name, e.Message);
        }

        if (Environment.GetEnvironmentVariable("TARAZIN_FAIL_FAST") == "1")
            throw;
    }
}

// This must run before HTTPS enforcement, redirects, rate limiting, and routing.
// With proxy handling disabled, client-supplied X-Forwarded-* values are ignored.
if (reverseProxyEnabled)
    app.UseForwardedHeaders();

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}


// HTTP → HTTPS: پیکربندیِ redirect (پورت/کد) قبلاً از طریق AddHttpsRedirection
// بالای همین فایل اعمال شده؛ اینجا فقط میان‌افزار را نصب می‌کنیم.
app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();

// MAUI connection bootstrap (2026-08-20): POST /api/mobile/connection verifies
// the user's credentials against [central].[Users] — the same check as the web
// login — and returns the server's SQL connection string encrypted with a key
// derived from the login password. This endpoint does NOT perform the login
// itself: after this one call, both hosts run the identical in-process login
// (AuthService → PBKDF2 → DbService). Responses are never cacheable and
// production requests must use HTTPS with normal certificate validation.
app.MapPost("/api/mobile/connection", async (ConnectionBootstrapRequest request, HttpContext http,
    MobileConnectionService service, CancellationToken ct) =>
{
    SetSensitiveResponseHeaders(http.Response);
    try
    {
        if (!http.Request.IsHttps && !app.Environment.IsDevelopment())
            return MobileError(StatusCodes.Status426UpgradeRequired, "https_required", "اتصال امن HTTPS لازم است.");

        var result = await service.BootstrapAsync(request, ct);
        return result.Response is not null
            ? Results.Json(result.Response, statusCode: result.StatusCode)
            : Results.Json(result.Error, statusCode: result.StatusCode);
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        throw;
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Mobile connection bootstrap failed ({ErrorType})", ex.GetType().Name);
        return MobileError(StatusCodes.Status503ServiceUnavailable, "service_unavailable", "سرویس اتصال موقتاً در دسترس نیست.");
    }
    finally
    {
        request.Password = "";
    }
})
.DisableAntiforgery()
.RequireRateLimiting("mobile-connection")
.WithMetadata(new RequestSizeLimitAttribute(8_192));

// مدل Blazor Server کلاسیک (net8): blazor.server.js و دارایی‌های استاتیک
// MudBlazor/Tarazin.Ui از طریق static web assets و UseStaticFiles سرو می‌شوند.
// (MapStaticAssets که در net9+ اضافه شد، در net8 وجود ندارد و لازم هم نیست.)
app.MapBlazorHub();
app.MapFallbackToPage("/_Host");



app.Run();

// قفل تک‌نمونه‌ای: نگه‌داشتن مودِکس تا پایان عمر فرایند. اگر نمونهٔ دیگری از قبل
// در حال اجراست، null برمی‌گرداند و فراخواننده پیام چاپ می‌کند و خروجی می‌دهد.
// نام بدون پیشوند Global است تا در همان نشست/کاربرِ کاربر کار کند (بدون نیاز به
// دسترسی ادمین).
static IDisposable? AcquireSingleInstanceLock()
{
    var mutexName = typeof(Program).FullName + ".SingleInstance";
    var mutex = new Mutex(initiallyOwned: true, name: "Local\\" + mutexName, out var createdNew);
    if (createdNew) return mutex;                                   // این نمونه مالک شد
    try
    {
        if (!mutex.WaitOne(0)) { mutex.Dispose(); return null; }   // نمونهٔ دیگری مالک است → رد
        return mutex;                                              // مالکِ قبلی رِهلش کرد → مالک شدیم
    }
    catch (AbandonedMutexException) { return mutex; }              // مالکِ قبلی cras ه؛ اکنون مالکیم
}

static IResult MobileError(int status, string code, string message)
    => Results.Json(new MobileConnectionError { Code = code, Message = message }, statusCode: status);

static void SetSensitiveResponseHeaders(HttpResponse response)
{
    response.Headers.CacheControl = "no-store, no-cache, max-age=0";
    response.Headers.Pragma = "no-cache";
    response.Headers.Append("Referrer-Policy", "no-referrer");
    response.Headers.Append("X-Content-Type-Options", "nosniff");
}
