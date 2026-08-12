namespace Share;

public static class HermesApps
{
    public const string Accounting = "https://localhost:65218/";
    public const string Central = "https://localhost:65219/";

    public static string Open(string baseUrl, string? userToken)
    {
        if (string.IsNullOrWhiteSpace(userToken))
            return baseUrl;
        var sep = baseUrl.Contains('?') ? "&" : "?";
        return baseUrl.TrimEnd('/') + "/" + sep + "token=" + Uri.EscapeDataString(userToken);
    }
}
