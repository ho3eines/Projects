using System.Text.RegularExpressions;

namespace WebApi.Services;

public static class NamedScriptRules
{
    private static readonly Regex SafeName = new(
        @"^[A-Za-z0-9][A-Za-z0-9_\-./]{0,120}$",
        RegexOptions.Compiled);

    private static readonly string[] Forbidden = { "SELECT", "INSERT", "UPDATE", "DELETE", "DROP", "ALTER", "EXEC", "MERGE", "TRUNCATE", "--", "/*", "*/", ";" };

    public static bool IsSafeScriptName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
            return false;
        if (name.Contains(' ') || name.Contains('\\'))
            return false;
        if (!SafeName.IsMatch(name))
            return false;
        var upper = name.ToUpperInvariant();
        return Forbidden.All(f => !upper.Contains(f));
    }
}
