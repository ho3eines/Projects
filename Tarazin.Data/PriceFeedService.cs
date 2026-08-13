using System.Globalization;
using System.Text.Json;
using Microsoft.Extensions.Logging;
using Tarazin.Models;

namespace Tarazin.Data;

/// <summary>
/// دریافت نرخ‌های بازار به‌صورت آنلاین از منابع تعریف‌شده (PRD §44/§61).
///
/// قواعد معماری:
/// - دادهٔ کسب‌وکار همیشه از طریق اسکریپت‌های نامدار Dapper می‌آید؛ این سرویس
///   فقط **دادهٔ بازار خارجی** (قیمت طلا/سکه/ارز) را از API/Feed رسمیِ منابع
///   تعریف‌شده در <c>currency.PriceSources</c> دریافت می‌کند.
/// - هر منبع سه بخش دارد که **همگی توسط مدیر قابل ویرایش‌اند**:
///   Endpoint (آدرس API/Feed رسمی)، MappingsJson (نگاشت ItemKey ← مسیر در پاسخ)
///   و Priority (ترتیب منابع — §58). به‌همین دلیل سیستم به HTML Selector شکننده
///   وابسته نیست (PRD §61).
/// - خروجی فقط JSON (API/Feed رسمی) یا جاوااسکریپتِ ساختارمند
///   (<c>var x = {...};</c>) است؛ اگر هیچ‌کدام نبود، خطا ثبت و وضعیت منبع
///   Offline می‌شود؛ نرخ‌های معتبر قبلی دست نمی‌خورند (PRD §57).
/// - نرخ جدید فقط در OnlineRate می‌نشیند و هرگز مستقیم وارد معامله نمی‌شود
///   (PRD §46/§56)؛ ورود به نرخ سیستم فقط با تأیید مدیر یا خط مشی AutoPromote.
/// </summary>
public sealed class PriceFeedService
{
    private static readonly HttpClient Http = CreateClient();
    private readonly DbService _db;
    private readonly ILogger<PriceFeedService> _logger;

    public PriceFeedService(DbService db, ILogger<PriceFeedService> logger)
    {
        _db = db;
        _logger = logger;
    }

    private static HttpClient CreateClient()
    {
        var client = new HttpClient { Timeout = TimeSpan.FromSeconds(25) };
        client.DefaultRequestHeaders.UserAgent.ParseAdd("Tarazin-PriceFeed/1.0 (+https://tarazin.local)");
        client.DefaultRequestHeaders.Accept.ParseAdd("application/json");
        return client;
    }

    /// <summary>
    /// یک چرخهٔ کامل دریافت از همهٔ منابع فعال به ترتیب اولویت (§58).
    /// اگر منبع اول در دسترس نبود، منبع بعدی بررسی می‌شود.
    /// </summary>
    public async Task<PriceFeedResult> FetchAllAsync(CancellationToken ct = default)
    {
        var result = new PriceFeedResult();
        var sources = (await _db.QueryAsync<PriceSourceRow>(
            "currency", "PriceSourceList", new { OnlyActive = true }, ct)).ToList();

        foreach (var source in sources
                     .Where(s => s.IsActive && !string.Equals(s.SourceKey, "MANUAL", StringComparison.OrdinalIgnoreCase))
                     .OrderBy(s => s.Priority))
        {
            result.Results.Add(await FetchSourceAsync(source, ct));
        }

        return result;
    }

