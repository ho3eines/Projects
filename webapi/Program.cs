using Share.Models;
using WebApi.Services;
using WebApi.Controllers;
using WebApi;
using Microsoft.Extensions.FileProviders;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection("ConnectionStrings"));

builder.Services.AddSingleton<ISystemQueryExecutor, SystemQueryExecutor>();

// ---- RequestService v2 ----
builder.Services.Configure<RequestServiceConfig>(builder.Configuration.GetSection("RequestService"));
builder.Services.AddSingleton<RequestEventLogger>();
builder.Services.AddSingleton<SessionStore>();
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
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
        options.RequireHttpsMetadata = false;
    });

builder.Services.AddAuthorization();

builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", p =>
    {
        p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

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
app.UseCors("AllowAll");

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

app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

app.Run();