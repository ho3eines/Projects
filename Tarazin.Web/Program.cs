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

// Product licenses are deployment secrets. They must live outside the web
// root/repository and are loaded only by the server process when configured.
var stimulsoftLicensePath = Environment.GetEnvironmentVariable("TARAZIN_STIMULSOFT_LICENSE_PATH");
if (!string.IsNullOrWhiteSpace(stimulsoftLicensePath))
{
    if (!Path.IsPathRooted(stimulsoftLicensePath) || !File.Exists(stimulsoftLicensePath))
        throw new InvalidOperationException("The configured Stimulsoft license file is unavailable.");

    Stimulsoft.Base.StiLicense.LoadFromFile(stimulsoftLicensePath);
}

// ── Blazor Server (web host) — the UI itself lives in Tarazin.Ui ─────────
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();
// ── Minimal API-style controllers (api/{guid} connection endpoint for MAUI) ─
builder.Services.AddControllers();
builder.Services.AddRateLimiter(options =>
{
    options.RejectionStatusCode = StatusCodes.Status429TooManyRequests;
    options.AddPolicy("credential-broker", httpContext =>
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
builder.Services.AddScoped<CredentialBrokerService>();
builder.Services.AddHostedService<CredentialCleanupService>();

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
    logger.LogInformation("SQL provider uses server-side deployment configuration; values redacted");

    try
    {
        await TarazinDbInitializer.EnsureInitializedAsync(scope.ServiceProvider);
        scope.ServiceProvider.GetRequiredService<PriceFeedScheduler>().Start();

        // Do not emit SQL destinations, physical file paths, or provider details.
        logger.LogInformation("Database initialization completed");
    }
    catch (Exception ex)
    {
        logger.LogError("Database initialization failed ({ErrorType}): {SafeMessage}",
            ex.GetType().Name, DbService.Describe(ex));

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

app.UseHttpsRedirection();
app.UseStaticFiles();
app.UseRouting();
app.UseRateLimiter();

// MAUI bootstrap endpoints. Responses are never cacheable and production
// requests must use HTTPS with normal certificate validation.
var broker = app.MapGroup("/api/mobile/connection")
    .RequireRateLimiting("credential-broker");

broker.MapPost("/login", async (MobileConnectionRequest request, HttpContext http,
    CredentialBrokerService service, CancellationToken ct) =>
{
    SetSensitiveResponseHeaders(http.Response);
    try
    {
        if (!http.Request.IsHttps && !app.Environment.IsDevelopment())
            return BrokerError(StatusCodes.Status426UpgradeRequired, "https_required", "اتصال امن HTTPS لازم است.");

        return BrokerHttpResult(await service.LoginAsync(request, ct));
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        throw;
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Credential login request failed ({ErrorType})", ex.GetType().Name);
        return BrokerError(StatusCodes.Status503ServiceUnavailable, "service_unavailable", "سرویس اتصال موقتاً در دسترس نیست.");
    }
    finally
    {
        request.Password = "";
    }
}).DisableAntiforgery().WithMetadata(new RequestSizeLimitAttribute(16_384));

broker.MapPost("/refresh", async (MobileConnectionRefreshRequest request, HttpContext http,
    CredentialBrokerService service, CancellationToken ct) =>
{
    SetSensitiveResponseHeaders(http.Response);
    try
    {
        if (!http.Request.IsHttps && !app.Environment.IsDevelopment())
            return BrokerError(StatusCodes.Status426UpgradeRequired, "https_required", "اتصال امن HTTPS لازم است.");

        return BrokerHttpResult(await service.RefreshAsync(
            request, CredentialBrokerService.ReadBearerToken(http.Request), ct));
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        throw;
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Credential refresh request failed ({ErrorType})", ex.GetType().Name);
        return BrokerError(StatusCodes.Status503ServiceUnavailable, "service_unavailable", "سرویس اتصال موقتاً در دسترس نیست.");
    }
}).DisableAntiforgery().WithMetadata(new RequestSizeLimitAttribute(8_192));

broker.MapPost("/revoke", async (HttpContext http, CredentialBrokerService service, CancellationToken ct) =>
{
    SetSensitiveResponseHeaders(http.Response);
    try
    {
        if (!http.Request.IsHttps && !app.Environment.IsDevelopment())
            return BrokerError(StatusCodes.Status426UpgradeRequired, "https_required", "اتصال امن HTTPS لازم است.");

        await service.RevokeAsync(CredentialBrokerService.ReadBearerToken(http.Request), ct);
    }
    catch (OperationCanceledException) when (ct.IsCancellationRequested)
    {
        throw;
    }
    catch (Exception ex)
    {
        app.Logger.LogWarning("Credential revoke request failed ({ErrorType})", ex.GetType().Name);
    }
    return Results.NoContent();
}).DisableAntiforgery().WithMetadata(new RequestSizeLimitAttribute(1_024));

// مدل Blazor Server کلاسیک (net8): blazor.server.js و دارایی‌های استاتیک
// MudBlazor/Tarazin.Ui از طریق static web assets و UseStaticFiles سرو می‌شوند.
// (MapStaticAssets که در net9+ اضافه شد، در net8 وجود ندارد و لازم هم نیست.)
app.MapControllers();
app.MapBlazorHub();
app.MapFallbackToPage("/_Host");



app.Run();

static IResult BrokerHttpResult(BrokerResult result)
    => result.Response is not null
        ? Results.Json(result.Response, statusCode: result.StatusCode)
        : Results.Json(result.Error, statusCode: result.StatusCode);

static IResult BrokerError(int status, string code, string message)
    => Results.Json(new CredentialBrokerError { Code = code, Message = message }, statusCode: status);

static void SetSensitiveResponseHeaders(HttpResponse response)
{
    response.Headers.CacheControl = "no-store, no-cache, max-age=0";
    response.Headers.Pragma = "no-cache";
    response.Headers.Append("Referrer-Policy", "no-referrer");
    response.Headers.Append("X-Content-Type-Options", "nosniff");
}
