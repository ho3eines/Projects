using System.Text.Json;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using WebApi.Services;

namespace WebApi.Controllers;

/// <summary>
/// Internal contract portal (PRD AC #4, ADR-003).
/// Read-only; serves the shared domain contract manifest.
/// </summary>
[ApiController]
[Route("api/contracts")]
[AllowAnonymous]
public class ContractsController : ControllerBase
{
    private readonly IContractCatalog _catalog;

    public ContractsController(IContractCatalog catalog)
    {
        _catalog = catalog;
    }

    [HttpGet]
    public IActionResult All() => Ok(_catalog.Root);

    [HttpGet("{name}")]
    public IActionResult ByName(string name)
    {
        if (_catalog.Root.TryGetProperty("contracts", out var contracts) && contracts.ValueKind == JsonValueKind.Array)
        {
            foreach (var c in contracts.EnumerateArray())
            {
                if (c.TryGetProperty("name", out var n) &&
                    string.Equals(n.GetString(), name, StringComparison.OrdinalIgnoreCase))
                    return Ok(c);
            }
        }
        return NotFound(new { code = 404, message = $"Contract not found: {name}" });
    }
}
