using TarazinApp.Services;
using MudBlazor.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Blazor Server (single project — no webapi, no WASM clients) ──────────
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// ── MudBlazor UI kit ─────────────────────────────────────────────────────
builder.Services.AddMudServices();

// ── Data & services (all server-side, direct SQL via named scripts) ──────
builder.Services.AddSingleton<ScriptCatalog>();
builder.Services.AddScoped<DbService>();
builder.Services.AddScoped<AuditService>();
builder.Services.AddScoped<AuthService>();
builder.Services.AddScoped<UserSession>();

var app = builder.Build();

// ── Startup: load named scripts, ensure schemas/tables, seed idempotently ─
using (var scope = app.Services.CreateScope())
{
    var catalog = scope.ServiceProvider.GetRequiredService<ScriptCatalog>();
    catalog.Load(app.Environment.ContentRootPath);

    var db = scope.ServiceProvider.GetRequiredService<DbService>();
    await db.EnsureSchemaAsync();
    await db.SeedAsync();
    await EnsureBootstrapAdminAsync(db, app.Configuration);
}

if (!app.Environment.IsDevelopment())
{
    app.UseExceptionHandler("/Error");
    app.UseHsts();
}

app.UseStaticFiles();
app.UseRouting();

app.MapBlazorHub();
app.MapFallbackToPage("/_Host");

app.Run();

// Creates the first admin only when [central].[Users] is empty.
// Password is hashed with PBKDF2 on the server (never stored in plaintext).
static async Task EnsureBootstrapAdminAsync(DbService db, IConfiguration config)
{
    var count = await db.ScalarAsync("central", "UserCount");
    if (count is not null && Convert.ToInt32(count) > 0)
        return;

    var username = config["Tarazin:BootstrapAdminUser"] ?? "admin";
    var password = config["Tarazin:BootstrapAdminPassword"] ?? "admin";
    await db.ExecuteAsync("central", "UserUpsert", new
    {
        UserId = 0,
        Username = username,
        PasswordHash = PasswordHasher.Hash(password),
        DisplayName = "مدیر سیستم",
        Role = "Admin",
        IsActive = true,
        CreatedBy = "bootstrap"
    });
}
