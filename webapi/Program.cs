using WebApi;
using WebApi.Services;

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
builder.Services.AddSingleton<ISessionStore, SessionStore>();
builder.Services.AddSingleton<HandshakeGuard>();
builder.Services.AddSingleton<IUserTokenService, UserTokenService>();
builder.Services.AddSingleton<IUserDirectory, UserDirectory>();
builder.Services.AddHostedService<SchemaBootstrap>();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

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

var app = builder.Build();

if (app.Environment.IsDevelopment())
{
    app.UseDeveloperExceptionPage();
}

app.UseHttpsRedirection();
app.UseCors("HermesClients");
app.MapControllers();

app.MapRazorComponents<App>()
    .AddInteractiveServerRenderMode();

app.MapGet("/health", () => Results.Ok(new { status = "ok", time = DateTime.UtcNow }));

app.Run();
