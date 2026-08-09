using Share.Models;
using WebApi.Services;

var builder = WebApplication.CreateBuilder(args);

// ---------- WebAPI core services ----------
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection("ConnectionStrings"));

builder.Services.AddSingleton<ISystemQueryExecutor, SystemQueryExecutor>();

// ---------- Blazor Server (مدیریت تنظیمات پروژه‌ها) ----------
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

// ---------- Auth (JWT) ----------
builder.Services.AddAuthentication("Bearer")
    .AddJwtBearer(options =>
    {
        options.Authority = builder.Configuration["Auth:Authority"];
        options.Audience = builder.Configuration["Auth:Audience"];
        options.RequireHttpsMetadata = false;
    });

builder.Services.AddAuthorization();

// ---------- CORS for all project clients ----------
builder.Services.AddCors(options =>
{
    options.AddPolicy("AllowAll", p =>
    {
        p.AllowAnyOrigin().AllowAnyHeader().AllowAnyMethod();
    });
});

var app = builder.Build();

// ---------- Pipeline ----------
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

// Blazor Server endpoints (تنظیمات پروژه‌ها)
app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

// Health check for Docker
app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

app.Run();