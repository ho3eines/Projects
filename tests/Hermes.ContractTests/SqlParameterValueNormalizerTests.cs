using System.Text.Json;
using WebApi.Services;
using Xunit;

namespace Hermes.ContractTests;

public sealed class SqlParameterValueNormalizerTests
{
    [Fact]
    public void Normalize_converts_deserialized_parameter_values_to_ado_net_primitives()
    {
        var parameters = JsonSerializer.Deserialize<Dictionary<string, object?>>(
            """
            {
              "FromDate": "2026-08-12T00:00:00",
              "TakeSize": 25,
              "Amount": 12.75,
              "IsActive": true,
              "OptionalId": null,
              "JsonPayload": { "name": "Hermes" }
            }
            """)!;

        var fromDate = SqlParameterValueNormalizer.Normalize(parameters["FromDate"]);
        var takeSize = SqlParameterValueNormalizer.Normalize(parameters["TakeSize"]);
        var amount = SqlParameterValueNormalizer.Normalize(parameters["Amount"]);
        var isActive = SqlParameterValueNormalizer.Normalize(parameters["IsActive"]);
        var optionalId = SqlParameterValueNormalizer.Normalize(parameters["OptionalId"]);
        var jsonPayload = SqlParameterValueNormalizer.Normalize(parameters["JsonPayload"]);

        Assert.Equal("2026-08-12T00:00:00", Assert.IsType<string>(fromDate));
        Assert.Equal(25, Assert.IsType<int>(takeSize));
        Assert.Equal(12.75m, Assert.IsType<decimal>(amount));
        Assert.True(Assert.IsType<bool>(isActive));
        Assert.Null(optionalId);
        Assert.Equal("{ \"name\": \"Hermes\" }", Assert.IsType<string>(jsonPayload));
    }

    [Fact]
    public void Normalize_leaves_existing_clr_values_unchanged()
    {
        var date = new DateTime(2026, 8, 12);

        Assert.Equal(date, Assert.IsType<DateTime>(SqlParameterValueNormalizer.Normalize(date)));
    }
}
