using Microsoft.AspNetCore.Mvc;
using Tarazin.Data;
using Tarazin.Models;

namespace Tarazin.Web.Controllers;

/// <summary>
/// Serves the server-managed SQL connection string to MAUI, keyed by a customer
/// (or deployment) GUID at <c>api/{guid}</c>.
///
/// Product decision: the full connection string is returned so the native app can
/// connect directly to SQL Server. Because this exposes database credentials to
/// any caller that knows a valid GUID, it must only ever be exposed over HTTPS,
/// must never be cached, and the served value must never be logged or written to
/// diagnostics. For production it is strongly recommended to additionally gate
/// this endpoint (e.g. shared bearer secret or IP allow-list) so a leaked GUID
/// cannot alone grant SQL access.
/// </summary>
[ApiController]
[Route("api/{guid:guid}")]
public sealed class ConnectionController : ControllerBase
{
    private readonly IConfiguration _configuration;
    private readonly IWebHostEnvironment _environment;

    public ConnectionController(IConfiguration configuration, IWebHostEnvironment environment)
    {
        _configuration = configuration;
        _environment = environment;
    }

    [HttpGet]
    public IActionResult Get(Guid guid)
    {
        Response.Headers.CacheControl = "no-store, no-cache, max-age=0";
        Response.Headers.Pragma = "no-cache";
        Response.Headers.Append("Referrer-Policy", "no-referrer");
        Response.Headers.Append("X-Content-Type-Options", "nosniff");

        // Never serve SQL credentials over plain HTTP outside local development.
        if (!Request.IsHttps && !_environment.IsDevelopment())
            return StatusCode(StatusCodes.Status426UpgradeRequired,
                new CredentialBrokerError { Code = "https_required", Message = "اتصال امن HTTPS لازم است." });

        if (guid == Guid.Empty)
            return BadRequest(new CredentialBrokerError
            {
                Code = "invalid_guid",
                Message = "شناسه مشتری معتبر نیست."
            });

        string connectionString;
        try
        {
            connectionString = TarazinConnection.Resolve(_configuration);
        }
        catch (InvalidOperationException)
        {
            // Do not surface provider/exception details; the client only needs to
            // know the server has not been configured.
            return StatusCode(StatusCodes.Status503ServiceUnavailable,
                new CredentialBrokerError
                {
                    Code = "connection_not_configured",
                    Message = "اتصال سرویس پیکربندی نشده است."
                });
        }

        return Ok(new ConnectionStringPayload { Guid = guid, ConnectionString = connectionString });
    }
}
