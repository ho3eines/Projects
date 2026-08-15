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
    /// نگاشت نمونه: [{"ItemKey":"XAU-18","Path":"data[type=IRG18].price","Factor":10}]
    /// Path علاوه بر نقطه و اندیس (<c>rates[0].price</c>)، انتخاب عضو آرایه
    /// بر اساس یک property را هم پشتیبانی می‌کند
    /// (<c>data[type=IRG18].price</c>). این دقیقاً ساختار API رسمی TabloTala
    /// است که آرایهٔ <c>data</c> با فیلدهای id/type/ordering/title/last_update/price
    /// برمی‌گرداند و ترتیب اعضا نباید مبنای نگاشت باشد.
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

            // API رسمی TabloTala در موفقیت status=successful برمی‌گرداند.
            // اگر status صریحاً خطا باشد، دادهٔ احتمالی ناقص را اعمال نکن.
            if (root.ValueKind == JsonValueKind.Object
                && TryGetProperty(root, "status", out var statusElement)
                && statusElement.ValueKind == JsonValueKind.String)
            {
                var status = statusElement.GetString();
                if (!string.IsNullOrWhiteSpace(status)
                    && !string.Equals(status, "successful", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(status, "success", StringComparison.OrdinalIgnoreCase)
                    && !string.Equals(status, "ok", StringComparison.OrdinalIgnoreCase))
                    return new List<FeedItemValue>();
            }

            // کلید تکراری در Mapping نباید MERGE سمت SQL را با چند source row
            // برای یک target بشکند؛ آخرین نگاشت معتبر همان کلید برنده است.
            var items = new Dictionary<string, FeedItemValue>(StringComparer.OrdinalIgnoreCase);
            var now = DateTime.UtcNow;

            foreach (var mapping in mappings)
            {
                var value = TryReadDecimal(root, mapping.Path);
                if (value is null)
                    continue;

                var scaled = decimal.Round(value.Value * mapping.Factor, 4, MidpointRounding.AwayFromZero);
                if (scaled <= 0)
                    continue;

                items[mapping.ItemKey] = new FeedItemValue
                {
                    ItemKey = mapping.ItemKey,
                    Value = scaled,
                    FetchedAt = now
                };
            }

            return items.Values.ToList();
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

    /// <summary>
    /// خواندن decimal از مسیر نقطه‌ای. سه شکل segment پشتیبانی می‌شود:
    /// <list type="bullet">
    /// <item><c>data.price</c> — property معمولی</item>
    /// <item><c>data[0].price</c> — اندیس آرایه</item>
    /// <item><c>data[type=IRG18].price</c> — عضو آرایه با مقدار property مشخص</item>
    /// </list>
    /// </summary>
    private static decimal? TryReadDecimal(JsonElement root, string path)
    {
        var segments = path.Split('.', StringSplitOptions.RemoveEmptyEntries | StringSplitOptions.TrimEntries);
        JsonElement current = root;

        foreach (var raw in segments)
        {
            var segment = raw.Trim();
            string? selector = null;

            var bracket = segment.IndexOf('[');
            if (bracket >= 0)
            {
                if (!segment.EndsWith(']'))
                    return null;

                selector = segment[(bracket + 1)..^1].Trim();
                segment = segment[..bracket].Trim();
            }

            if (segment.Length > 0)
            {
                if (current.ValueKind != JsonValueKind.Object || !TryGetProperty(current, segment, out var child))
                    return null;
                current = child;
            }

            if (selector is null)
                continue;

            if (current.ValueKind != JsonValueKind.Array)
                return null;

            if (int.TryParse(selector, NumberStyles.None, CultureInfo.InvariantCulture, out var index))
            {
                if (index < 0 || index >= current.GetArrayLength())
                    return null;
                current = current[index];
                continue;
            }

            var equals = selector.IndexOf('=');
            if (equals <= 0 || equals == selector.Length - 1)
                return null;

            var propertyName = selector[..equals].Trim();
            var expected = selector[(equals + 1)..].Trim().Trim('"', '\'');
            JsonElement? matched = null;

            foreach (var candidate in current.EnumerateArray())
            {
                if (candidate.ValueKind != JsonValueKind.Object
                    || !TryGetProperty(candidate, propertyName, out var actual))
                    continue;

                var actualText = actual.ValueKind == JsonValueKind.String
                    ? actual.GetString()
                    : actual.GetRawText();

                if (string.Equals(actualText, expected, StringComparison.OrdinalIgnoreCase))
                {
                    matched = candidate;
                    break;
                }
            }

            if (!matched.HasValue)
                return null;
            current = matched.Value;
        }

        switch (current.ValueKind)
        {
            case JsonValueKind.Number:
                // برخی قیمت‌های FR با نمایش طولانیِ حاصل از double می‌آیند
                // (مثلاً 1.156700000000000061...). ابتدا decimal و سپس double
                // را امتحان می‌کنیم تا این مقادیر معتبر حذف نشوند.
                if (current.TryGetDecimal(out var number))
                    return number;
                if (current.TryGetDouble(out var doubleNumber)
                    && !double.IsNaN(doubleNumber)
                    && !double.IsInfinity(doubleNumber))
                    return Convert.ToDecimal(doubleNumber);
                return null;

            case JsonValueKind.String:
                var text = current.GetString();
                if (string.IsNullOrWhiteSpace(text))
                    return null;
                // حذف جداکنندهٔ هزارگان و کاراکترهای غیرعددی (مثل «ریال» یا «٬»).
                var cleaned = new string(text.Where(c => char.IsDigit(c) || c is '.' or '-').ToArray());
                return decimal.TryParse(cleaned, NumberStyles.Number, CultureInfo.InvariantCulture, out var parsed)
                    ? parsed
                    : null;

            default:
                return null;
        }
    }

    private static bool TryGetProperty(JsonElement element, string name, out JsonElement value)
    {
        if (element.TryGetProperty(name, out value))
            return true;

        foreach (var property in element.EnumerateObject())
        {
            if (string.Equals(property.Name, name, StringComparison.OrdinalIgnoreCase))
            {
                value = property.Value;
                return true;
            }
        }

        value = default;
        return false;
    }

    private static string Truncate(string text, int max) =>
        text.Length <= max ? text : text[..max];
}
