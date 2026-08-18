namespace Tarazin.Web;

/// <summary>Revokes expired SQL logins and removes replay/session tombstones.</summary>
public sealed class CredentialCleanupService : BackgroundService
{
    private readonly IServiceScopeFactory _scopeFactory;
    private readonly ILogger<CredentialCleanupService> _logger;

    public CredentialCleanupService(IServiceScopeFactory scopeFactory, ILogger<CredentialCleanupService> logger)
    {
        _scopeFactory = scopeFactory;
        _logger = logger;
    }

    protected override async Task ExecuteAsync(CancellationToken stoppingToken)
    {
        using var timer = new PeriodicTimer(TimeSpan.FromMinutes(1));
        while (!stoppingToken.IsCancellationRequested)
        {
            try
            {
                using var scope = _scopeFactory.CreateScope();
                var broker = scope.ServiceProvider.GetRequiredService<CredentialBrokerService>();
                await broker.CleanupExpiredAsync(stoppingToken);
            }
            catch (OperationCanceledException) when (stoppingToken.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.LogWarning("Credential cleanup failed ({ErrorType}); it will retry.", ex.GetType().Name);
            }

            if (!await timer.WaitForNextTickAsync(stoppingToken))
                break;
        }
    }
}
