namespace Share;

public static class HermesApps
{
    public const string Accounting = "https://localhost:65218/";
    public const string Central = "https://localhost:65219/";
    public const string Inventory = "https://localhost:65224/";
    public const string Treasury = "https://localhost:65226/";
    public const string Payroll = "https://localhost:65228/";
    public const string GoldShop = "https://localhost:65230/";
    public const string Store = "https://localhost:65232/";

    public static string Open(string baseUrl, string? userToken)
    {
        if (string.IsNullOrWhiteSpace(userToken))
            return baseUrl;
        var sep = baseUrl.Contains('?') ? "&" : "?";
        return baseUrl.TrimEnd('/') + "/" + sep + "token=" + Uri.EscapeDataString(userToken);
    }
}
