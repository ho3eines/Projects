using System;
using System.Collections.Generic;
using System.Text;
using System.Threading.Tasks;
using Dapper;
using Microsoft.Data.SqlClient;
using Xunit;

namespace Tarazin.Tests;

/// <summary>
/// گارد ضد-بازگشتِ کدگذاری دوبل UTF-8 — همان ۴ ستونی که در گذشته با بایت‌های UTF-8
/// که به‌جای Windows-1256 خوانده شده‌اند خراب شدند (موژیمیک مثل «ط¯ط±غŒط§ظپطھ»):
///   treasury.CashMovements.Description ، accounting.Documents.CounterPartyName ،
///   goldshop.InvoiceLines.Title ، goldshop.GoldPartyLedger.Description
/// ابزار تعمیر همان داده‌ها: tools/fix-double-utf8.ps1 (همان منطق، یک منبع حقیقت).
///
/// تشخیص دو مرحله‌ای است تا نویسه‌های سالمِ U+0080–U+00FF (مثل گیومهٔ «» یا حروف
/// فرانسوی é) خطای کاذب ندهند:
///   ۱) سیگنال ارزان: رشته حداقل یک نویسهٔ U+0080–U+00FF دارد؛
///   ۲) تأیید: دیکدِ سختگیرانهٔ cp1256→UTF-8 متنی معتبر با دست‌کم یک حرف فارسی
///      (U+0600–U+06FF) می‌دهد که با اصل فرق دارد → قطعاً دوبل-کدگذاری است.
///
/// دو بخش دارد:
///   - تست‌های واحد خالص (بدون DB، هیچ‌وقت Skip): نمونه‌های موژیمیکِ واقعی شناسایی و
///     تعمیر می‌شوند و متن سالم/لاتین دست نمی‌خورد؛
///   - گارد DBدار (SkippableFact): کل ۴ ستون را اسکن می‌کند و اگر ردیفِ دوبل-UTF8
///     برگشته باشد Fail می‌شود (DB در دسترس نبود → Skip، مثل بقیهٔ گاردهای DBدار).
/// </summary>
public class DoubleUtf8GuardTests
{
    static DoubleUtf8GuardTests()
    {
        // .NET Core جدول‌های کدپیج (cp1256) را به‌صورت پیش‌فرض ندارد —
        // System.Text.Encoding.CodePages به‌صورت انتقالی از Microsoft.Data.SqlClient می‌آید.
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    /// <summary>ستون‌های شناخته‌شدهٔ دارای خطر دوبل-UTF8: (schema, table, column, keyColumn).</summary>
    private static readonly (string Schema, string Table, string Column, string KeyColumn)[] Targets =
    {
        ("treasury",   "CashMovements",   "Description",      "MovementNumber"),
        ("accounting",  "Documents",      "CounterPartyName", "DocumentId"),
        ("goldshop",    "InvoiceLines",   "Title",            "LineId"),
        ("goldshop",    "GoldPartyLedger", "Description",     "LedgerId"),
    };

    /// <summary>
    /// تشخیص و تعمیر موژیمیکِ دوبل-UTF8 (دقیقاً منطق tools/fix-double-utf8.ps1):
    /// اگر رشته قابل تعمیر باشد متن درست برمی‌گرداند، وگرنه null (سالم یا غیرقابل‌تعمیر).
    /// </summary>
    internal static string? TryRepairDoubleUtf8(string s)
    {
        if (string.IsNullOrEmpty(s)) return null;

        // ۱) سیگنال ارزان — نویسهٔ U+0080..U+00FF (محصولِ خواندنِ بایتِ UTF-8 به‌جای cp1256)
        bool suspect = false;
        foreach (var ch in s)
        {
            int c = ch;
            if (c is >= 0x80 and <= 0xFF) { suspect = true; break; }
        }
        if (!suspect) return null;

        // ۲) تأیید — وارونِ خرابی: بایت‌ها از cp1256، سپس دیکدِ سختگیرانهٔ UTF-8
        string repaired;
        try
        {
            var cp1256 = Encoding.GetEncoding(1256);
            var utf8Strict = new UTF8Encoding(false, true); // throwOnInvalidBytes
            repaired = utf8Strict.GetString(cp1256.GetBytes(s));
        }
        catch (DecoderFallbackException) { return null; } // UTF-8 نامعتبر → سالم/غیرقابل‌تعمیر
        catch (EncoderFallbackException) { return null; } // cp1256 نتوانست نگاشت کند

        if (repaired == s) return null;

        // نتیجه باید واقعاً فارسی باشد (نه تصادفِ لاتین/نماد)
        bool persian = false;
        foreach (var ch in repaired)
        {
            int c = ch;
            if (c is >= 0x600 and <= 0x6FF) { persian = true; break; }
        }
        return persian ? repaired : null;
    }

    // ── بخش ۱: تست‌های واحد خالص (بدون DB — هیچ‌وقت Skip) ────────────────────

    /// <summary>موژیمیکِ واقعی (ساخته‌شده از متن سالم با همان مکانیزم خرابی) شناسایی و درست تعمیر می‌شود.</summary>
    [Theory]
    [InlineData("دریافت بانکی GINV-00074")]
    [InlineData("شرکت نمونه")]
    [InlineData("طلای ۱۸ عیار (گرم)")]
    public void Known_mojibake_samples_are_detected_and_repaired(string clean)
    {
        var cp1256 = Encoding.GetEncoding(1256);
        // همان مکانیزم خرابی: بایت‌های UTF-8 متن سالم با جدول cp1256 خوانده می‌شوند
        var mojibake = cp1256.GetString(Encoding.UTF8.GetBytes(clean));
        Assert.NotEqual(clean, mojibake);          // واقعاً خراب شده
        Assert.Equal(clean, TryRepairDoubleUtf8(mojibake));
    }

    /// <summary>متن سالم — حتی با نویسه‌های U+0080–U+00FF معتبر — هرگز دست نمی‌خورد.</summary>
    [Theory]
    [InlineData("دریافت بانکی GINV-00074")]            // فارسی سالم بدون نویسهٔ مشکوک
    [InlineData("فاکتور «نقدی» — پرداخت ۱۰۰٪")]          // گیومهٔ U+00AB/U+00BB سالم
    [InlineData("Banque Nationale — dépôt")]           // لاتین با é (U+00E9)
    [InlineData("")]
    [InlineData("   ")]
    public void Clean_text_is_never_touched(string s)
    {
        Assert.Null(TryRepairDoubleUtf8(s));
    }

    // ── بخش ۲: گارد DBدار — اسکن ۴ ستونِ شناخته‌شده ──────────────────────────

    /// <summary>
    /// اسکن زندهٔ ۴ ستونی که قبلاً دوبل-UTF8 شدند: اگر حتی یک ردیفِ دوبل-UTF8 برگشته
    /// باشد تست Fail می‌شود و همان ردیف‌ها (با کلید و متن درست) گزارش می‌شوند تا با
    /// tools/fix-double-utf8.ps1 -Apply تعمیر شوند. SQL در دسترس نبود → Skip.
    /// </summary>
    [SkippableFact]
    public async Task Scan_four_known_columns_has_no_double_utf8_rows()
    {
        using var cn = await TestDb.OpenOrSkipAsync();
        var problems = new List<string>();

        foreach (var t in Targets)
        {
            var rows = await cn.QueryAsync<(object Key, string Value)>(
                $"SELECT [{t.KeyColumn}] AS [Key], [{t.Column}] AS [Value] " +
                $"FROM [{t.Schema}].[{t.Table}] WHERE [{t.Column}] IS NOT NULL");

            foreach (var r in rows)
            {
                var repaired = TryRepairDoubleUtf8(r.Value);
                if (repaired != null)
                    problems.Add($"{t.Schema}.{t.Table}.{t.Column} (key={r.Key}): «{r.Value}» → «{repaired}»");
            }
        }

        Assert.True(problems.Count == 0,
            "ردیف‌های دوبل-UTF8 در ستون‌های شناخته‌شده پیدا شدند — با " +
            "«powershell -File tools/fix-double-utf8.ps1 -Apply» تعمیر کن:\n" +
            string.Join("\n", problems));
    }
}
