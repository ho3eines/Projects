using WebApi;
using WebApi.Services;
using WebApi.Controllers;
using Microsoft.Extensions.FileProviders;
using Microsoft.Extensions.Diagnostics.HealthChecks;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection("ConnectionStrings"));
builder.Services.Configure<HermesProjectsOptions>(
    builder.Configuration.GetSection("Hermes"));
builder.Services.Configure<AuthOptions>(
    builder.Configuration.GetSection("Auth"));

builder.Services.AddSingleton<ISystemQueryExecutor, SystemQueryExecutor>();
builder.Services.AddSingleton<CryptoJsService>();
builder.Services.AddSingleton<IProjectCatalog, ProjectCatalog>();
builder.Services.AddSingleton<WebApi.Services.ISessionStore, WebApi.Services.SessionStore>();
builder.Services.AddSingleton<HandshakeGuard>();
builder.Services.AddSingleton<IUserTokenService, UserTokenService>();
builder.Services.AddSingleton<IUserDirectory, UserDirectory>();
builder.Services.AddHostedService<SchemaBootstrap>();

// ---- RequestService v2 ----
builder.Services.Configure<RequestServiceConfig>(builder.Configuration.GetSection("RequestService"));
builder.Services.AddSingleton<RequestEventLogger>();
builder.Services.AddSingleton<AutoBackupScheduler>();
builder.Services.AddHostedService(sp => sp.GetRequiredService<AutoBackupScheduler>());

// Modal Service
builder.Services.AddScoped<IModalService, ModalService>();
builder.Services.AddScoped<ProjectService>();

// Blazor Server
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// HttpClient برای UI مدیریت پروژه‌ها (Blazor Server)
builder.Services.AddHttpClient();
builder.Services.AddScoped(sp => new HttpClient
{
    BaseAddress = new Uri("http://localhost:5088")
});

// Auth (JWT)
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.TokenValidationParameters = new Microsoft.IdentityModel.Tokens.TokenValidationParameters
        {
            ValidateIssuer = true,
            ValidateAudience = true,
            ValidateLifetime = true,
            ValidateIssuerSigningKey = true,
            ValidIssuer = builder.Configuration["Auth:Issuer"],
            ValidAudience = builder.Configuration["Auth:Audience"],
            IssuerSigningKey = new Microsoft.IdentityModel.Tokens.SymmetricSecurityKey(
                System.Text.Encoding.UTF8.GetBytes(builder.Configuration["Auth:SigningKey"]!))
        };
    });

var hermes = builder.Configuration.GetSection("Hermes").Get<HermesProjectsOptions>() ?? new();
var origins = hermes.CorsOrigins.Count > 0
    ? hermes.CorsOrigins.ToArray()
    : new[]
    {
        "https://localhost:65218", "http://localhost:65220",
        "https://localhost:65219", "http://localhost:65221"
    };

builder.Services.AddCors(options =>
{
    options.AddPolicy("HermesClients", p =>
    {
        p.WithOrigins(origins)
            .AllowAnyHeader()
            .AllowAnyMethod();
    });
});

// Health Checks
builder.Services.AddCustomHealthChecks(builder.Configuration);

var app = builder.Build();

// Initialize Projects table on startup
await ProjectsTableInitializer.EnsureAsync(app.Configuration.GetConnectionString("DefaultConnection")!);

// Register auto-backup for all projects
using (var scope = app.Services.CreateScope())
{
    var scheduler = scope.ServiceProvider.GetRequiredService<AutoBackupScheduler>();
    await scheduler.RegisterAllAsync();
}

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseCors("HermesClients");

// فایل‌های استاتیک عمومی (wwwroot: css, js, lib)
app.UseStaticFiles();

// بکاپ‌ها از wwwroot/backup/{ProjectGuid}/ قابل دانلود هستند
var backupRoot = Path.Combine(app.Environment.WebRootPath ?? Path.Combine(app.Environment.ContentRootPath, "wwwroot"), "backup");
Directory.CreateDirectory(backupRoot);
app.UseStaticFiles(new StaticFileOptions
{
    FileProvider = new PhysicalFileProvider(backupRoot),
    RequestPath = "/backup"
});

app.UseAuthentication();
app.UseAuthorization();

app.UseRouting();  // لازم برای Antiforgery
app.UseAntiforgery();

app.MapControllers();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// Health Checks endpoints
app.MapCustomHealthChecks();

app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

app.Run();