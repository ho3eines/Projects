using MudBlazor.Services;
using Tarazin.Services;

var builder = WebApplication.CreateBuilder(args);

// ── Blazor Server (web host) — the UI itself lives in Tarazin.Shared ─────
builder.Services.AddRazorPages();
builder.Services.AddServerSideBlazor();

// ── MudBlazor UI kit (providers are rendered by the shared App.razor) ─────
builder.Services.AddMudServices();

// ── Shared Tarazin services (DbService, ScriptCatalog, Auth, Audit, ...) ──
builder.Services.AddTarazinSharedServices();

var app = builder.Build();

// ── Startup: ensure schemas/tables, seed idempotently, bootstrap admin ────
using (var scope = app.Services.CreateScope())
{
    await TarazinDbInitializer.EnsureInitializedAsync(scope.ServiceProvider);
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
