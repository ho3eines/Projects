using System.Text.Json;

namespace WebApi.Services;

/// <summary>
/// Converts values produced by System.Text.Json when deserializing into
/// <c>Dictionary&lt;string, object?&gt;</c> to CLR primitives accepted by Dapper and
/// ADO.NET. Without this conversion every dictionary value remains a
/// <see cref="JsonElement"/>, which SqlClient cannot use as a parameter value.
/// </summary>
public static class SqlParameterValueNormalizer
{
    public static object? Normalize(object? value)
    {
        if (value is not JsonElement element)
            return value;

        return element.ValueKind switch
        {
            JsonValueKind.Undefined => null,
            JsonValueKind.Null => null,
            JsonValueKind.String => element.GetString(),
            JsonValueKind.True => true,
            JsonValueKind.False => false,
            JsonValueKind.Number => NormalizeNumber(element),

            // Named scripts should normally receive scalar parameters. Preserve
            // an object/array as JSON text so scripts that intentionally accept
            // an nvarchar JSON parameter can still use OPENJSON/JSON_VALUE.
            JsonValueKind.Object or JsonValueKind.Array => element.GetRawText(),
            _ => element.GetRawText()
        };
    }

    private static object NormalizeNumber(JsonElement element)
    {
        if (element.TryGetInt32(out var int32))
            return int32;
        if (element.TryGetInt64(out var int64))
            return int64;
        if (element.TryGetDecimal(out var decimalValue))
            return decimalValue;
        return element.GetDouble();
    }
}