    /// <summary>دریافت نرخ از یک منبع مشخص و اعمال در مرکز قیمت (FeedApply).</summary>
    public async Task<PriceSourceFetchResult> FetchSourceAsync(PriceSourceRow source, CancellationToken ct = default)
    {
        var outcome = new PriceSourceFetchResult
        {
            SourceKey = source.SourceKey,
            Title = source.Title,
            FetchedAt = DateTime.UtcNow
        };

        if (string.IsNullOrWhiteSpace(source.Endpoint))
        {
            outcome.Error = "برای این منبع Endpoint تعریف نشده است.";
            await MarkOfflineAsync(source.SourceKey, outcome.Error, ct);
            return outcome;
        }

        try
        {
            _logger.LogInformation("دریافت نرخ از {Source} ← {Endpoint}", source.SourceKey, source.Endpoint);
            using var response = await Http.GetAsync(source.Endpoint, ct);
            response.EnsureSuccessStatusCode();

            var body = await response.Content.ReadAsStringAsync(ct);
            var items = ParseFeed(body, source.MappingsJson);

            if (items.Count == 0)
                throw new InvalidOperationException("هیچ نرخی از خروجی منبع استخراج نشد (فرمت پشتیبانی‌نشده یا نگاشت خالی).");

            await _db.ExecuteAsync("currency", "FeedApply", new
            {
                SourceKey = source.SourceKey,
                ItemsJson = JsonSerializer.Serialize(items),
                CreatedBy = "system"
            }, ct);

            outcome.Success = true;
            outcome.ItemCount = items.Count;
            _logger.LogInformation("اعمال {Count} نرخ از {Source} با موفقیت انجام شد", items.Count, source.SourceKey);
        }
        catch (Exception ex)
        {
            outcome.Error = Truncate(ex.Message, 400);
            _logger.LogWarning(ex, "دریافت نرخ از {Source} ناموفق بود — وضعیت منبع Offline می‌شود و آخرین نرخ معتبر حفظ می‌شود (§57)", source.SourceKey);
            await MarkOfflineAsync(source.SourceKey, outcome.Error, ct);
        }

        return outcome;
    }

