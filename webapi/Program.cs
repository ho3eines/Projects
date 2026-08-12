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
builder.Services.Configure<OutboxOptions>(
    builder.Configuration.GetSection("Outbox"));

builder.Services.AddSingleton<ISystemQueryExecutor, SystemQueryExecutor>();
builder.Services.AddSingleton<CryptoJsService>();
builder.Services.AddSingleton<IProjectCatalog, ProjectCatalog>();
builder.Services.AddSingleton<ISessionStore, SessionStore>();
builder.Services.AddSingleton<HandshakeGuard>();
builder.Services.AddSingleton<IUserTokenService, UserTokenService>();
builder.Services.AddSingleton<IUserDirectory, UserDirectory>();
builder.Services.AddSingleton<IAuditService, AuditService>();
builder.Services.AddSingleton<IContractCatalog, ContractCatalog>();
builder.Services.AddHostedService<SchemaBootstrap>();
builder.Services.AddHostedService<OutboxProcessor>();

builder.Services.AddRazorComponents()
    .AddInteractiveServerComponents();

var hermes = builder.Configuration.GetSection("Hermes").Get<HermesProjectsOptions>() ?? new();
var origins = hermes.CorsOrigins.Count > 0
    ? hermes.CorsOrigins.ToArray()
    : new[]
    {
        "https://localhost:65218", "http://localhost:65220",
        "https://localhost:65219", "http://localhost:65221",
        "https://localhost:65224", "http://localhost:65225",
        "https://localhost:65226", "http://localhost:65227",
        "https://localhost:65228", "http://localhost:65229",
        "https://localhost:65230", "http://localhost:65231",
        "https://localhost:65232", "http://localhost:65233"
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
