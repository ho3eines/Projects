using Share.Models;
using WebApi;
using WebApi.Services;

var builder = WebApplication.CreateBuilder(args);

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();

builder.Services.Configure<ConnectionStringsOptions>(
    builder.Configuration.GetSection("ConnectionStrings"));

builder.Services.Configure<HermesProjectsOptions>(
    builder.Configuration.GetSection("Hermes"));
builder.Services.AddSingleton<ISystemQueryExecutor, SystemQueryExecutor>();
builder.Services.AddSingleton<CryptoJsService>();
builder.Services.AddSingleton<IProjectCatalog, ProjectCatalog>();
builder.Services.AddSingleton<ISessionStore, SessionStore>();
builder.Services.AddSingleton<HandshakeGuard>();

// Blazor Server
builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

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

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseCors("AllowAll");
app.UseAuthentication();
app.UseAuthorization();

app.MapControllers();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

app.Run();
