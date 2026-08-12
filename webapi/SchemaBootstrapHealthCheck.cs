using Microsoft.Extensions.Diagnostics.HealthChecks;
using WebApi.Services;

namespace WebApi;

/// <summary>
/// Marks the service unready while product schemas are still being created.
/// This prevents reverse proxies, dev-server auto-open, or retries from sending
/// traffic before _Ensure.sql has created [central].[News], [accounting].[Documents],
/// and the other schema-owned tables.
/// </summary>
internal sealed class SchemaBootstrapHealthCheck : IHealthCheck
{
    private readonly SchemaBootstrap _bootstrap;

    public SchemaBootstrapHealthCheck(SchemaBootstrap bootstrap)
    {
        _bootstrap = bootstrap;
    }

    public async Task<HealthCheckResult> CheckHealthAsync(HealthCheckContext context, CancellationToken cancellationToken = default)
    {
        if (_bootstrap.Completed && await _bootstrap.CoreTablesExistAsync(cancellationToken))
            return HealthCheckResult.Healthy("All product schemas are initialized.");

        if (_bootstrap.LastError is not null)
        {
            return HealthCheckResult.Unhealthy(
                "Schema bootstrap failed. Product tables may be missing.",
                _bootstrap.LastError);
        }

        return HealthCheckResult.Unhealthy("Schema bootstrap is still running.");
    }
}
