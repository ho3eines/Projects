using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Dapper;
using Share.Models;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// Internal named-TSQL executor (JWT). WASM clients must NOT call this.
/// They use RequestService → /api/auth/handshake + /api/Data/ (encrypted, ProjectGuid).
/// </summary>
[ApiController]
[Route("api/system")]
[Authorize]
public class SystemController : ControllerBase
{
    private readonly ILogger<SystemController> _logger;
    private readonly ISystemQueryExecutor _executor;

    public SystemController(ILogger<SystemController> logger, ISystemQueryExecutor executor)
    {
        _logger = logger;
        _executor = executor;
    }

    /// <summary>Run a SELECT script → List<T></summary>
    [HttpPost("query")]
    public async Task<IActionResult> Query([FromBody] SystemRequestPayload request)
    {
        if (string.IsNullOrWhiteSpace(request.ScriptName))
            return BadRequest(new { error = "ScriptName is required" });

        try
        {
            var data = await _executor.QueryAsync(request.ScriptName, request.Parameters, request.Schema);
            return Ok(new SystemQueryResult<dynamic>
            {
                RequestId = request.RequestId,
                TotalCount = data.Count,
                Data = data
            });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Query failed for script {Script}", request.ScriptName);
            return StatusCode(500, new { error = ex.Message, requestId = request.RequestId });
        }
    }

    /// <summary>Run an INSERT/UPDATE/DELETE/DDL script → affected rows</summary>
    [HttpPost("execute")]
    public async Task<IActionResult> Execute([FromBody] SystemRequestPayload request)
    {
        if (string.IsNullOrWhiteSpace(request.ScriptName))
            return BadRequest(new { error = "ScriptName is required" });

        try
        {
            int affected = await _executor.ExecuteAsync(request.ScriptName, request.Parameters, request.Schema);
            return Ok(new { request.RequestId, AffectedRows = affected });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Execute failed for script {Script}", request.ScriptName);
            return StatusCode(500, new { error = ex.Message, requestId = request.RequestId });
        }
    }

    /// <summary>Run a scalar script → single value</summary>
    [HttpPost("scalar")]
    public async Task<IActionResult> Scalar([FromBody] SystemRequestPayload request)
    {
        if (string.IsNullOrWhiteSpace(request.ScriptName))
            return BadRequest(new { error = "ScriptName is required" });

        try
        {
            var value = await _executor.ScalarAsync(request.ScriptName, request.Parameters, request.Schema);
            return Ok(new { request.RequestId, Value = value });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Scalar failed for script {Script}", request.ScriptName);
            return StatusCode(500, new { error = ex.Message, requestId = request.RequestId });
        }
    }
}