    private async Task MarkOfflineAsync(string sourceKey, string error, CancellationToken ct)
    {
        try
        {
            await _db.ExecuteAsync("currency", "PriceSourceStatus", new
            {
                SourceKey = sourceKey,
                Status = "Offline",
                Error = error,
                LastFetchAt = DateTime.UtcNow,
                CreatedBy = "system"
            }, ct);
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "به‌روزرسانی وضعیت منبع {Source} ناموفق بود", sourceKey);
        }
    }

    /// <summary>
    /// استخراج مقادیر نرخ از خروجی منبع بر اساس MappingsJson.
    /// نگاشت نمونه: [{"ItemKey":"USD","Path":"rates.usd.price","Factor":1}]
    /// Path از نقطه و اندیس پشتیبانی می‌کند: "rates[0].price".
    /// اگر خروجی JSON نبود، جاوااسکریپت ساختارمندِ { ... } را می‌کاود
    /// (بدون هیچ Selector مبتنی بر HTML).
    /// </summary>
    public static List<FeedItemValue> ParseFeed(string body, string? mappingsJson)
    {
        var mappings = ParseMappings(mappingsJson);
        if (mappings.Count == 0)
            return new List<FeedItemValue>();

        JsonDocument? document = TryParseJson(body)
            ?? TryExtractJsObject(body);

        if (document is null)
            return new List<FeedItemValue>();

        using (document)
        {
            var root = document.RootElement;
            var items = new List<FeedItemValue>();
            var now = DateTime.UtcNow;

            foreach (var mapping in mappings)
            {
                var value = TryReadDecimal(root, mapping.Path);
                if (value is null)
                    continue;

                var scaled = value.Value * mapping.Factor;
                if (scaled <= 0)
                    continue;

                items.Add(new FeedItemValue { ItemKey = mapping.ItemKey, Value = scaled, FetchedAt = now });
            }

            return items;
        }
    }

    private static JsonDocument? TryParseJson(string body)
    {
        try
        {
            var trimmed = body.TrimStart();
            if (!trimmed.StartsWith('{') && !trimmed.StartsWith('['))
                return null;
            return JsonDocument.Parse(trimmed);
        }
        catch (JsonException)
        {
            return null;
        }
    }

    /// <summary>
    /// خروجی‌های «جاوااسکریپت ساختارمند» (بسیاری از تابلوهای قیمت ایرانی):
    ///   var prices = {...};  یا  window.Prices = {...};  یا  const x = {...};
    /// این روش روی ساختار داده متکی است نه روی HTML — و با تغییر ساختارِ
    /// خودِ خروجی منبع، مدیر فقط MappingsJson را اصلاح می‌کند (PRD §61).
    /// </summary>
    private static JsonDocument? TryExtractJsObject(string body)
    {
        var start = body.IndexOf('{');
        if (start < 0)
            return null;

        var depth = 0;
        var inString = false;
        var escape = false;
        for (var i = start; i < body.Length; i++)
        {
            var c = body[i];
            if (inString)
            {
                if (escape) { escape = false; continue; }
                if (c == '\\') { escape = true; continue; }
                if (c == '"') inString = false;
                continue;
            }

            switch (c)
            {
                case '"': inString = true; break;
                case '{': depth++; break;
                case '}':
                    depth--;
                    if (depth == 0)
                    {
                        var candidate = body[start..(i + 1)];
                        try
                        {
                            return JsonDocument.Parse(candidate);
                        }
                        catch (JsonException)
                        {
                            return null;
                        }
                    }
                    break;
            }
        }

        return null;
    }

    private sealed record Mapping(string ItemKey, string Path, decimal Factor);

    private static List<Mapping> ParseMappings(string? mappingsJson)
    {
        var result = new List<Mapping>();
        if (string.IsNullOrWhiteSpace(mappingsJson))
            return result;

        try
        {
            using var doc = JsonDocument.Parse(mappingsJson);
            foreach (var el in doc.RootElement.EnumerateArray())
            {
                var key = el.TryGetProperty("ItemKey", out var k) ? k.GetString() : null;
                var path = el.TryGetProperty("Path", out var p) ? p.GetString() : null;
                var factor = el.TryGetProperty("Factor", out var f) && f.TryGetDecimal(out var fv) ? fv : 1m;
                if (!string.IsNullOrWhiteSpace(key) && !string.IsNullOrWhiteSpace(path))
                    result.Add(new Mapping(key.Trim(), path.Trim(), factor));
            }
        }
        catch (JsonException)
        {
            // نگاشت خراب — بدون آیتم برمی‌گردد تا در گزارش خطا دیده شود.
        }

        return result;
    }

    /// <summary>خواندن decimal از مسیر نقطه‌ای (با پشتیبانی از [n]).</summary>
    private static decimal? TryReadDecimal(JsonElement root, string path)
    {
        var segments = path.Split('.');
        JsonElement current = root;

        foreach (var raw in segments)
        {
            var segment = raw.Trim();
            var index = -1;

            var bracket = segment.IndexOf('[');
            if (bracket >= 0 && segment.EndsWith(']'))
            {
                var name = segment[..bracket];
                var idxText = segment[(bracket + 1)..^1];
                if (int.TryParse(idxText, out index))
                    segment = name;
                else
                    return null;
            }

            if (segment.Length > 0)
            {
                if (current.ValueKind != JsonValueKind.Object || !current.TryGetProperty(segment, out var child))
                    return null;
                current = child;
            }

            if (index >= 0)
            {
                if (current.ValueKind != JsonValueKind.Array || index >= current.GetArrayLength())
                    return null;
                current = current[index];
            }
        }

        switch (current.ValueKind)
        {
            case JsonValueKind.Number:
                return current.TryGetDecimal(out var n) ? n : null;
            case JsonValueKind.String:
                var text = current.GetString();
                if (string.IsNullOrWhiteSpace(text))
                    return null;
                // حذف جداکنندهٔ هزارگان و کاراکترهای غیرعددی (مثل «ریال» یا «٬»).
                var cleaned = new string(text.Where(c => char.IsDigit(c) || c is '.' or '-').ToArray());
                return decimal.TryParse(cleaned, NumberStyles.Number, CultureInfo.InvariantCulture, out var d) ? d : null;
            default:
                return null;
        }
    }

    private static string Truncate(string text, int max) =>
        text.Length <= max ? text : text[..max];
}
